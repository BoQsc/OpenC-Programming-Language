
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

Every automatable rule has an active fixture and expected result.
Non-automatable rules state the required review evidence. The current 1.0
candidate corpus executes all 278 authored fixtures; all 466 active rules have
dedicated fixture coverage and the authoring backlog is empty.

All 174 grammar productions name an accepting fixture and a rejecting fixture
in `standard/core/conformance/OpenC_Core_Grammar_Coverage.json`.

`active_rules` and `expected.rules` identify normative rules exercised by a
fixture. `expected.expected.diagnostic_rule` identifies the exact compiler
diagnostic expected from a rejecting source fixture. Keeping these fields
separate prevents historical provenance from being mistaken for diagnostic-ID
compatibility.
