# Conformance Authoring and Execution

Every automatable rule receives at least one direct fixture. Where meaningful it also receives one rejection or boundary fixture. State-machine rules receive branch, merge, loop, early-return, and failure-path cases.

Fixture kinds:

```text
source-valid
source-invalid
runtime-success
runtime-checked-failure
runtime-target-fault
multi-source
target-record
human-review
```

A fixture records candidate revision, source units, project/module context, target record, expected phase, expected primary rule ID, expected runtime outcome, cleanup trace, and required implementation stage.

The authored matrices in this package are complete work queues. Actual fixture execution remains pending until a complete implementation exists.
