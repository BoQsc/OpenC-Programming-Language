# Core IR and Lowering Contract

The reference exchange IR is a typed control-flow graph described by `schemas/CORE_IR.schema.json`. It is not mandated as an implementation's internal representation.

Lowering must make these operations explicit:

- checked, wrapping, and saturating arithmetic;
- bounds and optional checks;
- status/out transactional commit;
- resource-construction reservation and commit;
- ownership move;
- borrow begin/end;
- cleanup registration and LIFO execution;
- storage lifetime begin/end;
- pointer provenance operations;
- checked failure and target fault as distinct terminators.

Return values and ownership transfers are prepared before cleanup runs. The backend must not delegate OpenC overflow, pointer, or lifetime meaning to a host language whose semantics are weaker.
