# Recommended Reference Implementation Layout

```text
reference/
  driver/
  source/
  lexer/
  parser/
  ast/
  modules/
  symbols/
  types/
  constants/
  overloads/
  cfg/
  flow/
  status_out/
  ownership/
  borrow/
  cleanup/
  pointers/
  unsafe/
  ir/
  targets/
  backends/
  diagnostics/
  conformance/
  tests/
```

D remains the recommended reference implementation language because it supports direct systems programming and keeps the implementation independent from C source compatibility. The implementation shall use only declared dependencies and record exact compiler/toolchain versions.
