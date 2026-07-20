# Type, Conversion, and Overload Algorithms

## Type identity

Types are structural for built-in constructors and nominal for declared struct, enum, and resource types. Constness, fixed-array length, slice mutability, pointer pointed-to constness, and parameter modes participate where specified.

## Implicit conversions

Build the finite conversion set from the active rule index. An implicit conversion is viable only when every possible source value is preserved. No implementation-defined ranking exists.

## Overload selection

1. Gather declarations with matching name and argument count.
2. Require parameter-mode compatibility.
3. If exactly one exact type-and-mode match exists, select it.
4. Otherwise retain candidates requiring only permitted lossless conversions.
5. Select only when exactly one candidate remains.
6. Return type does not disambiguate.
7. Emit all viable candidates and origin spans on ambiguity.

The selected declaration is fixed before argument evaluation.
