# Implementer Start Here

## First target

Build a complete Core frontend before Hosted, Native, script/live, or concurrency work.

```text
I0 source → tokens → AST
I1 modules → names → types → constants → overloads
I2 CFG → initialization → optional → status/out proof
I3 resources → ownership → cleanup → borrows
I4 storage → raw pointers → provenance → unsafe validation
I5 typed IR → interpreter or backend → runtime evidence
```

## Minimum repository modules

```text
source_manager
lexer
parser
ast
module_resolver
symbol_table
type_system
constant_evaluator
overload_resolver
expression_checker
cfg_builder
flow_analysis
status_out_analysis
ownership_analysis
borrow_analysis
cleanup_analysis
pointer_analysis
unsafe_validator
ir_builder
backend
diagnostic_engine
conformance_adapter
driver
```

Use `implementation/IMPLEMENTATION_WORK_MATRIX.json` as the complete rule queue and `implementation/GRAMMAR_IMPLEMENTATION_MATRIX.json` as the parser queue. A stage is complete only when its required fixture set executes and its machine-readable evidence record validates.
