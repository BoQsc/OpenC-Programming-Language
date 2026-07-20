# OpenC implementation source — original handoff boundary

This canonical tree contains concrete source for every implementation area planned for OpenC 1.0:

```text
reference compiler
informative bootstrap compiler
Core and Hosted runtime
Linux provider
Windows provider
freestanding provider
minimum Hosted standard library
compiler driver
formatter
language server
rule explanation tool
project/context tool
conformance runner
package and release tools
unit/integration test source
conformance fixture source
maintained Core and Hosted programs
build, clean, test, archive, and verification source
```

At handoff, the claim was deliberately limited:

```text
source authored:       YES
source inventory:      COMPLETE BY CONTRACT
compiled:              NO
linked:                NO
implementation tests:  NOT EXECUTED
conformance fixtures:  NOT EXECUTED
Linux verified:        NO
Windows verified:      NO
freestanding verified: NO
independent review:    PENDING
release ready:         NO
```

A future builder must treat every compiler, runtime, library, and tool defect discovered during compilation or execution as an implementation finding. Where source and standard disagree, the standard is authoritative.

Local verification has now begun. This document preserves the handoff boundary; current results are recorded in `VERIFICATION_STATUS.md`.
