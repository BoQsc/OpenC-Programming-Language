# Fixture Format

Fixtures conform to `schemas/FIXTURE.schema.json`.

Example:

```json
{
  "schema": "openc.fixture.v1",
  "id": "type/implicit_lossy_i64_i32",
  "candidate": "OpenC Core Candidate 2 — Implementation Readiness Revision 1",
  "kind": "source-invalid",
  "rules": ["OPENC-CONVERT-LOSSY-001"],
  "sources": [
    {
      "name": "main",
      "module": "main",
      "encoding": "utf-8",
      "content": "i32 main(){i64 a=1;i32 b=a;return b;}\n"
    }
  ],
  "expected": {
    "phase": "type",
    "primary_rule": "OPENC-CONVERT-LOSSY-001"
  }
}
```

Fixture IDs are stable. A changed expected meaning receives an explicit compatibility event rather than silently rewriting historical evidence.
