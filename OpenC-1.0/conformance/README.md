
# OpenC conformance authoring

Conformance material is an authored contract until executed by a recorded implementation adapter.

```text
fixtures/valid
fixtures/invalid
fixtures/diagnostic
fixtures/runtime
fixtures/multi_source
fixtures/command
fixtures/records
```

Every automatable rule should eventually have an active fixture and expected
result. Non-automatable rules state the required review evidence. The 1.0
candidate executes all 268 authored fixtures; 331 active rules have dedicated
fixture coverage and 135 remain in the explicit authoring backlog.

`active_rules` and `expected.rules` identify normative rules exercised by a
fixture. `expected.expected.diagnostic_rule` identifies the exact compiler
diagnostic expected from a rejecting source fixture. Keeping these fields
separate prevents historical provenance from being mistaken for diagnostic-ID
compatibility.
