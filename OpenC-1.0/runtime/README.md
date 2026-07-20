# OpenC runtime source

Status: **D RUNTIME BUILT, TESTED, AND EXECUTED ON WINDOWS; ALTERNATIVE C PROVIDERS UNVERIFIED**

The runtime source includes:

```text
Core status, optional, slice, and typed-storage representations
checked integer and fault helpers
console output
memory allocation and byte operations
file handles and byte I/O
process arguments and exit
Linux and Windows startup modules
freestanding hook installation
```

The canonical D runtime is exercised by unit tests, runtime fixtures, and
maintained programs on Windows. The separate common-C, Linux, Windows-C, and
freestanding providers remain outside the supported 1.0 verification claim.
