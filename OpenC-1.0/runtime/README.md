# OpenC runtime source

Status: **WINDOWS C RUNTIME BUILT AND EXECUTED; LEGACY D RUNTIME RETAINED FOR AUDIT**

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

The common/Windows C runtime is the required standalone compiler provider and
is exercised by native compiler, runtime-fixture, and maintained-program
gates. The D runtime remains legacy bootstrap/reference source. Linux and
freestanding providers remain outside the supported 1.0 verification claim.
