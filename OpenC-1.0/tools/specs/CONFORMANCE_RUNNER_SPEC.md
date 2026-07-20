# Conformance Runner Specification

`openc validate` executes fixtures through an implementation adapter. It never scrapes human terminal text when structured output is available.

Each result distinguishes:

```text
language pass
language failure
unsupported feature
implementation crash
infrastructure failure
timeout
```

Only an executed expected language outcome counts as a pass. The report conforms to `schemas/CONFORMANCE_RESULT.schema.json`, records fixture and implementation hashes, and lists extensions and implementation limits.
