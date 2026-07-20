# Module and Name Resolution Algorithm

1. Load the declared project-context module map.
2. Decode and parse every source unit assigned to the active build.
3. Evaluate bounded `when` conditions from declared build context.
4. Merge selected top-level declarations from all units sharing one logical module.
5. Reject duplicate module declarations and import cycles.
6. Build private and exported declaration tables independent of source-unit order.
7. Resolve each source unit's imports locally; imports are not re-exported.
8. Resolve unqualified local names, then declarations in the current module, then unambiguous imported short qualifiers.
9. Require an import even for full qualification.
10. Reject shadowing and ambiguous candidates with origin spans.

The module-interface exchange record is defined by `schemas/MODULE_INTERFACE.schema.json`. Filesystem layout and source extension remain project-tool policy, not Core semantics.
