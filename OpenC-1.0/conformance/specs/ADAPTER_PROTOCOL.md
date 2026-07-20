# Implementation Adapter Protocol

An adapter receives one JSON request naming:

```text
candidate
fixture ID and kind
source-unit bytes and hashes
module/project context
target record
expected evidence channels
time and memory limits
```

It returns one structured result containing implementation identity, phase reached, acceptance/rejection, diagnostics, runtime output, exit result, cleanup trace, target fault, unsupported features, limits, duration, and infrastructure failures.

The adapter may invoke a compiler process, interpreter, library API, or remote target runner. The transport is not normative; the result meaning is.
