# Official Formatter Specification

The formatter is deterministic and semantics-preserving.

Canonical defaults:

```text
UTF-8 without BOM
LF output
4-space indentation
no tab indentation
opening brace on the declaration/control line
one space around binary operators
no space before call parentheses
semicolon on ordinary statements
no trailing semicolon after struct/resource/enum declaration blocks
trailing comma in multiline aggregate/array/enum lists
100-column preferred wrap target; correctness never depends on width
```

The formatter parses valid Core source and prints from the syntax tree. It does not repair invalid source silently. `openc fmt --check` exits nonzero when output would change.
