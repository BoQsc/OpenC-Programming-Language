# Fixture format

Canonical fixture records conform to `schemas/FIXTURE.schema.json` and are
listed by `conformance/fixtures/MANIFEST.json`.

```json
{
  "schema": "openc.fixture.v1",
  "id": "invalid/implicit_narrow",
  "kind": "invalid",
  "origin": "OpenC Standard Draft 0.10 validation/invalid/implicit_narrow",
  "evidence_state": "EXECUTED_PASS_WINDOWS_X86_64_RC1",
  "active_rules": ["OPENC-CONVERT-LOSSY-001"],
  "source_files": ["conformance/fixtures/invalid/implicit_narrow/main"],
  "expected": {
    "edition": "OpenC Core 1.0 Current",
    "fixture_kind": "source",
    "rules": ["OPENC-CONVERT-LOSSY-001"],
    "expected": {
      "result": "reject",
      "rule": "OPENC-CONVERT-LOSSY-001",
      "diagnostic_rule": "OPENC-TYPE-MISMATCH-001"
    }
  }
}
```

`active_rules` and `expected.rules` are normative coverage identities.
`diagnostic_rule` is the exact implementation diagnostic required from a
rejecting fixture. `rule` remains the primary normative rule tested. Runtime
fixtures match their authored runtime outcome contract rather than requiring a
compile-time diagnostic.

Fixture IDs and `origin` provenance are stable. Adapting a historical source to
Current changes its execution target but does not erase its origin.
