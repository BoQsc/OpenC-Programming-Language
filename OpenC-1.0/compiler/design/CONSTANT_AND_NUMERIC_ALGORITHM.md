# Constant and Numeric Evaluation

Use arbitrary-precision mathematical integers during parsing and constant evaluation, then apply the exact destination and operation rules.

- all integer literal bases use the same i32-then-i64 unconstrained default;
- ordinary integer arithmetic is checked;
- division truncates toward zero and remainder follows the dividend sign;
- division by zero and invalid shifts are checked failures;
- fixed-width signed integers use two's-complement values;
- wrapping and saturating behavior use the closed intrinsic set;
- floating values use binary32/binary64 with round-to-nearest, ties-to-even;
- compile-time evaluation cannot hide a runtime checked failure.

Constant folding must preserve the runtime failure category, evaluation order, and target record.
