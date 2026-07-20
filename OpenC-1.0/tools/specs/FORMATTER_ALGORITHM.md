# Deterministic Formatter Algorithm

1. Decode and parse valid source with comments retained as trivia.
2. Attach a line comment to the nearest preceding token on its line; attach a block comment to the following node unless it trails a token on the same line.
3. Print indentation in four spaces per block depth.
4. Print one space around binary and assignment operators; none around postfix operators.
5. Keep a syntactic form on one line only when its canonical flat rendering is at most the configured width and contains no attached line comment.
6. Otherwise break function parameters, call arguments, array/aggregate fields, enum items, and import lists one item per line, indent once, and include a trailing comma where grammar permits.
7. Binary expressions break before the operator at the precedence-group boundary, preserving explicit parentheses when removing them could change parse or aid comment attachment.
8. Print one blank line between top-level declarations and no more than the configured number of internal blank lines.
9. Emit UTF-8 without BOM and LF endings.
10. Reparse formatted output and require an equivalent syntax tree before writing.

The formatter never changes declaration order, qualifier spelling, numeric literal value, text escape value, or comment text.
