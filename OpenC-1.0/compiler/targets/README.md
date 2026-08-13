# OpenC target records

The authored target records describe the facts used by the compiler and build
tools. They are provider inputs; each record's `evidence_state` identifies the
separate verification claim actually reached.

```text
linux-x86_64.json
windows-x86_64.json
freestanding-x86_64.json
```

The Windows record contains the SH-15 Microsoft x64 ABI contract: LLP64 data
layout, positional integer/vector register assignment, shadow and stack rules,
aggregate and hidden-return classification, volatile/nonvolatile registers,
natural/explicit/union/bitfield layout, and version-1 unwind requirements. It
also contains the SH-16 deterministic PE32+ artifact and CRT-free runtime
contract: sections, directories, security flags, relocations, unwind, TLS,
system-DLL import limits, UTF-8 boundaries, heap, files, cleanup, and the
explicit bounded proof profile. Win32 library names and types remain outside
the language and target record.
