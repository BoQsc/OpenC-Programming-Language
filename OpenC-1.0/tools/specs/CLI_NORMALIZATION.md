# CLI Normalization

Classical invocation is portable and primary:

```text
openc build --profile strict --target linux-x86_64
openc build --profile=strict --target=linux-x86_64
```

The OpenC-aware parenthesized alternative is accepted when the complete call arrives as one shell argument:

```text
openc 'build(profile="strict", target="linux-x86_64")'
```

PowerShell also accepts the single-quoted form. Other shells may require their ordinary quoting rules. The tool parser normalizes both forms into the same ordered option record.

Parenthesized grammar:

```text
invocation  = command "(" [ named_argument { "," named_argument } ] ")"
named_argument = identifier "=" scalar
scalar      = quoted_text | integer | true | false
```

Duplicate options, unknown names, mixed positional/named ambiguity, and conflicting classical/parenthesized values are diagnostics. The parenthesized form does not interpret arbitrary OpenC expressions and executes no code.
