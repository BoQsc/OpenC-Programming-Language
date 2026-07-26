# Conformance Authoring and Execution

Every automatable rule should receive at least one direct fixture. Where
meaningful it also receives one rejection or boundary fixture. State-machine
rules should receive branch, merge, loop, early-return, and failure-path cases.

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

A fixture records Current edition, historical origin where applicable, source
units, project/module context, normative active rules, exact diagnostic
expectation when rejecting, expected runtime outcome, cleanup trace, and target.

The current post-tag 1.0 candidate corpus contains 278 executed passing
fixtures on Windows x86-64. It gives dedicated coverage to all 466 active
rules; zero rules remain in the explicit authoring queue. All 174 grammar
productions have an executed accepting/rejecting fixture pair.
