"""Flow-sensitive initialization, optional presence, status/out, and cleanup state."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Iterable

from .diagnostics import DiagnosticEngine
from .model import Phase, SemanticType, Span


class InitState(str, Enum):
    UNINITIALIZED = "uninitialized"
    CONDITIONAL = "conditional"
    INITIALIZED = "initialized"
    MAYBE_INITIALIZED = "maybe_initialized"
    AMBIGUOUS = "ambiguous"
    MOVED = "moved"
    DESTROYED = "destroyed"


class PresenceState(str, Enum):
    UNKNOWN = "unknown"
    ABSENT = "absent"
    PRESENT = "present"
    MAYBE = "maybe"


class OwnerState(str, Enum):
    NONE = "none"
    UNINITIALIZED = "uninitialized"
    CONDITIONAL = "conditional"
    LIVE = "live"
    CLEANUP_RESERVED = "cleanup_reserved"
    DISMANTLING = "dismantling"
    MOVED = "moved"
    MAYBE_LIVE = "maybe_live"
    AMBIGUOUS = "ambiguous"
    DESTROYED = "destroyed"


@dataclass(slots=True)
class FlowBinding:
    name: str
    type: SemanticType
    declared_span: Span
    init: InitState = InitState.UNINITIALIZED
    presence: PresenceState = PresenceState.UNKNOWN
    owner: OwnerState = OwnerState.NONE
    lineage: int | None = None
    mutable: bool = True
    cleanup_action: str | None = None
    borrow_readers: int = 0
    borrow_writer: bool = False

    def clone(self) -> "FlowBinding":
        return FlowBinding(
            self.name, self.type, self.declared_span, self.init, self.presence,
            self.owner, self.lineage, self.mutable, self.cleanup_action,
            self.borrow_readers, self.borrow_writer,
        )


@dataclass(slots=True)
class StatusLineage:
    lineage_id: int
    status_names: set[str]
    outputs: set[str]
    owning_outputs: set[str]
    resolved: str = "unknown"  # unknown | success | failure

    def clone(self) -> "StatusLineage":
        return StatusLineage(
            self.lineage_id, set(self.status_names), set(self.outputs),
            set(self.owning_outputs), self.resolved,
        )


@dataclass(slots=True)
class FlowState:
    bindings: dict[str, FlowBinding] = field(default_factory=dict)
    lineages: dict[int, StatusLineage] = field(default_factory=dict)
    next_lineage: int = 1
    reachable: bool = True
    unsafe_depth: int = 0
    loop_depth: int = 0

    def clone(self) -> "FlowState":
        return FlowState(
            {name: binding.clone() for name, binding in self.bindings.items()},
            {key: value.clone() for key, value in self.lineages.items()},
            self.next_lineage, self.reachable, self.unsafe_depth, self.loop_depth,
        )

    def declare(self, binding: FlowBinding, diagnostics: DiagnosticEngine) -> None:
        if binding.name in self.bindings:
            diagnostics.raise_error(
                "OPENC-NAME-DUPLICATE-001", Phase.DECLARATION,
                f"duplicate local declaration '{binding.name}'", binding.declared_span,
                "flow.declaration",
            )
        self.bindings[binding.name] = binding

    def get(self, name: str, diagnostics: DiagnosticEngine, span: Span) -> FlowBinding:
        binding = self.bindings.get(name)
        if binding is None:
            diagnostics.raise_error(
                "OPENC-NAME-UNKNOWN-001", Phase.NAME,
                f"unknown local name '{name}'", span, "flow.name",
            )
        assert binding is not None
        return binding

    def new_lineage(self, status_name: str, outputs: Iterable[str], owning_outputs: Iterable[str] = ()) -> int:
        lineage_id = self.next_lineage
        self.next_lineage += 1
        self.lineages[lineage_id] = StatusLineage(
            lineage_id, {status_name}, set(outputs), set(owning_outputs)
        )
        return lineage_id

    def add_status_copy(self, lineage_id: int, status_name: str) -> None:
        self.lineages[lineage_id].status_names.add(status_name)

    def lose_status_name(self, status_name: str, diagnostics: DiagnosticEngine, span: Span) -> None:
        for lineage in self.lineages.values():
            if status_name not in lineage.status_names:
                continue
            lineage.status_names.remove(status_name)
            if not lineage.status_names and lineage.resolved == "unknown":
                unresolved = [name for name in lineage.outputs if self.bindings.get(name) and self.bindings[name].init == InitState.CONDITIONAL]
                if unresolved:
                    diagnostics.raise_error(
                        "OPENC-OUT-PROOF-LOSS-001", Phase.FLOW,
                        f"overwriting '{status_name}' loses the only proof carrier for output(s): {', '.join(sorted(unresolved))}",
                        span, "flow.status_out",
                    )

    def resolve_lineage(self, lineage_id: int, outcome: str) -> None:
        lineage = self.lineages[lineage_id]
        lineage.resolved = outcome
        for name in lineage.outputs:
            binding = self.bindings.get(name)
            if binding is None or binding.lineage != lineage_id:
                continue
            if outcome == "success":
                binding.init = InitState.INITIALIZED
                binding.owner = OwnerState.LIVE if name in lineage.owning_outputs else binding.owner
                if binding.type.kind == "optional":
                    binding.presence = PresenceState.MAYBE
            else:
                binding.init = InitState.UNINITIALIZED
                if name in lineage.owning_outputs:
                    binding.owner = OwnerState.UNINITIALIZED
            binding.lineage = None

    def require_readable(self, name: str, diagnostics: DiagnosticEngine, span: Span) -> FlowBinding:
        binding = self.get(name, diagnostics, span)
        if binding.init != InitState.INITIALIZED:
            rule = "OPENC-SAFE-INIT-001"
            message = f"'{name}' is not definitely initialized"
            if binding.init == InitState.CONDITIONAL:
                rule = "OPENC-OUT-PROOF-001"
                message = f"output '{name}' cannot be used until its status is proven successful"
            elif binding.init == InitState.MOVED:
                rule = "OPENC-OWN-USE-AFTER-MOVE-001"
                message = f"owner '{name}' was moved"
            elif binding.init == InitState.DESTROYED:
                rule = "OPENC-LIFETIME-USE-AFTER-END-001"
                message = f"'{name}' has been destroyed"
            diagnostics.raise_error(rule, Phase.FLOW, message, span, "flow.initialization")
        return binding

    def require_assignable(self, name: str, diagnostics: DiagnosticEngine, span: Span) -> FlowBinding:
        binding = self.get(name, diagnostics, span)
        if not binding.mutable:
            diagnostics.raise_error(
                "OPENC-CONST-ASSIGN-001", Phase.FLOW,
                f"cannot assign to const binding '{name}'", span, "flow.mutability",
            )
        if binding.owner in {OwnerState.LIVE, OwnerState.CLEANUP_RESERVED, OwnerState.DISMANTLING}:
            diagnostics.raise_error(
                "OPENC-OWN-OVERWRITE-001", Phase.OWNERSHIP,
                f"cannot overwrite live owner '{name}'", span, "ownership.overwrite",
            )
        if binding.init == InitState.CONDITIONAL:
            diagnostics.raise_error(
                "OPENC-OUT-OVERWRITE-001", Phase.FLOW,
                f"cannot overwrite unresolved output '{name}'", span, "flow.status_out",
            )
        return binding

    def merge(self, other: "FlowState") -> "FlowState":
        if not self.reachable:
            return other.clone()
        if not other.reachable:
            return self.clone()
        result = self.clone()
        result.next_lineage = max(self.next_lineage, other.next_lineage)
        all_names = set(self.bindings) | set(other.bindings)
        result.bindings = {}
        for name in all_names:
            left = self.bindings.get(name)
            right = other.bindings.get(name)
            if left is None or right is None:
                continue
            merged = left.clone()
            merged.init = merge_init(left.init, right.init, left.lineage, right.lineage)
            merged.lineage = left.lineage if left.lineage == right.lineage and merged.init == InitState.CONDITIONAL else None
            merged.presence = merge_presence(left.presence, right.presence)
            merged.owner = merge_owner(left.owner, right.owner)
            merged.cleanup_action = left.cleanup_action if left.cleanup_action == right.cleanup_action else None
            merged.borrow_readers = max(left.borrow_readers, right.borrow_readers)
            merged.borrow_writer = left.borrow_writer or right.borrow_writer
            result.bindings[name] = merged
        result.lineages = {}
        for lineage_id in set(self.lineages) & set(other.lineages):
            left_lineage = self.lineages[lineage_id]
            right_lineage = other.lineages[lineage_id]
            if left_lineage.resolved == right_lineage.resolved:
                merged = left_lineage.clone()
                merged.status_names &= right_lineage.status_names
                result.lineages[lineage_id] = merged
        result.reachable = self.reachable or other.reachable
        result.unsafe_depth = min(self.unsafe_depth, other.unsafe_depth)
        result.loop_depth = min(self.loop_depth, other.loop_depth)
        return result

    def verify_scope_exit(self, diagnostics: DiagnosticEngine, span: Span, names: Iterable[str] | None = None) -> None:
        selected = names if names is not None else self.bindings.keys()
        for name in selected:
            binding = self.bindings.get(name)
            if binding is None:
                continue
            if binding.owner in {OwnerState.LIVE, OwnerState.DISMANTLING, OwnerState.MAYBE_LIVE, OwnerState.AMBIGUOUS}:
                diagnostics.raise_error(
                    "OPENC-OWN-EXIT-001", Phase.OWNERSHIP,
                    f"owner '{name}' reaches scope exit without transfer or registered cleanup",
                    span, "ownership.exit",
                )
            if binding.init == InitState.CONDITIONAL:
                diagnostics.raise_error(
                    "OPENC-OUT-PROOF-LOSS-001", Phase.FLOW,
                    f"conditional output '{name}' reaches scope exit without success or failure proof",
                    span, "flow.status_out",
                )


def merge_init(left: InitState, right: InitState, left_lineage: int | None, right_lineage: int | None) -> InitState:
    if left == right:
        if left == InitState.CONDITIONAL and left_lineage != right_lineage:
            return InitState.AMBIGUOUS
        return left
    if {left, right} == {InitState.INITIALIZED, InitState.UNINITIALIZED}:
        return InitState.MAYBE_INITIALIZED
    if InitState.AMBIGUOUS in {left, right}:
        return InitState.AMBIGUOUS
    if InitState.MOVED in {left, right}:
        return InitState.AMBIGUOUS
    if InitState.DESTROYED in {left, right}:
        return InitState.AMBIGUOUS
    if InitState.CONDITIONAL in {left, right}:
        return InitState.AMBIGUOUS
    return InitState.MAYBE_INITIALIZED


def merge_presence(left: PresenceState, right: PresenceState) -> PresenceState:
    if left == right:
        return left
    if PresenceState.UNKNOWN in {left, right}:
        return PresenceState.UNKNOWN
    return PresenceState.MAYBE


def merge_owner(left: OwnerState, right: OwnerState) -> OwnerState:
    if left == right:
        return left
    if {left, right} <= {OwnerState.UNINITIALIZED, OwnerState.MOVED, OwnerState.DESTROYED, OwnerState.NONE}:
        return OwnerState.UNINITIALIZED
    if OwnerState.LIVE in {left, right} or OwnerState.CLEANUP_RESERVED in {left, right}:
        return OwnerState.MAYBE_LIVE
    return OwnerState.AMBIGUOUS
