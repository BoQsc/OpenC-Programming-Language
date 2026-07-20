# OpenC minimum Hosted standard-library source

Status: **D IMPLEMENTATION BUILT, TESTED, AND EXECUTED ON WINDOWS**

The authored D modules implement the minimum Hosted families:

```text
system.io
system.memory
system.file
system.path
system.process
system.text
```

They depend only on the first-party OpenC runtime and the D standard library.
Windows behavior is exercised by unit tests, runtime fixtures, maintained
programs, and the compiler-in-OpenC bootstrap.
