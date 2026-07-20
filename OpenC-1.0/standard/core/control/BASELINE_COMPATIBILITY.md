# CC2 to IR1 Compatibility

IR1 is a pre-freeze candidate correction, not a released compatibility promise.

Potentially source-affecting corrections:

- `construct` accepts an exact typed value and is restricted to a new local `ref` initializer;
- module path segments may explicitly use predeclared type words, while all other reserved words remain forbidden;
- switch subjects and cases now have a closed domain;
- `scope` arguments are limited to literals and stable name paths;
- unchecked integer arithmetic is retired in favor of safe wrapping intrinsics;
- byte writes cannot mutate a live non-byte typed representation;
- whole arrays and ownership-bearing resource fields are not address-of operands.

Implementations should target IR1 rather than relying on ambiguous CC2 wording. Every correction remains subject to independent review before Core freeze.
