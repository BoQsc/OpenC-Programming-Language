"""Resource ownership, safe-borrow, cleanup, and raw-pointer abstract state."""
from __future__ import annotations

from dataclasses import dataclass, field

from .diagnostics import DiagnosticEngine
from .flow import FlowBinding, FlowState, InitState, OwnerState
from .model import Phase, SemanticType, Span


@dataclass(slots=True)
class BorrowRecord:
    owner: str
    mutable: bool
    region: int
    span: Span


@dataclass(slots=True)
class Provenance:
    allocation_id: str
    extent: int | None
    offset: int = 0
    generation: int = 0
    alive: bool = True
    one_past: bool = False
    alignment: int = 1
    element_type: SemanticType | None = None

    def derive(self, offset_delta: int, element_size: int) -> "Provenance":
        new_offset = self.offset + offset_delta * element_size
        one_past = self.extent is not None and new_offset == self.extent
        return Provenance(
            self.allocation_id, self.extent, new_offset, self.generation,
            self.alive, one_past, self.alignment, self.element_type,
        )


class OwnershipChecker:
    def __init__(self, diagnostics: DiagnosticEngine):
        self.diagnostics = diagnostics
        self.region = 0
        self.borrows: list[BorrowRecord] = []
        self.provenance: dict[str, Provenance] = {}

    @staticmethod
    def is_owner_type(value: SemanticType) -> bool:
        return value.resource or (value.kind == "ptr" and value.name.startswith("own "))

    def initialize_binding(self, binding: FlowBinding) -> None:
        binding.init = InitState.INITIALIZED
        if binding.type.resource:
            binding.owner = OwnerState.LIVE
        elif binding.type.kind == "ptr":
            binding.owner = OwnerState.NONE
        if binding.type.kind == "optional":
            binding.presence = binding.presence.MAYBE

    def move(self, state: FlowState, source_name: str, span: Span) -> None:
        source = state.require_readable(source_name, self.diagnostics, span)
        if source.owner == OwnerState.CLEANUP_RESERVED:
            self.diagnostics.raise_error(
                "OPENC-SCOPE-RESERVED-MOVE-001", Phase.OWNERSHIP,
                f"owner '{source_name}' is reserved by scope cleanup and cannot be moved",
                span, "ownership.cleanup",
            )
        if source.owner != OwnerState.LIVE:
            self.diagnostics.raise_error(
                "OPENC-OWN-MOVE-STATE-001", Phase.OWNERSHIP,
                f"'{source_name}' is not a live owner", span, "ownership.move",
            )
        self.require_unborrowed(source_name, span)
        source.owner = OwnerState.MOVED
        source.init = InitState.MOVED

    def reserve_cleanup(self, state: FlowState, owner_name: str, action: str, span: Span) -> None:
        owner = state.require_readable(owner_name, self.diagnostics, span)
        if owner.owner != OwnerState.LIVE:
            self.diagnostics.raise_error(
                "OPENC-SCOPE-OWNER-STATE-001", Phase.OWNERSHIP,
                f"scope cleanup requires a live owner, but '{owner_name}' is {owner.owner.value}",
                span, "ownership.cleanup",
            )
        if owner.cleanup_action is not None:
            self.diagnostics.raise_error(
                "OPENC-SCOPE-DUPLICATE-OWNER-001", Phase.OWNERSHIP,
                f"owner '{owner_name}' already has registered cleanup", span, "ownership.cleanup",
            )
        owner.owner = OwnerState.CLEANUP_RESERVED
        owner.cleanup_action = action

    def consume_reserved_cleanup(self, state: FlowState, owner_name: str) -> None:
        owner = state.bindings[owner_name]
        owner.owner = OwnerState.MOVED
        owner.init = InitState.MOVED
        owner.cleanup_action = None

    def begin_borrow(self, state: FlowState, owner_name: str, mutable: bool, span: Span) -> BorrowRecord:
        owner = state.require_readable(owner_name, self.diagnostics, span)
        if owner.owner in {OwnerState.MOVED, OwnerState.DESTROYED, OwnerState.UNINITIALIZED}:
            self.diagnostics.raise_error(
                "OPENC-BORROW-OWNER-STATE-001", Phase.BORROW,
                f"cannot borrow '{owner_name}' in state {owner.owner.value}", span, "borrow.state",
            )
        active = [item for item in self.borrows if item.owner == owner_name]
        if mutable and active:
            self.diagnostics.raise_error(
                "OPENC-BORROW-CONFLICT-001", Phase.BORROW,
                f"mutable borrow of '{owner_name}' conflicts with an active borrow", span, "borrow.conflict",
            )
        if not mutable and any(item.mutable for item in active):
            self.diagnostics.raise_error(
                "OPENC-BORROW-CONFLICT-001", Phase.BORROW,
                f"read borrow of '{owner_name}' conflicts with an active mutable borrow", span, "borrow.conflict",
            )
        self.region += 1
        record = BorrowRecord(owner_name, mutable, self.region, span)
        self.borrows.append(record)
        if mutable:
            owner.borrow_writer = True
        else:
            owner.borrow_readers += 1
        return record

    def end_borrow(self, state: FlowState, record: BorrowRecord) -> None:
        if record not in self.borrows:
            return
        self.borrows.remove(record)
        owner = state.bindings.get(record.owner)
        if owner is None:
            return
        if record.mutable:
            owner.borrow_writer = False
        else:
            owner.borrow_readers = max(0, owner.borrow_readers - 1)

    def require_unborrowed(self, owner_name: str, span: Span) -> None:
        active = [item for item in self.borrows if item.owner == owner_name]
        if active:
            self.diagnostics.raise_error(
                "OPENC-BORROW-OWNER-ACTIVE-001", Phase.BORROW,
                f"ownership operation on '{owner_name}' conflicts with active borrow(s)",
                span, "borrow.owner",
            )

    def register_allocation(self, pointer_name: str, allocation_id: str, extent: int | None, alignment: int, element_type) -> None:
        self.provenance[pointer_name] = Provenance(
            allocation_id, extent, 0, 0, True, False, alignment, element_type
        )

    def derive_pointer(self, target_name: str, source_name: str, element_offset: int, element_size: int, span: Span) -> None:
        source = self.provenance.get(source_name)
        if source is None:
            self.diagnostics.raise_error(
                "OPENC-PTR-PROVENANCE-001", Phase.UNSAFE,
                f"pointer '{source_name}' has no declared provenance", span, "unsafe.provenance",
            )
        assert source is not None
        target = source.derive(element_offset, element_size)
        if target.extent is not None and not (0 <= target.offset <= target.extent):
            self.diagnostics.raise_error(
                "OPENC-PTR-ARITH-BOUNDS-001", Phase.UNSAFE,
                "pointer arithmetic leaves the originating allocation", span, "unsafe.provenance",
            )
        self.provenance[target_name] = target

    def free_allocation(self, pointer_name: str, span: Span) -> None:
        pointer = self.provenance.get(pointer_name)
        if pointer is None:
            self.diagnostics.raise_error(
                "OPENC-MEM-FREE-PROVENANCE-001", Phase.OWNERSHIP,
                f"pointer '{pointer_name}' is not a known allocation base", span, "ownership.memory",
            )
        assert pointer is not None
        if pointer.offset != 0:
            self.diagnostics.raise_error(
                "OPENC-MEM-FREE-BASE-001", Phase.OWNERSHIP,
                "only the allocation-base pointer may be freed", span, "ownership.memory",
            )
        if not pointer.alive:
            self.diagnostics.raise_error(
                "OPENC-MEM-DOUBLE-FREE-001", Phase.OWNERSHIP,
                f"allocation referenced by '{pointer_name}' was already freed", span, "ownership.memory",
            )
        allocation_id = pointer.allocation_id
        for value in self.provenance.values():
            if value.allocation_id == allocation_id:
                value.alive = False
                value.generation += 1

    def check_dereference(self, pointer_name: str, size: int, alignment: int, span: Span) -> None:
        pointer = self.provenance.get(pointer_name)
        if pointer is None:
            return  # Unknown foreign provenance is checked dynamically by the backend/runtime.
        if not pointer.alive:
            self.diagnostics.raise_error(
                "OPENC-MEM-USE-AFTER-FREE-001", Phase.UNSAFE,
                f"pointer '{pointer_name}' refers to ended storage", span, "unsafe.provenance",
            )
        if pointer.one_past:
            self.diagnostics.raise_error(
                "OPENC-PTR-ONE-PAST-DEREF-001", Phase.UNSAFE,
                "one-past pointer cannot be dereferenced", span, "unsafe.provenance",
            )
        if pointer.extent is not None and pointer.offset + size > pointer.extent:
            self.diagnostics.raise_error(
                "OPENC-PTR-DEREF-BOUNDS-001", Phase.UNSAFE,
                "pointer dereference exceeds originating allocation", span, "unsafe.provenance",
            )
        if pointer.offset % alignment != 0:
            self.diagnostics.raise_error(
                "OPENC-PTR-ALIGNMENT-001", Phase.UNSAFE,
                f"pointer offset {pointer.offset} does not satisfy alignment {alignment}",
                span, "unsafe.alignment",
            )
