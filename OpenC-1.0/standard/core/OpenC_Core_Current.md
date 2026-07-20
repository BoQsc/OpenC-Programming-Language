# OpenC Core — 1.0 Release-Candidate Standard

- Release-candidate version: `1.0.0-rc.1`
- Authority state: **owner-ratified release-candidate baseline; not published**
- Source lineage: OpenC Core Candidate 2, Correction 001, and Implementation Readiness Revision 1
- Active normative rules: 466
- Normative grammar entries: 174

> Historical naming note: the body retains the lineage term “Core Candidate 2” where it identifies the audited baseline. Within this canonical tree, this file is the current Core development authority; no separately packaged candidate overrides it.

## Purpose

OpenC Core Candidate 2 is the first integrated candidate after the research-draft and patch-stack phases. It closes the planned Core coherence work for compile-time conditions, declarations, recoverable failure, resources, cleanup, pointer provenance, numeric execution, modules, text/collections, optionals/aggregates, functions/constants/targets, grammar authority, diagnostics, security taxonomy, and rule disposition.

"Complete candidate" means that every currently planned Core 1.0 language family has authored syntax and semantics in one authority set. It does **not** mean independent review, complete implementation, executed conformance, release readiness, Hosted readiness, Native ABI freeze, or final 1.0 ratification.

## Core boundary

Included:

- UTF-8 source, lexical grammar, logical modules, and structured `when` selection;
- primitive and constructed Core types;
- declarations, constants, expressions, deterministic evaluation, and exact numeric semantics;
- statements, functions, structs, enums, arrays, slices, immutable text, optional values, `status`, and `out`;
- resources, ownership, borrowing, typed storage, raw pointers, unsafe operations, cleanup, and flow analysis;
- target context, portability obligations, structured diagnostics, and conformance identities.

Excluded from Core Candidate 2:

- Hosted process, file, allocator, console, path, and encoding providers;
- Native ABI/FFI and linker syntax;
- script/live conveniences and project/package commands;
- strict/critical assurance policy;
- threads, atomics, shared values, channels, time, cancellation, groups, and completion streams;
- source-file extension policy and release governance.

## Authority

Within this canonical development tree:

1. `standard/core/grammar/OpenC_Core_Grammar.ebnf` defines source structure.
2. This rulebook defines semantic validity and behavior.
3. `standard/core/metadata/OpenC_Core_Rule_Index.json` defines machine-readable rule identity.
4. `standard/core/metadata/OpenC_Core_Diagnostic_Catalog.json` defines diagnostic phase/category defaults.
5. `standard/core/metadata/OpenC_Core_Term_Index.json` defines canonical terminology.
6. Security, rationale, implementation, proposal, and historical documents are explanatory unless a normative rule explicitly incorporates them.

A disagreement between the grammar and this rulebook is a specification defect; implementations do not guess.

# Terms


**source unit** — one UTF-8 OpenC source sequence assigned to one logical module by declared project context.

**logical module** — the order-independent declaration set formed by all source units assigned the same module identity.

**object** — initialized storage with a complete type and active lifetime.

**storage** — memory capable of containing an object; storage alone is not a value.

**value** — the abstract typed result represented by an expression or object.

**plain value** — a copyable non-resource value whose type carries no unique ownership obligation.

**owner** — the binding responsible for exactly one resource or owning-pointer obligation.

**borrow** — temporary non-owning access through `ref` or a slice.

**raw pointer** — a low-level address value of type `ptr T` with abstract provenance and offset.

**safe code** — code outside an unsafe region or unsafe function body.

**unsafe operation** — an operation whose validity depends on explicit caller-provided low-level preconditions.

**recoverable failure** — a visible nonzero `status.code` result handled by ordinary control flow.

**checked failure** — a defined structured non-recoverable failure that runs required cleanup.

**target fault** — one bounded target-declared consequence of violating an unsafe precondition.

**resource** — a non-copyable value with one exactly-once outer ownership obligation and zero or more visible nested ownership slots.

**proof lineage** — compiler-only local evidence connecting one fallible call result to the conditional initialization of exactly its `out` targets.

**structured exit** — normal scope completion, `return`, `break`, `continue`, recoverable return, or language-generated checked failure.

**Core constant expression** — the finite side-effect-free expression subset used for module constants, switch cases, and plain field defaults.

**build-context expression** — the smaller context-only expression subset used by `when`.


**binding** — a source name associated with one declared value, reference, pointer, owner, output slot, function, type, module, or constant according to its declaration kind.

**complete type** — a type whose size, alignment, value rules, and required fields or members are known in the current translation context.

**full expression** — an expression whose evaluation is completed before the next enclosing sequencing boundary defined by the grammar.

**observable effect** — a value result, mutation, ownership transition, cleanup action, diagnostic, checked failure, target fault, or externally visible target action whose order or presence is defined by Core.

**no-fail operation** — an operation whose valid-input contract admits neither recoverable failure, checked failure, nor target fault; internal unsafe work is permitted only when a safe wrapper proves all preconditions for every valid input.

**provenance** — abstract identity connecting a raw pointer to one active object, array, typed-storage lifetime, allocation, or declared target region.

**lifetime generation** — one specific activation of an object lifetime in storage; reconstruction creates a new generation and does not revive pointers or borrows from an earlier generation.

**implementation limit** — a declared finite capacity of an implementation whose exhaustion produces a structured diagnostic rather than altered language meaning.

**source span** — a half-open region identified by 1-based logical line and Unicode-scalar column coordinates plus 0-based UTF-8 byte offset and byte length.

**stable owner destination** — a named owner binding, return slot, ownership-bearing aggregate field at commit, or proven owning output slot that can carry exactly one ownership obligation without an unnamed temporary.

**addressable location** — a stable live object, eligible field, or element location for which Core defines an address-of result type and lifetime bound.

**reserved word** — a word spelling that the lexical phase classifies for fixed language syntax and that cannot be introduced as an ordinary identifier.

**predeclared type word** — a primitive type spelling recognized by type grammar; it cannot be rebound, but may occur as an imported module segment under the explicit module-name rules.

# Normative grammar

```ebnf
source_unit          = { import_decl } { top_decl } ;

import_decl          = "import" module_name ";" ;
module_name          = identifier { "." identifier } ;
qualified_name       = identifier { "." identifier } ;

top_decl            = [ "export" ]
                       ( function_decl
                       | struct_decl
                       | enum_decl
                       | resource_decl
                       | module_const_decl
                       | when_decl ) ;

module_const_decl    = "const" module_const_type identifier
                       "=" constant_expression ";" ;
module_const_type    = module_const_value_type | optional_core_type ;
module_const_value_type = type_atom [ fixed_array_suffix ] ;

struct_decl          = "struct" identifier "{" { struct_field_decl } "}" ;
resource_decl        = "resource" identifier "{" { resource_field_decl } "}" ;
struct_field_decl    = struct_field_type identifier
                       [ "=" constant_expression ] ";" ;
resource_field_decl  = resource_value_field_decl
                     | resource_owned_pointer_field_decl ;
resource_value_field_decl = struct_field_type identifier
                            [ "=" constant_expression ] ";" ;
resource_owned_pointer_field_decl = "own" ptr_type identifier ";" ;
struct_field_type    = field_value_type | ptr_type | optional_type ;
field_value_type     = [ "const" ] type_atom [ fixed_array_suffix ] ;

enum_decl            = "enum" [ unsigned_integer_type ] identifier
                       "{" enum_item { "," enum_item } [ "," ] "}" ;
enum_item            = identifier [ "=" constant_integer_expression ] ;

function_decl        = [ "unsafe" ] function_result identifier
                       "(" [ parameter { "," parameter } ] ")" block ;
function_result      = "void" | ordinary_result_type | owning_pointer_result ;
ordinary_result_type = value_type | ref_type | ptr_type | optional_type ;
owning_pointer_result = "own" ptr_type ;

parameter            = out_own_pointer_parameter | out_parameter
                     | own_parameter | ordinary_parameter ;
ordinary_parameter   = parameter_type identifier ;
parameter_type       = value_type | ref_type | ptr_type | optional_type ;
own_parameter        = "own" own_parameter_target identifier ;
own_parameter_target = ptr_type | qualified_name ;
out_parameter        = "out" output_parameter_type identifier ;
output_parameter_type = output_value_type | ptr_type | optional_core_type ;
output_value_type    = type_atom [ fixed_array_suffix ] ;
out_own_pointer_parameter = "out" "own" ptr_type identifier ;

when_decl            = "when" when_expression "{" { top_decl } "}" ;

block                 = "{" { block_item } "}" ;
block_item            = local_decl | statement ;
local_decl            = local_type identifier [ "=" expression ] ";" ;
local_type            = type ;

type                  = value_type | ref_type | ptr_type
                       | optional_type | storage_type ;
value_type            = [ "const" ] type_atom [ value_suffix ] ;
value_suffix          = fixed_array_suffix | slice_suffix_type ;
ref_type              = "ref" [ "const" ] ref_target ;
ptr_type              = "ptr" [ "const" ] ptr_target ;
optional_type         = [ "const" ] optional_core_type ;
optional_core_type    = "optional" optional_target ;
storage_type          = "storage" storage_target ;
ref_target            = type_atom [ fixed_array_suffix ] ;
ptr_target            = type_atom ;
optional_target       = type_atom [ fixed_array_suffix ] ;
storage_target        = type_atom [ fixed_array_suffix ] ;
type_atom             = primitive_object_type | qualified_name ;
fixed_array_suffix    = "[" constant_integer_expression "]" ;
slice_suffix_type     = "[" "]" ;

primitive_object_type = signed_integer_type | unsigned_integer_type
                      | "isize" | "usize" | "bool" | "byte"
                      | "f32" | "f64" | "text" | "status" ;
signed_integer_type   = "i8" | "i16" | "i32" | "i64" ;
unsigned_integer_type = "u8" | "u16" | "u32" | "u64" ;

statement             = block | expression_stmt | if_stmt | while_stmt
                      | for_stmt | switch_stmt | break_stmt | continue_stmt
                      | return_stmt | scope_stmt | unsafe_stmt | when_stmt ;
expression_stmt       = expression ";" ;
if_stmt               = "if" expression block [ "else" ( block | if_stmt ) ] ;
while_stmt            = "while" expression block ;
for_stmt              = "for" [ for_init ] ";" [ expression ] ";"
                       [ expression ] block ;
for_init              = local_type identifier [ "=" expression ] | expression ;
switch_stmt           = "switch" expression "{" { switch_case }
                       [ default_case ] "}" ;
switch_case           = "case" constant_expression block ;
default_case          = "default" block ;
break_stmt            = "break" ";" ;
continue_stmt         = "continue" ";" ;
return_stmt           = "return" [ expression ] ";" ;
scope_stmt            = "scope" scope_action ";" ;
scope_action          = scope_call | destroy_expr ;
scope_call            = qualified_name "(" [ scope_argument
                       { "," scope_argument } ] ")" ;
scope_argument        = literal | qualified_name ;
unsafe_stmt           = "unsafe" block ;
when_stmt             = "when" when_expression block ;

expression            = assignment_expr ;
assignment_expr       = logical_or_expr [ assignment_op assignment_expr ] ;
assignment_op         = "=" | "+=" | "-=" | "*=" | "/=" | "%="
                      | "&=" | "|=" | "^=" | "<<=" | ">>=" ;
logical_or_expr       = logical_and_expr { "||" logical_and_expr } ;
logical_and_expr      = bitwise_or_expr { "&&" bitwise_or_expr } ;
bitwise_or_expr       = bitwise_xor_expr { "|" bitwise_xor_expr } ;
bitwise_xor_expr      = bitwise_and_expr { "^" bitwise_and_expr } ;
bitwise_and_expr      = equality_expr { "&" equality_expr } ;
equality_expr         = relational_expr { ( "==" | "!=" ) relational_expr } ;
relational_expr       = shift_expr { ( "<" | "<=" | ">" | ">=" ) shift_expr } ;
shift_expr            = additive_expr { ( "<<" | ">>" ) additive_expr } ;
additive_expr         = multiplicative_expr { ( "+" | "-" ) multiplicative_expr } ;
multiplicative_expr   = unary_expr { ( "*" | "/" | "%" ) unary_expr } ;
unary_expr            = ( "!" | "~" | "+" | "-" | "&" | "*" ) unary_expr
                      | cast_expr | cast_unchecked_expr | reinterpret_expr
                      | construct_expr | destroy_expr | type_query_expr
                      | postfix_expr ;
cast_expr             = "cast" "(" type "," expression ")" ;
cast_unchecked_expr   = "cast_unchecked" "(" type "," expression ")" ;
reinterpret_expr      = "reinterpret" "(" type "," expression ")" ;
construct_expr        = "construct" "(" identifier "," expression ")" ;
destroy_expr          = "destroy" "(" ownership_source ")" ;
type_query_expr       = ( "size_of" | "align_of" ) "(" type ")" ;
postfix_expr          = primary_expr { postfix_suffix } ;
postfix_suffix        = call_suffix | member_suffix | index_suffix | range_suffix ;
call_suffix           = "(" [ call_argument { "," call_argument } ] ")" ;
call_argument         = out_argument | expression ;
out_argument          = "out" identifier ;
member_suffix         = "." identifier ;
index_suffix          = "[" expression "]" ;
range_suffix          = "[" [ expression ] ".." [ expression ] "]" ;
primary_expr          = literal | qualified_name | "(" expression ")"
                      | status_initializer | aggregate_initializer
                      | array_initializer ;

status_initializer    = "status" "{" status_code_init
                       [ "," status_message_init ] [ "," ] "}"
                      | "status" "{" status_message_init ","
                       status_code_init [ "," ] "}" ;
status_code_init      = "code" "=" expression ;
status_message_init   = "message" "=" expression ;
aggregate_initializer = qualified_name "{" [ aggregate_field_init
                       { "," aggregate_field_init } [ "," ] ] "}" ;
aggregate_field_init  = ordinary_field_init | ownership_field_init ;
ordinary_field_init   = identifier "=" expression ;
ownership_field_init = "own" identifier "=" ownership_source ;
ownership_source     = identifier { "." identifier } ;
array_initializer    = "{" [ expression { "," expression } [ "," ] ] "}" ;
literal              = integer_literal | float_literal | text_literal
                     | "true" | "false" | "null" | "none" ;

constant_expression          = constant_or_expression ;
constant_or_expression       = constant_and_expression
                               { "||" constant_and_expression } ;
constant_and_expression      = constant_bitwise_or_expression
                               { "&&" constant_bitwise_or_expression } ;
constant_bitwise_or_expression = constant_bitwise_xor_expression
                               { "|" constant_bitwise_xor_expression } ;
constant_bitwise_xor_expression = constant_bitwise_and_expression
                               { "^" constant_bitwise_and_expression } ;
constant_bitwise_and_expression = constant_equality_expression
                               { "&" constant_equality_expression } ;
constant_equality_expression = constant_relational_expression
                               { ( "==" | "!=" ) constant_relational_expression } ;
constant_relational_expression = constant_shift_expression
                               { ( "<" | "<=" | ">" | ">=" ) constant_shift_expression } ;
constant_shift_expression    = constant_additive_expression
                               { ( "<<" | ">>" ) constant_additive_expression } ;
constant_additive_expression = constant_multiplicative_expression
                               { ( "+" | "-" ) constant_multiplicative_expression } ;
constant_multiplicative_expression = constant_unary_expression
                               { ( "*" | "/" | "%" ) constant_unary_expression } ;
constant_unary_expression    = ( "!" | "~" | "+" | "-" ) constant_unary_expression
                             | constant_primary_expression ;
constant_primary_expression  = constant_literal | qualified_name
                             | constant_type_query
                             | constant_array_initializer
                             | constant_aggregate_initializer
                             | "(" constant_expression ")" ;
constant_literal             = integer_literal | float_literal | text_literal
                             | "true" | "false" | "none" ;
constant_type_query          = ( "size_of" | "align_of" ) "(" type ")" ;
constant_array_initializer   = "{" [ constant_expression
                             { "," constant_expression } [ "," ] ] "}" ;
constant_aggregate_initializer = qualified_name "{"
                             [ constant_field_init { "," constant_field_init } [ "," ] ] "}" ;
constant_field_init          = identifier "=" constant_expression ;

constant_integer_expression = constant_expression ;

when_expression             = when_or_expression ;
when_or_expression          = when_and_expression { "||" when_and_expression } ;
when_and_expression         = when_equality_expression { "&&" when_equality_expression } ;
when_equality_expression    = when_relational_expression
                              [ ( "==" | "!=" ) when_relational_expression ] ;
when_relational_expression  = when_unary_expression
                              [ ( "<" | "<=" | ">" | ">=" ) when_unary_expression ] ;
when_unary_expression       = "!" when_unary_expression | when_primary_expression ;
when_primary_expression     = when_literal | when_context_name
                            | "(" when_expression ")" ;
when_literal                = when_integer_literal | text_literal | "true" | "false" ;
when_integer_literal        = [ "+" | "-" ] integer_literal ;
when_context_name           = identifier "." identifier { "." identifier } ;

(* Lexical productions. Ignored elements separate tokens and never carry project semantics. *)
ignored_element       = whitespace | line_comment | block_comment ;
space_character       = ? U+0020 SPACE ? ;
horizontal_tab_character = ? U+0009 CHARACTER TABULATION ? ;
line_feed_character   = ? U+000A LINE FEED ? ;
carriage_return_character = ? U+000D CARRIAGE RETURN ? ;
backslash_character   = ? U+005C REVERSE SOLIDUS ? ;
double_quote_character = ? U+0022 QUOTATION MARK ? ;
whitespace            = space_character | horizontal_tab_character | line_terminator ;
line_terminator       = line_feed_character
                      | carriage_return_character [ line_feed_character ] ;
line_comment          = "/" "/" { line_comment_character } [ line_terminator ] ;
line_comment_character = ? any Unicode scalar value except U+000D or U+000A ? ;
block_comment         = "/" "*" block_comment_body "*" "/" ;
block_comment_body    = ? shortest Unicode scalar sequence containing no U+002A U+002F closing pair; comments do not nest ? ;

identifier            = identifier_start { identifier_continue } ;
identifier_start      = ascii_letter | "_" ;
identifier_continue   = ascii_letter | decimal_digit | "_" ;
ascii_letter          = "A".."Z" | "a".."z" ;
predeclared_type_word = "i8" | "i16" | "i32" | "i64"
                      | "u8" | "u16" | "u32" | "u64"
                      | "isize" | "usize" | "bool" | "byte"
                      | "f32" | "f64" | "text" | "status" ;
decimal_digit         = "0".."9" ;
hex_digit             = decimal_digit | "A".."F" | "a".."f" ;
binary_digit          = "0" | "1" ;
digit_separator       = "_" ;
integer_literal       = decimal_integer | hexadecimal_integer | binary_integer ;
decimal_integer       = decimal_digit { [ digit_separator ] decimal_digit } ;
hexadecimal_integer   = "0" ( "x" | "X" ) hex_digit { [ digit_separator ] hex_digit } ;
binary_integer        = "0" ( "b" | "B" ) binary_digit { [ digit_separator ] binary_digit } ;
float_literal         = decimal_digits "." decimal_digits [ exponent_part ]
                      | decimal_digits exponent_part ;
decimal_digits        = decimal_digit { [ digit_separator ] decimal_digit } ;
exponent_part         = ( "e" | "E" ) [ "+" | "-" ] decimal_digits ;
text_literal          = double_quote_character { text_character | escape_sequence }
                        double_quote_character ;
text_character        = ? any Unicode scalar value except U+0022, U+005C, U+000D, or U+000A ? ;
escape_sequence       = backslash_character escape_code ;
escape_code           = backslash_character | double_quote_character
                      | "n" | "r" | "t" | "0" | unicode_escape_tail ;
unicode_escape_tail   = "u" "{" hex_digit
                        [ hex_digit [ hex_digit [ hex_digit [ hex_digit [ hex_digit ] ] ] ] ] ]
                        "}" ;
```

# 1. Conformance, terms, and safety outcomes

### OPENC-SAFETY-NOUB-001 — OpenC has no arbitrary undefined-behavior category

Statically invalid source is rejected with a structured diagnostic. Valid safe source may encounter only the dynamic outcomes enumerated by `OPENC-SAFETY-OUTCOME-001`, including defined checked failure. A violated unsafe precondition is bounded by the declared target-fault contract. None of these cases authorizes an optimizer to invent unrelated behavior.

### OPENC-SAFETY-UNSAFE-001 — Unsafe selects explicit precondition responsibility

An unsafe boundary permits operations whose validity depends on caller-provided low-level facts. It does not disable typing, sequencing, ownership, lifetime, diagnostic, or target rules. Statically known violations remain diagnosable inside unsafe code.

### OPENC-TERM-CHECKFAIL-001 — Checked failure is structured non-recoverable failure

A checked failure is a defined non-recoverable outcome of the current execution operation. It records a rule identity and source context, runs required structured cleanup, and terminates the current program or another declared execution boundary. It is distinct from a recoverable `status` result and from a target fault.

### OPENC-SAFETY-OUTCOME-001 — Every Core operation has one finite outcome category

Every source construct or runtime operation results in exactly one of:

1. defined successful behavior;
2. required source diagnostic and rejection;
3. recoverable `status` failure;
4. structured checked failure;
5. declared implementation-limit rejection;
6. declared target-dependent successful behavior; or
7. violation of an explicit unsafe precondition with a bounded target fault.

Core defines no residual arbitrary undefined-behavior category.

### OPENC-SAFETY-OPTIMIZE-001 — Optimization preserves all defined and recorded effects

An implementation may optimize only when every observable result, sequencing edge, cleanup action, diagnostic obligation, ownership transition, and target-dependent contract remains equivalent. It may not assume that a checked failure or unsafe precondition violation is impossible merely because the source is intended to be correct.

### OPENC-SAFETY-IMPLIMIT-001 — Implementation limits fail visibly

A conforming implementation may impose declared finite limits. Exceeding a limit shall produce a structured diagnostic identifying the limit and shall not silently change valid-program meaning or fall through to arbitrary behavior.

# 2. Source, translation, and build context

### OPENC-SOURCE-UTF8-001 — UTF-8 is the canonical source encoding

A source unit is decoded as UTF-8 into Unicode scalar values before tokenization. Surrogate code points are not Unicode scalar values and therefore cannot appear as decoded source characters. At most one UTF-8 byte-order mark may occur at byte offset zero under `OPENC-SOURCE-BOM-001`.

### OPENC-SOURCE-INVALID-001 — Invalid source encoding is diagnosed

An ill-formed UTF-8 byte sequence is a `source`-phase diagnostic. The decoder shall not replace malformed bytes and continue as though the replacement scalar had been authored. A U+FEFF scalar occurring outside an initial byte-order mark, text literal, or comment is tokenized normally and rejected when it cannot begin a valid token.


### OPENC-SOURCE-BOM-001 — One initial UTF-8 byte-order mark is ignored

At most one UTF-8 BOM byte sequence may occur at byte offset zero. It is removed before logical line, column, token, and source-span calculation. A BOM elsewhere is not ignored and cannot act as whitespace.

### OPENC-LEX-COMMENT-001 — Comments do not affect token meaning

Line comments begin with `//` and continue to the next logical line terminator or source end. Block comments begin with `/*` and end at the next `*/`; they do not nest. An unterminated block comment is a lexical diagnostic. Comments and whitespace separate tokens and carry no hidden project semantics.

### OPENC-TRANSLATE-NOPREPROCESSOR-001 — Parsing does not require textual preprocessing

Ordinary OpenC source shall be parseable without a separate textual macro language.

### OPENC-TRANSLATE-NOINCLUDE-001 — Textual includes are not part of OpenC

`#include` and equivalent source-pasting directives are not OpenC syntax.

### OPENC-WHEN-CONTEXT-001 — Conditional compilation reads only declared build context

Every non-literal primary in a `when` condition shall be a fully qualified build-context name containing at least two identifier segments. The active build context shall declare that name, its scalar kind, its exact value, and its origin before conditional source selection begins.

The permitted build-context scalar kinds are boolean, exact mathematical integer, and text. Source-level constants, locals, parameters, fields, functions, type queries, allocation, mutation, pointer operations, filesystem or network probes, clocks, randomness, environment-variable reads, and tool-installation probes are not build-context primaries in Core 1.0.

Every referenced context name and value is an observable build input and shall be available to reproducibility and diagnostic records.

### OPENC-WHEN-EXPR-001 — Conditional compilation uses a finite boolean/comparison grammar

A `when` condition shall match the normative `when_expression` grammar. It may contain boolean, signed integer, and text literals; fully qualified declared build-context names; parentheses; boolean `!`, `&&`, and `||`; equality `==` and `!=`; and integer ordering `<`, `<=`, `>`, and `>=`.

Boolean operators require boolean operands. Equality requires operands of the same scalar kind. Ordering requires integer operands. Text equality compares the exact Unicode scalar sequence and is case-sensitive. The complete condition shall be resolved and type-checked, including operands that evaluation could short-circuit, and its final type shall be boolean.

Calls, member calls, indexing, ranges, assignment, arithmetic, bitwise operations, casts, construction, destruction, type queries, pointer operations, and general source-name lookup are outside this grammar and invalid in a `when` condition.

### OPENC-WHEN-STRUCTURED-001 — Conditional compilation selects complete parsed bodies

A declaration-level `when` body contains complete top-level declarations. A statement-level `when` body is an ordinary lexical block. Core Candidate 2 defines no `else` clause for `when`.

Every `when` body shall be tokenized and parsed regardless of the condition value. A non-selected body need not undergo name, type, ownership, lifetime, capability, or flow validation against declarations unavailable in the active context. A selected declaration body contributes its declarations to the enclosing module; a selected statement body retains its ordinary block scope. A false body contributes no declarations, flow facts, calls, effects, or cleanup registrations, and no runtime branch is emitted.

A `when` block shall not splice arbitrary token fragments.

# 3. Lexical grammar

### OPENC-LEX-IDENT-001 — Identifier spelling and token selection are stable

Identifier comparison is case-sensitive and uses exact decoded scalar spelling. Lexical analysis uses deterministic maximal munch: at one source position the implementation chooses the longest token admitted by the lexical grammar; comment openers are recognized before the `/` operator; equal-length alternatives are resolved by the explicit token-class rules and never by implementation preference.

### OPENC-LEX-TYPEWORD-001 — Reserved and predeclared words cannot be rebound

A source declaration shall not introduce a local, parameter, field, function, type, enum item, module constant, or module-local qualifier whose unqualified spelling is a reserved word or predeclared type word. The complete word classification is fixed by `OPENC-LEX-WORDCLASS-001`.

### OPENC-LEX-TYPEQUALIFIER-001 — Predeclared type words may be explicit module segments

A declared module name may contain a predeclared type word as one segment. In a qualified name followed by `.`, parser context treats that segment as module qualification. An unqualified predeclared type word remains a type spelling and is never an ordinary value binding. Other reserved words are not module segments.


### OPENC-LEX-MAXIMAL-001 — Tokenization uses deterministic maximal munch

At each source offset the lexer consumes the longest valid token. Multi-character operators and comment delimiters are considered before their single-character prefixes. A numeric literal is consumed only while its separators and digits remain valid; an invalid continuation produces a lexical diagnostic rather than silent token splitting when the continuation would otherwise look like a literal suffix.

### OPENC-LEX-WORDCLASS-001 — Word spellings have one closed classification

The reserved words are: `import`, `export`, `const`, `struct`, `resource`, `enum`, `unsafe`, `void`, `own`, `out`, `when`, `ref`, `ptr`, `optional`, `storage`, `if`, `else`, `while`, `for`, `switch`, `case`, `default`, `break`, `continue`, `return`, `scope`, `cast`, `cast_unchecked`, `reinterpret`, `construct`, `destroy`, `size_of`, `align_of`, `true`, `false`, `null`, and `none`.

The predeclared type words are: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `isize`, `usize`, `bool`, `byte`, `f32`, `f64`, `text`, and `status`. A lexer may emit specialized token kinds for these words, but the parser-visible classification and module-segment exception shall match the normative grammar.

### OPENC-LITERAL-INTEGER-001 — Integer literals are exact mathematical integers

An integer literal has no hidden overflow before it is checked against its expression context and destination type.

### OPENC-LITERAL-RANGE-001 — Destination range is checked

A literal shall not initialize or convert to an integer type that cannot represent its value.

Leading-zero octal notation is not supported.

### OPENC-LITERAL-TEXT-001 — Text literals create exact scalar sequences

A text literal denotes the Unicode scalar sequence produced by its source characters and escapes. A raw quote, backslash, CR, or LF cannot occur as an unescaped text character. Invalid or unterminated escapes and invalid scalar escapes are lexical errors. Core performs no implicit normalization; canonically equivalent but distinct scalar sequences remain distinct values.

### OPENC-LITERAL-SEPARATOR-001 — Numeric separators occur only between digits

An underscore in a numeric literal occurs only between two valid digits of that literal's base. Leading, trailing, doubled, prefix-adjacent, decimal-point-adjacent, or exponent-marker-adjacent underscores are not numeric tokens and produce a lexical diagnostic.

### OPENC-LITERAL-FLOATDEFAULT-001 — An unconstrained floating literal has type `f64`

When no expected floating type is supplied, a floating literal has type `f64`. Context may select `f32` only when the literal rounds to the exact `f32` value required by `OPENC-NUM-FLOAT-FORMAT-001` and `OPENC-NUM-FLOAT-ROUND-001`.

### OPENC-LITERAL-NOSUFFIX-001 — Numeric literals have no type suffixes

Spellings such as `10u32`, `1.0f`, or implementation-specific suffixes are not plain OpenC Core Candidate 2. The destination declaration or an explicit conversion supplies the intended type.

### OPENC-LITERAL-UNICODE-001 — Unicode escapes denote valid scalar values

A `\\u{HEX}` escape shall contain one through six hexadecimal digits and denote a Unicode scalar value from U+0000 through U+10FFFF excluding the surrogate range U+D800 through U+DFFF.

# 4. Modules, imports, and visibility

### OPENC-MODULE-IDENTITY-001 — Logical module identity comes from declared project context

Each source unit is assigned exactly one logical module name by explicit project/build context before language processing. Source spelling and file extension do not create module identity. The assignment is reported in diagnostics and reproducibility records.

### OPENC-MODULE-IMPORT-001 — Imports name one declared logical module

`import a.b;` makes the exported declarations of logical module `a.b` available to that source unit. An import does not paste source text, execute initialization code, or discover a module through undeclared filesystem search.

### OPENC-MODULE-SHORT-001 — Short qualifiers are canonical when unambiguous

Documentation should prefer the unambiguous short module qualifier for ordinary calls.

### OPENC-MODULE-AMBIGUOUS-001 — Ambiguous short qualifiers are rejected

If two imported module paths have the same final segment, use of that short segment is invalid. Full qualification remains available.

```c
import graphics.color;
import terminal.color;

graphics.color.convert(value);
```

### OPENC-MODULE-PRIVATE-001 — Declarations are private by default

A declaration without `export` shall not be referenced from another module.

### OPENC-MODULE-EXPORT-001 — Public API is explicit

An exported declaration shall expose only types and contracts visible to its importing modules.

### OPENC-MODULE-CYCLE-001 — The Core 1.0 candidate rejects module import cycles

The directed graph of logical module imports shall be acyclic. Any strongly connected component containing more than one module, or a self-import, is rejected with a diagnostic showing the cycle path.

### OPENC-MODULE-MULTISOURCE-001 — Source units assigned to one module form one declaration set

All source units explicitly assigned to the same logical module contribute top-level declarations to one module declaration set. Declarations are order-independent except for module-constant dependency evaluation. Diagnostics retain the originating source unit and location.

### OPENC-MODULE-DUPLICATE-001 — Duplicate declarations are checked across the complete module

After composing all source units of one module, duplicate non-overloadable declarations, duplicate type names, duplicate module constants, and identical function signatures are rejected regardless of source-unit order.

### OPENC-MODULE-IMPORTLOCAL-001 — Imports remain local to their source unit

An import affects only the source unit containing it. Another source unit in the same logical module shall declare its own imports. This keeps source dependencies visible and prevents accidental import-order coupling.

### OPENC-MODULE-FULLIMPORT-001 — Full qualification still requires an import

Writing `graphics.color.convert` does not bypass dependency declaration. The source unit shall import `graphics.color` before using either its short or full qualifier.

### OPENC-MODULE-IMPORTIDEMPOTENT-001 — Duplicate identical imports have no added effect

Repeated import of the same module in one source unit is permitted and has no semantic effect beyond the first identical import.

### OPENC-MODULE-ORDER-001 — Top-level declaration meaning is source-order independent

Function, type, enum, resource, and module-constant declarations may refer to declarations in the same logical module regardless of source-unit or textual order, subject to cycle and completeness rules. Implementations shall not make validity depend on directory enumeration order.

### OPENC-MODULE-NOREEXPORT-001 — Imports do not re-export names

Importing a module does not make that module's declarations part of the importing module's public API. Re-export syntax is not part of Core Candidate 2. Users import the defining logical module directly.

### OPENC-MODULE-MAPPING-001 — Filesystem mapping is outside source-language semantics

Project tooling maps source paths to logical modules and records that mapping. Core does not mandate a source-file extension, directory convention, package manager, or implicit parent-directory search.

### OPENC-MODULE-CONSTCYCLE-001 — Module constant cycles are rejected

The dependency graph of module constant initializers shall be acyclic after name resolution. A cycle is rejected even when an implementation could choose an evaluation order or one branch appears unused.

### OPENC-MODULE-API-001 — Exported signatures expose only accessible complete types

An exported declaration shall not expose a private or incomplete type in a position that importing modules must name or lay out. A resource may expose its opaque type identity without exposing its fields.

# 5. Type system

### OPENC-TYPE-WIDTH-001 — Fixed-width integer names have fixed widths

`i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, and `u64` have exactly the width stated in their names.

### OPENC-TYPE-MACHINE-001 — Machine-sized integers use the declared target pointer width

`isize` and `usize` have the same bit width as a target data pointer: 32 or 64 bits in the Core Candidate 2 target schema. Their signed/unsigned ranges follow the exact integer model. The active target record supplies the width; the build host is irrelevant during cross-compilation.

### OPENC-TYPE-HISTORICAL-001 — Historical C integer names are not primitive OpenC types

`char`, `short`, `int`, `long`, and `long long` are not OpenC Core Candidate 2 primitive type names.

### OPENC-TYPE-VOIDOBJECT-001 — `void` is only a function result

`void` appears only as a function result. It is not an object type and is absent from `type_atom`; variables, fields, array elements, slice elements, optionals, storage objects, parameters, pointers, casts, and ownership modes cannot target `void`.

### OPENC-TYPE-BOOL-001 — Boolean meaning is explicit

Only `bool` expressions are accepted as ordinary control-flow conditions.

### OPENC-TYPE-BYTE-001 — Bytes are raw data, not text

A `byte`, `byte[N]`, or `byte[]` shall not implicitly convert to `text`.

### OPENC-TYPE-FLOAT-001 — Integer and floating-point types do not mix implicitly

There is no implicit conversion between integer and floating-point values.

### OPENC-TYPE-FLOAT-FIXED-001 — Floating types have fixed value formats

A target that lacks direct binary32 or binary64 support shall provide conforming software behavior or report the type unsupported for that implementation component; it shall not silently substitute a different format.

### OPENC-TYPE-TEXT-001 — Text is an immutable sequence of Unicode scalar values

A `text` value is an immutable finite sequence of Unicode scalar values. Surrogate code points are not scalar values. Core does not prescribe one in-memory encoding, pointer representation, or null terminator.

### OPENC-TYPE-CONST-001 — Const values are not assignable

A `const` binding cannot be reassigned and its mutable fields or elements cannot be modified through that binding.

### OPENC-REF-TYPE-001 — `ref T` is a safe non-owning borrow

A safe reference is non-null, does not support pointer arithmetic, does not own the referred object, and shall not outlive it.

### OPENC-REF-READ-001 — `ref const T` is read-only

Mutation through `ref const T` is invalid.

### OPENC-REF-SYMBOL-001 — Symbols do not spell reference declarations

`T& name` and `const T& name` are not OpenC declarations.

### OPENC-REF-INIT-001 — A local safe reference is initialized at declaration

Because a safe reference is non-null and its identity is stable, a local `ref T` or `ref const T` binding shall have an initializer. Function parameters and returned reference values are initialized by their call/return contract.

### OPENC-REF-NOREBIND-001 — A safe reference binding is not rebound

After initialization, the reference continues to denote the same object for its lifetime. OpenC Core Candidate 2 has no ordinary reference-rebinding assignment.

### OPENC-REF-ASSIGN-001 — Assignment through a mutable reference assigns the referred plain value

For mutable `ref T`, `reference = value;` assigns a compatible plain value to the referred object; it does not change which object the reference denotes. Field and element assignment follow the same mutation permission. Assignment through `ref const T` is invalid.

### OPENC-REF-RESOURCEASSIGN-001 — A borrow does not replace a resource owner

Whole-value assignment through `ref ResourceType` is invalid. Resource replacement requires an explicit domain operation with ownership contracts so the existing and incoming obligations are discharged exactly once.

### OPENC-PTR-TYPE-001 — `ptr T` is a raw pointer type

A raw pointer is a low-level address value. It may be null, carries no general safe bounds guarantee, and is not owning unless a creating operation establishes an ownership obligation.

### OPENC-PTR-SYMBOL-001 — Symbols do not spell pointer declarations

`T* name` is not an OpenC declaration.

### OPENC-REF-CONSTVIEW-001 — Mutable safe references convert to read-only safe references

A `ref T` may be passed or used to initialize a `ref const T` where read-only access is required. The conversion preserves identity and lifetime while removing mutation permission. The reverse conversion is not implicit and is invalid in safe code.

### OPENC-PTR-CONSTVIEW-001 — Mutable raw pointers convert to read-only raw pointers

A `ptr T` may convert to `ptr const T` without changing address or provenance. A `ptr const T` shall not implicitly convert to `ptr T`; removing pointed-to constness requires a declared unsafe operation whose contract proves the underlying object is mutable.

### OPENC-OPTIONAL-EXPLICIT-001 — Absence uses the word-shaped `optional T` type

The canonical absence type is `optional T`. An immutable optional value is written `const optional T`. A non-optional value or safe reference cannot silently contain absence.

### OPENC-OPTIONAL-CHECK-001 — Optional value access is checked

Access to `.value` requires a statically proven `.present` condition or produces a defined checked failure.

### OPENC-OPTIONAL-NOSHORTHAND-001 — `T?` is not Core syntax

The symbolic nullable spelling `T?` is rejected.

### OPENC-OPTIONAL-NOBORROW-001 — Optional targets are copyable plain value types

`optional T` may contain a scalar, enum, text, plain struct, or fixed array whose resolved type is copyable and non-resource. It shall not contain `ref`, `ptr`, a slice, `storage`, another optional, or a resource type in Core Candidate 2.

### OPENC-ARRAY-TYPE-001 — Fixed array length is part of the type

`i32[4]` and `i32[8]` are distinct types.

### OPENC-SLICE-TYPE-001 — A slice is a bounded non-owning view

A slice carries element type, start, and length. It does not own the viewed storage.

### OPENC-SLICE-CONSTVIEW-001 — Mutable slices convert to read-only slices

A `T[]` may convert to `const T[]` with the same start, length, provenance, and lifetime. A `const T[]` shall not implicitly convert to `T[]`.

### OPENC-STORAGE-TYPE-001 — Typed storage targets one complete plain object type

`storage T` or `storage T[N]` reserves correctly aligned storage for one complete plain non-resource object or fixed array. It does not begin a lifetime and cannot target `ref`, `ptr`, `optional`, a slice, `void`, text with opaque representation, or a resource type.

### OPENC-CONVERT-IMPLICIT-001 — Implicit conversion preserves every source value

An implicit conversion is allowed only when every possible value of the source type is represented exactly and with the same meaning by the destination type.

Allowed examples include:

```text
i8 -> i16 -> i32 -> i64
u8 -> u16 -> u32 -> u64
f32 -> f64
```

Signed-to-unsigned, unsigned-to-signed, narrowing, integer-to-float, float-to-integer, text-to-bytes, pointer-to-integer, and unrelated pointer conversions are explicit.

### OPENC-CONVERT-LOSSY-001 — Lossy conversion is never implicit

A conversion that can change value, range, precision, signedness, representation, or interpretation shall be explicit.

### OPENC-CONVERT-CAST-001 — `cast` is checked

`cast(T, value)` shall not silently truncate or wrap.

### OPENC-CONVERT-REINTERPRET-001 — Reinterpretation is unsafe

Bit or pointer reinterpretation requires an unsafe boundary and does not create an object lifetime by itself.

### OPENC-TYPE-RESOURCEARRAY-001 — Fixed arrays do not own resource elements

A fixed array element type shall be copyable and non-resource. Resource collections use an owning resource type supplied by a module.

### OPENC-TYPE-RESOURCEOPTIONAL-001 — Optional resource containment is reserved

`optional T` shall not directly contain a resource type in OpenC Core Candidate 2. A resource module may define a domain-specific optional owner resource with explicit movement and destruction.

### OPENC-TYPE-PREFIXORDER-001 — Type constructors and modes have one canonical order

Canonical forms are `const T`, `const T[N]`, `const T[]`, `ref T`, `ref const T`, `ptr T`, `ptr const T`, `optional T`, `const optional T`, and `storage T`. Function-boundary modes are written `own ResourceType`, `own ptr T`, `out T`, and `out own ptr T`. Reordered forms such as `const ref T`, `const ptr T`, `optional const T`, `own out ptr T`, and `ptr own T` are invalid rather than silently normalized.

### OPENC-TYPE-CONSTRUCTORS-001 — Core type constructors are a closed word-shaped set

Core Candidate 2 defines exactly four type constructors: `ref`, `ptr`, `optional`, and `storage`. `const` is a qualifier. `own` and `out` are declaration modes, not general types. Symbolic declarations such as `T&`, `T*`, and `T?` remain invalid.

### OPENC-TYPE-SUFFIX-001 — Core value types use at most one array or slice suffix

A Core value type has no suffix, one fixed-array suffix, or one slice suffix. Nested fixed arrays, arrays of slices, and repeated suffix chains are deferred from Core Candidate 2 and require explicit container types or future grammar.

# 6. Declarations, constants, initialization, and scope

### OPENC-DECL-TYPEFIRST-001 — Ordinary declarations are type-first

OpenC Core Candidate 2 does not use `let`, `var`, `auto`, or `:=` as ordinary declaration syntax.

### OPENC-DECL-ASSIGN-001 — Declaration and reassignment are distinct

In ordinary module code, `name = value;` assigns an existing name. It does not declare a new name.

### OPENC-INIT-BEFOREUSE-001 — A value is initialized before read

Every read shall be dominated by definite initialization on every reachable path.

### OPENC-INIT-PATH-001 — Definite initialization is path-sensitive

```c
i32 value;

if condition {
    value = 1;
} else {
    value = 2;
}

use(value);
```

is valid. Omitting the `else` assignment makes the later read invalid unless another rule proves initialization.

### OPENC-INIT-NOZERO-001 — Storage is not silently zeroed into a value

OpenC does not solve uninitialized reads by silently defaulting every declaration to zero or an all-zero object representation.

### OPENC-CONST-INIT-001 — Constants are initialized at declaration

```c
const i32 limit = 100;
```

is valid; `const i32 limit;` is invalid.

### OPENC-CONST-ASSIGN-001 — Constants are not reassigned

Assignment through a `const` binding, reference, slice, or field path is invalid.

### OPENC-SCOPE-LOCAL-001 — Block-local names do not escape by name

A local name is not visible outside its declaring block.

### OPENC-SCOPE-DUPLICATE-001 — Duplicate declarations are rejected

Two declarations with the same name in the same scope are invalid.

### OPENC-SCOPE-SHADOW-001 — Core Candidate 2 rejects local shadowing

A local declaration shall not reuse a visible local or parameter name in an enclosing active scope. Module qualification handles external naming; explicit distinct local names keep flow, ownership, and diagnostic state unambiguous.

### OPENC-GLOBAL-CONST-001 — Module constants are compile-time values in an acyclic dependency graph

A module constant is initialized by the Core constant-expression subset before runtime execution. It may depend on earlier or later module constants through qualified or unqualified names, provided the complete dependency graph is acyclic and every expression is valid for the declared type.

### OPENC-GLOBAL-MUTABLE-001 — Core contains no ordinary mutable module object

Core Candidate 2 permits compile-time module constants but no ordinary safe mutable module-scope object. Hosted or concurrent specifications may introduce explicitly synchronized or provider-owned global state under separate capability rules.

### OPENC-PARAM-OUTTYPE-001 — `out` parameters name initializable caller values

An `out` parameter may initialize a mutable plain scalar or fixed array, an optional value, a non-owning raw pointer, or a resource value. It shall not have `const`, `ref`, slice, `storage`, or `void` form. Unique raw-pointer ownership uses the exact form `out own ptr T`; resource types already carry ownership by type and use `out ResourceType`.

### OPENC-PARAM-OWNTYPE-001 — `own` parameters consume only resources or owning raw pointers

The parameter forms `own ResourceType name` and `own ptr T name` consume one ownership obligation. A qualified name following `own` shall resolve to a resource type. `own` shall not prefix a primitive, plain struct, enum, array, slice, optional, safe reference, or storage type.

### OPENC-PARAM-OUT-001 — `out` is a provisional initialization slot

An `out T` parameter begins each call uninitialized. The callee may initialize it exactly once along a path and may read or borrow it only after that initialization. The caller receives a usable value only if the returned status is successful. `out` is not an alias to an already-live caller value.

### OPENC-PARAM-OWN-001 — `own` transfers responsibility to the callee

Passing a resource value to an `own T` parameter consumes the caller's ownership. The source binding becomes moved and cannot be read until reinitialized.

### OPENC-PARAM-REF-001 — `ref` does not transfer ownership

Passing through `ref` or `ref const` is a borrow and leaves ownership with the caller.

### OPENC-OWN-MODE-001 — `own` is a boundary ownership mode, not a local type

`own` may appear only on a consuming function parameter, an owning raw-pointer function result, an owning raw-pointer output parameter, or an owning raw-pointer field in a `resource` declaration. Local declarations, casts, type queries, ordinary struct fields, arrays, optionals, and storage declarations do not accept `own`.

### OPENC-OUT-MODE-001 — `out` is a parameter and call-site mode

`out` appears in a function parameter declaration and at the corresponding call argument. It does not create a storable type and cannot appear in a local declaration, field declaration, result type, cast target, or type query.

### OPENC-NAME-UNKNOWN-001 — Unknown names are diagnosed

An unresolved identifier or qualifier is invalid and shall produce candidates or origin information when available.

### OPENC-INIT-LOOP-001 — Loop-only assignment does not prove later initialization

A binding initialized only inside a loop remains potentially uninitialized after the loop unless every reachable exit proves otherwise.

### OPENC-OUT-TARGET-001 — An out target is one simple local binding without a live value

At the call site, `out name` shall name a mutable local binding whose state is definitely uninitialized and which carries no live resource or raw-pointer ownership obligation. Fields, indices, dereferences, constants, module bindings, already initialized locals, and unresolved conditional outputs are invalid out targets.

### OPENC-OUT-ALIAS-001 — Out targets are exclusive for the complete call

One storage location shall not appear in more than one `out` argument of a call and shall not overlap any argument passed by value, `ref`, `ref const`, `ptr`, or `own`. Because Core 1.0 out targets are simple local names, distinct valid out names are non-overlapping by construction.

### OPENC-OUT-NOREAD-001 — A callee cannot use an out slot before initialization

At function entry an `out` parameter has no value. Reading, borrowing, moving, destroying, or otherwise using it before assignment is invalid. After one valid initialization on a path, it may be read or borrowed subject to its ordinary type rules.

### OPENC-OUT-REASSIGN-001 — An out slot is initialized at most once on one path

Assigning an already initialized out parameter a second time on the same path is invalid. Different mutually exclusive branches may each initialize the slot once when their paths do not overlap.

### OPENC-CONST-EXPR-001 — Module constants use a closed side-effect-free expression subset

A module-constant initializer may use literals, other module constants, enum members, pure operators with defined constant semantics, `size_of`, `align_of`, fixed-array initializers, and plain struct initializers whose components are constant expressions. It cannot call functions, allocate, borrow, access pointers, construct storage, read build context, or depend on runtime state.

### OPENC-CONST-CHECKFAIL-001 — A constant expression cannot defer a checked failure to runtime

If constant evaluation would overflow, divide by zero, use an invalid shift, fail a checked cast, access an absent optional, or otherwise produce a checked failure, the declaration is rejected at compile time.

# 7. Expressions and conversions

### OPENC-EXPR-ORDER-001 — Operand evaluation is left-to-right

Function arguments and binary operands are evaluated from left to right. Each operand completes before the next begins, subject only to the explicit short-circuit rules for `&&` and `||`.

### OPENC-CALL-COUNT-001 — Argument count matches

A call shall supply the required number of arguments.

### OPENC-CALL-TYPE-001 — Argument types match parameter modes

Arguments shall satisfy value, borrow, output, and ownership-transfer requirements without implicit lossy conversion.

### OPENC-MEMBER-UNKNOWN-001 — Unknown members are rejected

A member access shall name a member defined by the type or a standard built-in property.

### OPENC-INDEX-SAFE-001 — Safe indexing checks bounds

Array and slice indexing is statically proven or checked at runtime.

### OPENC-SLICE-RANGE-CHECK-001 — Slice ranges are checked

For `values[start..end]`, the valid condition is `start <= end && end <= values.length`. Failure is a defined checked failure.

### OPENC-ARITH-TYPE-001 — Numeric operands have matching types

There are no C-style integer promotions. Mixed-width or mixed-signedness arithmetic requires explicit conversion.

### OPENC-ARITH-MINUS-001 — Unary minus is range-checked

Negating the minimum signed value is checked overflow.

### OPENC-EQUALITY-RESOURCE-001 — Resource equality is not implicit

Resource types define domain-specific comparison functions when meaningful.

### OPENC-BOOL-SHORT-001 — Boolean operators short-circuit

The right operand of `&&` is evaluated only when the left operand is true. The right operand of `||` is evaluated only when the left operand is false.

### OPENC-ASSIGN-TARGET-001 — Assignment targets are mutable locations

A constant, read-only borrow, read-only slice, literal, or temporary is not assignable.

### OPENC-ASSIGN-CONVERT-001 — Assignment does not perform lossy conversion

The assigned value shall match the destination or convert implicitly without possible information loss.

### OPENC-PTR-ADDRESS-001 — Raw address acquisition is unsafe and location-bounded

`&location` requires unsafe context and one addressable stable live location. The result is `ptr T` for a mutable location or `ptr const T` for a const location. Valid locations are eligible local objects, referred objects, non-ownership fields, and fixed-array or slice elements. Whole arrays, slice values, empty storage, temporaries, literals, call results, aggregate temporaries, and ownership-bearing resource fields are not addressable by Core. Array elements are addressed explicitly as `&array[index]`.


### OPENC-PTR-ADDRESSABLE-001 — Addressable locations have one stable lifetime and representable pointed-to type

An addressable location shall have an active lifetime, stable storage for the pointer's required use, and a pointed-to type expressible by `ptr T`. Address acquisition creates pointer provenance for that exact object or element lifetime generation. Moving, destroying, or reconstructing the object invalidates later typed access through the pointer according to the ordinary provenance rules.

### OPENC-PTR-DEREF-001 — Raw dereference is unsafe

Reading or writing through `*p` requires an unsafe boundary.

### OPENC-PTR-ARITH-001 — Raw pointer arithmetic is unsafe

Raw pointer arithmetic has target-documented address semantics and no safe bounds guarantee.

### OPENC-PTR-NULL-001 — Null dereference is invalid

Dereferencing `null` has no safe OpenC result. An implementation may trap, report, or expose a documented target fault, but shall not treat the case as unrestricted optimizer permission.

### OPENC-CAST-EXACT-001 — Checked cast means value-preserving cast

`cast(T, value)` succeeds only when the applicable `OPENC-NUM-CAST-*` rule defines the value as exactly representable by `T`. Rounding, truncation, wrapping, and saturation require their own explicit operations.

### OPENC-PTR-COMPARE-001 — Pointer equality is universal; ordering and subtraction require common provenance

Pointer equality and inequality are defined for all raw pointers: two null values are equal; two non-null values are equal only when they identify the same provenance and offset. Ordered comparison and pointer subtraction require common provenance and positions within the permitted range, including one-past.

# 8. Statements and control flow

### OPENC-BLOCK-BRACES-001 — Control-flow bodies use braces

`if`, `else`, `while`, `for`, `switch` cases, `unsafe`, and `when` bodies require braces. Single-statement brace omission is not OpenC.

### OPENC-STMT-SEMICOLON-001 — Statement boundaries are explicit

OpenC does not use newline-based semicolon insertion.

### OPENC-COND-BOOL-001 — Ordinary conditions are `bool`

The conditions of `if`, `while`, and `for` shall have type `bool`. Integer, pointer, optional, text, slice, and object truthiness are not part of ordinary module code.

### OPENC-FOR-SCOPE-001 — For-loop declarations are loop-local

Names declared in the initializer are not visible after the loop.

### OPENC-SWITCH-NOFALL-001 — Switch cases execute one body without fallthrough

A switch subject is evaluated exactly once. At most one matching case body is entered. Completing that body exits the switch; execution never falls into a later case. `break` exits the nearest enclosing switch or loop, while `continue` targets only the nearest enclosing loop.

### OPENC-SWITCH-ENUM-001 — Enum and boolean switches are exhaustiveness-checkable

A switch over an enum is exhaustive when every enumerator value is covered or a default case exists. A switch over `bool` is exhaustive when both `true` and `false` are covered or a default exists. Strict and critical validation may require exhaustiveness; Core execution remains defined for a non-exhaustive unmatched switch by executing no case body.


### OPENC-SWITCH-DOMAIN-001 — Switch subjects use one finite scalar domain

A switch subject has type `bool`, `byte`, a fixed-width integer, `isize`, `usize`, or one enum type. Floating, text, pointer, reference, optional, aggregate, resource, array, slice, and storage subjects are invalid.

### OPENC-SWITCH-CASE-001 — Switch cases are unique representable constants of the subject type

Every case expression is a constant expression exactly representable as the subject type. Enum cases use the same enum type. Case values are compared by the subject type's ordinary equality. A case does not perform lossy conversion.

### OPENC-SWITCH-DUPLICATE-001 — Duplicate switch case values are rejected

After constant evaluation and exact conversion to the switch subject type, no two case labels may have the same value. At most one default case is permitted.

### OPENC-SWITCH-EXECUTE-001 — Switch selects one equal case, default, or no body

The subject is evaluated once before any case body. The unique equal case executes when present; otherwise the default body executes when present; otherwise no body executes. Case expressions introduce no runtime evaluation.

### OPENC-LOOP-CONTEXT-001 — Break and continue target the nearest eligible construct

`break` is valid inside a loop or switch and exits the nearest enclosing such construct. `continue` is valid only inside a loop and begins the next iteration of the nearest enclosing loop. A nested switch does not intercept `continue`.


### OPENC-IF-EXECUTE-001 — If evaluates one boolean condition and one selected branch

An `if` condition is evaluated exactly once. When true, the first block executes; otherwise the `else` block or nested `if` executes when present. The unselected branch has no runtime effects.

### OPENC-WHILE-EXECUTE-001 — While checks before every iteration

A `while` condition is evaluated before the first iteration and before every later iteration. A false result exits the loop. `continue` transfers to the next condition evaluation; `break` exits the loop immediately after required cleanup for exited scopes.

### OPENC-FOR-EXECUTE-001 — For has fixed initializer, condition, iteration, and body order

A `for` initializer executes once. Before each iteration, the condition executes when present; an omitted condition is `true`. When true, the body executes, then the iteration expression executes when present, then control returns to the condition. `continue` transfers to the iteration expression and then the condition. `break` exits without executing the iteration expression.

### OPENC-RETURN-TYPE-001 — Return matches the function result type

A non-void function returns a compatible value on every reachable completed path. A void function returns no value.

### OPENC-RETURN-LIFETIME-001 — Returned borrows remain valid

A function shall not return a safe reference or slice that outlives its owner.

### OPENC-STMT-UNREACHABLE-001 — Unreachable ordinary code produces a warning diagnostic

An ordinary statement that cannot execute because every preceding path terminates produces a `flow` warning in plain Core. Validation overlays may elevate it to an error. Unreachable source is still parsed and type-checked to prevent hidden invalid syntax or declarations.

# 9. Functions and overload resolution

### OPENC-FUNCTION-DIRECT-001 — Functions use return-type-first declarations

OpenC ordinary functions do not use mandatory `fn`, `func`, or arrow-return syntax.

### OPENC-FUNCTION-PARAM-001 — Parameters are explicit and type-first

Every parameter has an explicit type and name. Inferred public signatures are not supported.

### OPENC-OVERLOAD-AMBIGUOUS-001 — Ambiguous overloads are rejected

An implementation shall not choose an overload by undocumented ranking or source order.

Default arguments and named call arguments are not supported in OpenC Core Candidate 2.

### OPENC-OVERLOAD-EXACT-001 — Overload selection prefers one exact type-and-mode match

After filtering by name and argument count, an exact candidate matches every parameter mode and resolved argument type without conversion, except the identity-preserving formation of a borrow from the supplied lvalue. If exactly one exact candidate remains, it is selected.

### OPENC-OVERLOAD-NORANK-001 — Lossless-conversion candidates have no hidden distance ranking

If no exact candidate exists, the implementation considers candidates reachable only through the enumerated implicit value-preserving conversions, mutable-to-const borrow conversion, and fixed-array-to-slice borrowing. If exactly one candidate is viable, it is selected. Two or more viable candidates are ambiguous; there is no numeric conversion-distance ranking.

### OPENC-OVERLOAD-RETURN-001 — Return type alone does not form an overload

Two functions in the same overload set shall not differ only by result type. Call-site destination context is not used to select between return-only alternatives.

### OPENC-OVERLOAD-MODE-001 — Parameter modes are exact parts of overload identity

Value, `ref`, `out`, and `own` parameters are distinct overload identities. Resolution shall not reinterpret an ordinary argument as an ownership transfer, output slot, or different borrow mode. An `out` argument matches only an `out` parameter and an ownership-consuming argument only an `own` parameter.

### OPENC-FUNCTION-PATH-001 — Every reachable completed path satisfies the result contract

A non-`void` function returns a compatible result on every reachable path that completes normally. A `void` function may reach the closing brace as an implicit `return;`. Out and ownership parameter obligations are checked at each return under their dedicated contracts.

### OPENC-OUT-OWN-001 — Owning raw-pointer output uses exactly `out own ptr T`

A successful `out own ptr T` call creates one unique allocation owner in the caller. A failed call creates no caller owner. Resource outputs use `out ResourceType` because resource ownership is carried by the resource type itself; `out own ResourceType` remains invalid redundancy.

### OPENC-OUT-CALL-001 — Output mutation and its proof carrier are visible

The caller writes `out name`. A call with one or more out arguments shall either initialize or assign a named local `status` binding, or appear as the direct return expression of an exact out-forwarding function. An anonymous temporary such as `make(out value).ok`, a nested out call, or an out call used as an expression statement is invalid.

### OPENC-OUT-RESULTBIND-001 — Out-call proof requires a stable local result binding

Except for exact direct forwarding, the result of a call containing `out` arguments shall be stored in a named local `status` binding before any proof test. This restriction keeps proof identity stable, makes diagnostics local, and prevents proof from being hidden in nested expressions.

### OPENC-OWN-CALL-001 — Consuming calls use domain-specific names

The language contract is declared by `own`, while caller readability is provided by a precise operation name such as `buffer_move` or `buffer_destroy`. A generic bare `move(value)` operation is not part of OpenC Core Candidate 2.

### OPENC-FUNCTION-UNSAFE-001 — Calling an unsafe function requires unsafe context

A caller shall enter an unsafe boundary before calling an unsafe function.

### OPENC-FUNCTION-OUTSUCCESS-001 — Every successful return commits every output

On every return path proven successful, every out parameter shall hold one initialized value and every owning output shall hold exactly one live ownership obligation. Missing, destroyed, or moved-away output state makes the successful return invalid.

### OPENC-FUNCTION-OUTFAIL-001 — Failure returns expose no output value or ownership obligation

On every return path proven failed, no output becomes caller-visible. A provisional plain output is discarded. A provisional resource or owning raw-pointer output shall not remain committed at failure; any local owner used to prepare it shall still be discharged or transferred exactly once.

Failure shall not leak a local owner, publish a partial resource, or expose an owning output whose success proof is false.

### OPENC-FUNCTION-OUTRETURN-001 — Every out-function return has a provable status relation

A return in a function with out parameters shall be one of: a definitely successful status on a path satisfying the success rule; a definitely failed status on a path satisfying the failure rule; or a proof-bearing status whose associated targets correspond exactly to the current function's out parameters. An arbitrary runtime status with no proven relation to output state is invalid.

### OPENC-OUT-FORWARD-001 — Exact out forwarding preserves the function contract

A function may directly return another out call, or return its proof-bearing local status, only when the forwarded output targets correspond one-for-one to all of the current function's out parameters with matching types and modes. The caller of the outer function receives a new local proof lineage governed by the outer function contract.

### OPENC-FUNCTION-ARGORDER-001 — Function calls use deterministic argument order

Function argument evaluation and parameter-mode transitions follow `OPENC-FUNCTION-ARGORDER-001` and the `OPENC-EVAL-*` sequencing rules. Callee bodies never begin while an earlier argument remains partially evaluated.

### OPENC-OVERLOAD-CONVERSIONS-001 — The viable implicit conversion set is finite

Overload viability may use only conversions already permitted implicitly by Core: exact integer widening within one signedness chain, `f32` to `f64`, mutable-to-const borrow/pointer view, and fixed-array-to-compatible-slice borrowing. No user-defined conversion, lossy conversion, signedness change, or return-context conversion participates.

### OPENC-FUNCTION-RECURSION-001 — Functions may call themselves through ordinary name resolution

Direct and mutual recursion are permitted when module and function declarations resolve without an import or constant-initialization cycle. Runtime stack limits are declared implementation limits.

# 10. Structs, enums, and resources

### OPENC-STRUCT-DECL-001 — Structs use a direct brace form

Fields are type-first declarations and each field ends with a semicolon.

### OPENC-STRUCT-TRAILING-001 — Struct declarations have no trailing semicolon

A semicolon after the closing struct brace is invalid OpenC Core Candidate 2 syntax.

### OPENC-RESOURCE-DECL-001 — Resources use a direct brace declaration

A resource declaration is written `resource Name { ... }`. Like a struct declaration, it has no trailing semicolon. Resource fields are type-first and each field ends with a semicolon.

### OPENC-RESOURCE-TRAILING-001 — Resource declarations have no trailing semicolon

A semicolon after the closing brace of a `resource` declaration is invalid Core Candidate 2 syntax.

### OPENC-STRUCT-FIELD-001 — Field access uses dot syntax

```c
player.health
```

Unknown fields are diagnosed.


### OPENC-STRUCT-CONSTFIELD-001 — Const fields are non-assignable through every containing path

A field declared with a const-qualified field type is initialized during aggregate construction and cannot later be assigned through a mutable containing binding, mutable reference, slice, pointer, or field path. Constness applies to the field value itself, not only to one access path.

### OPENC-FIELD-TYPE-001 — Stored fields use bounded non-borrowed forms

A stored field may use a scalar plain value, fixed array, optional plain value, or raw pointer. A field shall not have `ref`, slice, `storage`, or `void` form. An ordinary `struct` additionally rejects resource fields and `own ptr` fields. A `resource` may contain resource fields and may declare an owning raw-pointer field as `own ptr T name;`.

### OPENC-STRUCT-DEFAULT-001 — Plain struct field defaults are compile-time expressions

A plain struct field may declare a default only from the Core constant-expression subset. The expression cannot read another field, call a function, allocate, borrow, mutate state, or fail at runtime. It is evaluated separately for every construction that omits the field.

### OPENC-STRUCT-INIT-001 — Struct initialization is named

Positional aggregate initialization such as `Player{80, 40}` or `{80, 40}` is not OpenC Core Candidate 2 syntax.

### OPENC-STRUCT-INIT-FIELD-001 — Initializer fields are unique and known

Unknown or duplicate field names are invalid.

### OPENC-STRUCT-INIT-MISSING-001 — Required fields are initialized

A field may be omitted only when it has a declared default.

### OPENC-STRUCT-EMPTY-001 — Empty initialization requires complete defaults

`Player{}` is valid only when every field has a default.

Named initializer order does not affect field selection.

### OPENC-STRUCT-COPY-001 — Plain structs copy recursively by value

A struct is copyable only when every field is copyable and non-resource. Copying creates an independent value for each field under that field type's copy semantics. Padding and representation bytes are not copied as semantic state.

### OPENC-STRUCT-EQUALITY-001 — Plain struct equality is recursive field equality

A struct supports `==` and `!=` only when every field supports equality. Fields compare in declaration order with short-circuit behavior. Padding, layout, and inactive representation bytes do not participate.

### OPENC-ENUM-DISTINCT-001 — Enums are distinct types

An enum value does not implicitly convert to or from an integer.

### OPENC-ENUM-UNDERLYING-001 — Enums have a deterministic unsigned underlying type

An enum without an explicit underlying type uses `u32`. A representation-sensitive enum may name `u8`, `u16`, `u32`, or `u64` before its name. The underlying representation affects size and external encoding but does not enable implicit integer conversion.

### OPENC-ENUM-DUPLICATE-001 — Enum names and values are unique and range-checked

Duplicate member names and duplicate resulting numeric values are invalid. A missing value is zero for the first member and one greater than the previous member thereafter. Every value shall fit the declared or default underlying type.

### OPENC-RESOURCE-NOCOPY-001 — Resource owners are never copied by ordinary value syntax

A resource lvalue shall not initialize or assign another resource binding by ordinary value copy:

```c
Buffer second = first; // invalid
```

A resource owner is created only by an ownership-producing expression with a stable owner destination, including a resource initializer, a resource-returning call, a proven successful `out ResourceType` call, or an explicit whole-resource transfer through an `own ResourceType` boundary. Plain struct copy rules never apply to resources.

An ordinary by-value parameter whose resolved type is a resource is invalid because it would imply an unmarked resource copy. A resource parameter uses exactly one explicit boundary form according to intent:

```c
ref Buffer buffer;
ref const Buffer buffer;
own Buffer buffer;
out Buffer buffer;
```

### OPENC-RESOURCE-MOVE-001 — Whole-resource transfer crosses one explicit ownership boundary

A complete resource moves only through an explicit ownership boundary: passing it to an `own ResourceType` parameter, returning it as a resource result, committing it into an ownership-bearing resource field, or publishing it through a successful resource output.

Caller readability is provided by a domain-specific operation name:

```c
Buffer next = buffer_move(current);
```

The `own` parameter contract performs the transfer; the name explains the domain operation. A generic `move(current)` operation is not part of Core Candidate 2. After transfer, the source binding is moved and unusable until explicitly reinitialized.

### OPENC-RESOURCE-COPY-001 — Explicit duplication uses a domain function

If duplication is meaningful, the module may export a function such as:

```c
Buffer buffer_copy(ref const Buffer source);
```

### OPENC-RESOURCE-DESTROY-001 — Resource release is a domain-specific consuming operation

A resource is released by transferring it to a domain-specific consuming function:

```c
void buffer_destroy(own Buffer buffer);
```

Calling `buffer_destroy(owner)` moves the caller binding into the callee. The generic `destroy(reference)` expression applies only to a non-resource object constructed in `storage T`; it never substitutes for a resource contract.

A consuming resource function shall satisfy the complete consumer-return contract: it either transfers the whole resource onward, or discharges every compiler-visible nested ownership slot exactly once before completing its own domain-specific outer discharge.

### OPENC-RESOURCE-OBLIGATION-001 — Every resource lifetime carries one exactly-once outer obligation

When a resource initializer commits, a resource-returning call returns, or a proven resource output succeeds, exactly one outer resource obligation begins in the receiving owner binding.

That obligation shall be discharged exactly once by whole-resource transfer, return, successful output publication, commitment into another resource, or a consuming operation. It shall not be copied, silently overwritten, abandoned on a structured exit, or discharged twice.

A resource value may also contain compiler-visible nested obligation slots for resource fields and `own ptr` fields. Whole-resource transfer moves the outer obligation and every live nested slot together.

### OPENC-RESOURCE-NOCONSTOWNER-001 — Resource owner bindings are not declared `const`

A resource owner must remain movable to a domain transfer or destroy operation. `const ResourceType owner` is therefore invalid. Read-only access uses `ref const ResourceType` while ownership remains with a non-const binding.

### OPENC-STRUCT-INIT-ORDER-001 — Explicit fields evaluate in source order; defaults follow declaration order

Named explicit field expressions evaluate left-to-right in the written initializer order. After all explicit expressions succeed, omitted field defaults evaluate in field declaration order. Because defaults cannot depend on object fields, initializer spelling does not create hidden field-order dependencies.

### OPENC-STRUCT-NORESOURCE-001 — Ordinary structs cannot hide ownership obligations

A field in an ordinary `struct` shall not resolve to a resource type and shall not use `own ptr T`. A type containing resource or unique raw-pointer obligations is declared `resource`, keeping plain-struct copying and destruction unambiguous.

### OPENC-RESOURCE-FIELD-001 — A resource has one outer obligation and explicit nested obligation slots

A `resource` declaration may contain plain fields, non-owning raw-pointer fields, resource fields, and uniquely owning raw-pointer fields.

Each resource-typed field and each `own ptr` field is one compiler-visible nested obligation slot. Plain fields and non-owning `ptr` fields carry no independent ownership slot. Resource-typed fields carry ownership by their type; the redundant spelling `own ResourceType` is not used for fields.

Whole-resource transfer moves the outer obligation and all live slots as one unit. Field-by-field transfer is available only inside the consuming context of an `own ResourceType` parameter.

### OPENC-RESOURCE-FIELD-OWNPTR-001 — Unique raw-pointer fields use exactly `own ptr T`

A unique raw-pointer field in a resource declaration uses exactly:

```c
own ptr T name;
own ptr const T name;
```

The word `own` is required because ordinary `ptr T` is non-owning. An `own ptr` field is invalid in an ordinary struct, optional, array, or typed-storage object.

### OPENC-RESOURCE-FIELD-DEFAULT-001 — Ownership-bearing resource fields are explicit construction inputs

A resource-typed field and an `own ptr` field shall not declare a field default. Every such field is supplied explicitly by the resource construction transaction.

Plain fields and non-owning pointer fields may retain ordinary declaration defaults. Their default expressions are evaluated only when a resource initializer omits those fields, after explicit field expressions and in declaration order.

### OPENC-RESOURCE-INIT-001 — A named resource initializer creates one ownership-producing value

A resource value uses named aggregate syntax, with every ownership transfer marked by `own`:

```c
Buffer buffer = Buffer{
    length = size,
    own data = allocation
};
```

The resolved type determines that the initializer is a resource construction transaction rather than a plain struct copy. A resource lifetime does not begin until the transaction commits.

### OPENC-RESOURCE-INIT-REQUIRED-001 — Every ownership-bearing field is supplied exactly once

Every resource field and every `own ptr` field shall have exactly one initializer and shall not be omitted. Unknown fields, duplicate fields, and missing ownership-bearing fields are invalid. Plain fields may be omitted only when they have a valid declared default.

### OPENC-RESOURCE-INIT-OWNER-001 — Ownership clauses are explicit and require stable live owner sources

An ownership-bearing field shall use `own field = source`; an ordinary `field = expression` clause does not transfer ownership. Conversely, an `own field = source` clause is invalid for a plain or non-owning field. The source shall identify one stable live owner of the matching kind:

- a named local resource owner;
- a named local owning raw-pointer binding; or
- an ownership-bearing field path rooted in the current function's `own ResourceType` parameter.

An ownership-producing call, resource initializer, conditional output, arbitrary expression, temporary, cleanup-reserved owner, borrowed owner, non-owning pointer, or already moved owner is not a direct ownership-field source. Such work is bound to a stable owner in a preceding statement.

### OPENC-RESOURCE-INIT-RESERVE-001 — Construction reserves ownership sources before commit

When evaluation reaches an ownership-bearing field, the compiler reserves that source obligation for the current initializer without moving it yet. One obligation shall not be reserved twice, consumed, destroyed, reassigned, cleanup-bound, or committed into another owner while the reservation is active.

Ordinary non-consuming reads that are otherwise valid may observe a reserved source during the same initializer. Reservation does not start the destination resource lifetime.

### OPENC-RESOURCE-INIT-COMMIT-001 — Resource construction commits all ownership slots atomically

After every explicit initializer and applicable plain-field default has completed successfully, resource construction performs one non-failing commit:

1. every reserved ownership source moves exactly once;
2. every plain provisional field value is installed;
3. every nested obligation slot becomes live in the new resource; and
4. the outer resource lifetime and obligation begin in the destination.

There is no observable state in which only some ownership fields have moved into the destination.

### OPENC-RESOURCE-INIT-ROLLBACK-001 — Pre-commit checked failure preserves every source owner

If an initializer expression causes a language-generated checked failure before commit, all construction reservations are released, provisional plain values are discarded, the destination resource never begins lifetime, and every ownership source remains in its pre-initializer state.

Side effects of expressions that completed before the failure remain governed by ordinary evaluation rules; only ownership publication is transactional.

### OPENC-RESOURCE-INIT-PLACEMENT-001 — Ownership-producing expressions require a stable owner destination

A resource initializer, resource-returning call, or uniquely owning raw-pointer result shall appear only as:

- the initializer of a named owner binding;
- assignment to a definitely uninitialized or moved owner binding;
- a matching function return expression;
- assignment to a matching provisional owning output; or
- a stable preceding binding later consumed by another ownership operation.

It shall not be discarded, nested as an ordinary call argument, stored in a plain aggregate or optional, used as a condition, or hidden in another expression. Core Candidate 2 therefore has no unnamed owner temporaries requiring implicit destruction.

### OPENC-RESOURCE-REINIT-001 — Only an owner-empty binding may receive a new resource

A resource-producing value may initialize a resource binding whose state is definitely uninitialized or moved. Assigning a new resource to a live, cleanup-reserved, conditionally live, maybe-live, or ambiguous owner binding is invalid because the existing obligation would be overwritten or its state guessed.

### OPENC-RESOURCE-FIELD-VIEW-001 — Ordinary field access never extracts ownership

Outside a consuming resource context, a resource-typed field may be borrowed but not copied or moved. Reading an `own ptr` field yields only a non-owning `ptr T` view with the enclosing resource's lifetime; it does not duplicate or extract the unique pointer obligation.

Plain and non-owning fields follow their ordinary mutability rules.

### OPENC-RESOURCE-FIELD-ASSIGN-001 — Ownership-bearing fields are not replaced by assignment

A resource field or `own ptr` field shall not be replaced by ordinary field assignment. Replacement requires a domain operation that consumes the complete enclosing resource or a consuming context that discharges the old slot and commits a new complete resource.

### OPENC-RESOURCE-FIELD-CONSUME-001 — Field-level ownership transfer requires a consuming parameter

An ownership-bearing field may cross an `own` boundary only when its root binding is the current function's `own ResourceType` parameter. Consuming a nested resource field or `own ptr` field transfers that slot and marks it discharged in the source parameter.

A normal local resource owner, a borrowed resource, and a cleanup-reserved resource do not grant field-disassembly authority.

### OPENC-RESOURCE-DISMANTLE-001 — Consuming one field makes the resource incomplete

After any nested ownership slot is transferred from an `own ResourceType` parameter, that parameter enters the dismantling state. An incomplete resource shall not be borrowed as a whole, returned as a whole, passed as a whole to another `own ResourceType` parameter, or used by an operation requiring a complete resource.

Plain fields may still be read as required to discharge remaining slots, and remaining ownership slots may be transferred exactly once.

### OPENC-RESOURCE-FIELD-ONCE-001 — Every compiler-visible nested slot is discharged exactly once

Within a consuming resource function, each resource field and `own ptr` field shall have one terminal outcome: transferred onward or discharged by a matching consuming operation. Reusing an already transferred slot, transferring one slot twice, or returning while any slot remains live is invalid.

### OPENC-RESOURCE-CONSUMER-RETURN-001 — A consuming resource parameter has two valid terminal forms

On every normal or recoverable return from a function with an `own ResourceType` parameter, that parameter shall be in exactly one of these states:

- **whole transferred** — the complete resource was returned, committed, or passed onward as one owner; or
- **domain discharged** — every compiler-visible nested ownership slot was transferred or discharged, and completion of the consuming function discharges the outer resource obligation.

A complete resource with live nested slots, a partially dismantled resource with remaining slots, or an unresolved cleanup reservation is invalid at return.

### OPENC-RESOURCE-OPAQUE-DISCHARGE-001 — A slot-free resource relies on its consuming domain contract

A resource with no compiler-visible nested ownership slot may complete an `own ResourceType` function without a field transfer. The function's consuming contract is then the explicit domain boundary that discharges the resource's outer obligation, including any opaque external effect not represented as a Core field.

This rule does not excuse live resource fields or `own ptr` fields; those remain compiler-enforced slots.

### OPENC-STRUCT-DEFAULT-NODEP-001 — A field default cannot depend on another field

A field default is evaluated without a partially constructed object and therefore cannot name `this`, another field, or the destination binding. Shared dependencies are expressed as module constants.

### OPENC-STRUCT-INIT-COMMIT-001 — Plain aggregate construction publishes one complete value

A plain struct initializer evaluates all explicit and default fields before the destination value becomes initialized. A checked failure before completion leaves the destination uninitialized and publishes no partial object.

### OPENC-ENUM-IMPLICIT-001 — Implicit enum values advance by one

The first omitted enum value is zero. Each later omitted value is the previous member's value plus one using mathematical arithmetic. Overflow of the underlying type is a declaration diagnostic.

# 11. Arrays, slices, bytes, and text

### OPENC-ARRAY-DECL-001 — Array length is attached to the type

C-style declarations such as `i32 values[4];` are not OpenC syntax.

### OPENC-ARRAY-INIT-001 — Fixed array initialization supplies exactly its positive length

A fixed array length shall be a compile-time positive `usize` value. An array initializer supplies exactly that many compatible values. Partial implicit zero/default filling is not part of Core Candidate 2.

### OPENC-ARRAY-INDEX-001 — Fixed array indexing is checked

A statically known out-of-bounds index is a diagnostic. A dynamic out-of-bounds index produces a defined checked failure.

### OPENC-ARRAY-LENGTH-001 — Arrays expose `.length`

For `T[N]`, `.length` has type `usize` and value `N`.

### OPENC-ARRAY-COPY-001 — Copyability follows the element type

A fixed array is copyable only when its element type is copyable.

### OPENC-SLICE-BOUNDED-001 — A slice carries start, length, provenance, lifetime, and mutability

A slice is a non-owning bounded view over a contiguous live array or compatible provider region. Its abstract state includes element type, start, length, provenance, owner lifetime, and mutable/read-only capability. It is not a raw pointer and never silently loses its bounds.

### OPENC-SLICE-LENGTH-001 — Slices expose `.length`

The property is read-only and has type `usize`.

### OPENC-SLICE-FROMARRAY-001 — Array-to-slice conversion creates a checked borrow

A mutable array lvalue may form `T[]`; a const array or read-only view forms `const T[]`. The slice borrow lasts through its final use or declared escape bound. Temporary array values do not create escaping slices.

### OPENC-SLICE-MUTATE-001 — Only a mutable slice may assign elements

`T[]` permits element assignment when borrow rules allow it. `const T[]` permits reads only. A mutable slice converts to a read-only slice without changing extent or lifetime; the reverse conversion is invalid.

### OPENC-SLICE-RANGE-001 — Slice ranges are inclusive-exclusive and borrow the selected extent

`values[start..end]` denotes the elements with indices `start` through `end - 1`. Both endpoints are checked against `0..values.length`, and `start <= end` is required. The result retains provenance, owner lifetime, and constness.

### OPENC-SLICE-ALIAS-001 — Slice aliases obey the ordinary borrow exclusivity model

Multiple read-only slices may overlap. A mutable slice requires exclusive mutable access to its extent. A mutable slice and any overlapping mutable or read-only borrow cannot coexist unless the compiler proves the extents disjoint under `OPENC-SLICE-DISJOINT-001`.

### OPENC-ARRAY-NODECAY-001 — Arrays and slices do not become raw pointers implicitly

Conversion to `ptr T` requires an unsafe explicit operation and does not transfer safe bounds information.

### OPENC-BYTE-ARITH-001 — Byte arithmetic is explicit

`byte` supports equality and bitwise operators. Arithmetic uses an explicit cast to an integer type and back.

### OPENC-TEXT-LENGTH-001 — Text `.length` counts Unicode scalar values

For `text value`, `value.length` has type `usize` and reports the number of Unicode scalar values. Core defines no byte-length property because byte length depends on an explicit encoding contract outside the abstract text value.

### OPENC-TEXT-NOINDEX-001 — Core text has no direct numeric indexing or slicing

`text[index]` and numeric text ranges are not Core Candidate 2 operations. Their unit would be ambiguous across scalar values, grapheme clusters, and encodings. Hosted text APIs may provide explicit scalar iteration and encoding-aware operations under named contracts.

### OPENC-TEXT-CONVERT-001 — Text and bytes cross only through explicit encoding operations

There is no implicit conversion between `text`, `byte`, `byte[N]`, or byte slices. Encoding and decoding are library operations that name an encoding and define invalid-input behavior.

### OPENC-SLICE-RANGE-EMPTY-001 — Empty ranges are valid

A range with `start == end` produces a zero-length slice positioned at that boundary. A one-past boundary is valid only for an empty slice endpoint and is never dereferenceable.

### OPENC-SLICE-RANGE-DEFAULT-001 — Omitted slice endpoints have fixed meanings

In `values[..end]`, the start is zero. In `values[start..]`, the end is `values.length`. In `values[..]`, the complete extent is selected. Endpoint expressions evaluate left-to-right before bounds validation.

### OPENC-SLICE-DISJOINT-001 — Proven disjoint mutable slices may coexist

Two mutable slice borrows may coexist only when the compiler proves their viewed ranges do not overlap for their complete active lifetimes.

### OPENC-TEXT-EQUALITY-001 — Text equality compares exact scalar sequences

Two text values are equal only when they contain the same number of Unicode scalar values and each scalar is equal at the same position. Equality does not normalize, case-fold, or compare encoded byte sequences.

### OPENC-TEXT-COPY-001 — Text is an ordinary immutable value

Assignment, parameter passing, and return copy the abstract text value. Implementations may share immutable storage internally, but observable lifetime and equality shall match value semantics.

### OPENC-BYTE-DISTINCT-001 — Byte is a distinct eight-bit raw-data type

`byte` has exactly 256 values but is not implicitly interchangeable with `u8`, integer text code points, or character data. Checked casts may cross the numeric boundary when values are representable.

### OPENC-SLICE-COPY-001 — Copying a slice creates another borrow view

Copying a read-only slice creates another read borrow with the same extent and lifetime. Copying a mutable slice is permitted only when the resulting simultaneous borrow state remains valid; otherwise the copy is rejected as an alias conflict.

### OPENC-SLICE-ESCAPE-001 — A slice cannot outlive its owner

Returning, storing, or publishing a slice is valid only when the owner lifetime outlives the destination lifetime. A slice to a local array or constructed local object cannot escape that local lifetime.

# 12. Optional values, status, and recoverable failure

### OPENC-OPTIONAL-NONE-001 — `none` belongs to optional types

`none` converts only to `optional T`.

### OPENC-OPTIONAL-PRESENT-001 — Optional presence is observed through read-only `.present`

For `optional T value`, `value.present` is a read-only `bool`. A direct test of that property refines local flow state. The property cannot be assigned or forged independently of the optional value.

### OPENC-OPTIONAL-VALUE-001 — Optional `.value` requires proven presence

Accessing `.value` requires the current flow state to prove that the same optional binding is present. Without proof, a statically known access is rejected and an unavoidable runtime access produces a checked failure. `.value` has type `T` and follows the optional binding's constness.

### OPENC-STATUS-MUSTHANDLE-001 — A fallible result shall not die unobserved

A call that returns `status` creates one handling obligation. A status-returning call shall not be discarded as an expression statement. Assignment to a status binding retains rather than discharges the obligation. The obligation is discharged by reading `ok` or `code`, by using one of those fields in control flow, or by returning the status from the current function. Reading only `message` is not sufficient. Before the last binding carrying an unhandled result lineage is overwritten or leaves scope, the lineage shall be handled.

### OPENC-STATUS-OVERWRITE-001 — Pending status lineage cannot be silently erased

Overwriting or leaving scope with the last live binding of an unhandled status result is invalid. If that lineage also controls conditional out targets, losing the final carrier is invalid even after the status has merely been observed, unless every associated output state has been resolved or the status is validly forwarded.

### OPENC-STATUS-CODE-001 — Status code zero is success

Code `0` denotes success. Every nonzero `i32` code denotes recoverable failure in a domain defined by the producing module. Code identity, rather than message text, is the stable programmatic failure identity.

### OPENC-STATUS-INVARIANT-001 — Inconsistent status states are unrepresentable

The `ok` property is derived from `code`; it is not stored and cannot be supplied by a status initializer. Therefore a status value cannot represent `ok == true` with a nonzero code or `ok == false` with code zero.

### OPENC-STATUS-INITIALIZER-001 — Status initialization has one nonredundant form

A status initializer contains exactly one `code` field and at most one `message` field:

```c
status{ code = 0 }
status{ code = error_not_found, message = "not found" }
```

`code` shall have type `i32`. `message` shall have type `text` and defaults to empty text. The fields may appear in either named order. Duplicate fields, a missing `code`, an `ok` field, or any unknown field are invalid.

### OPENC-STATUS-MESSAGE-001 — Status message is descriptive, not proof-bearing

The `message` field is immutable descriptive text and defaults to empty text when omitted from a status initializer. Reading `message` neither proves success or failure nor, by itself, satisfies the obligation to handle a fallible result. Programs use `ok` or `code` for control flow.

### OPENC-OUT-OWNFLOW-001 — Owning outputs create conditional owner obligations

A resource output or `out own ptr T` output follows the ordinary proof lineage from Batch 3. Before proof, the target is unusable and carries no caller-visible owner. Proven success creates exactly one live owner obligation in the caller. Proven failure restores the target to definitely uninitialized and creates no obligation.

### OPENC-OUT-STATUSONLY-001 — Functions with `out` parameters return `status`

In Core Candidate 2, a function declaration containing one or more `out` parameters shall have result type `status`. This keeps output initialization proof tied to one immutable success/failure value.

### OPENC-ERROR-NOHIDDEN-001 — Recoverable control flow is visible

Ordinary recoverable failure shall not unwind through undeclared exception behavior.

### OPENC-ERROR-FATAL-001 — Fatal language failure uses the checked-failure model

Core does not define a second arbitrary fatal-error mechanism. Bounds, overflow, invalid optional extraction, division by zero, and similar dynamic safety violations produce the checked-failure outcome defined by `OPENC-TERM-CHECKFAIL-001`.

### OPENC-STATUS-READONLY-001 — `status` fields are immutable and `ok` is derived

`status` is a built-in plain value with a signed `i32 code`, a `text message`, and a read-only derived `bool ok` property. `ok` is exactly `code == 0`. Existing fields are not assignable. A status binding may be copied or reassigned only under the handling and proof-lineage rules in this chapter.

### OPENC-STATUS-PROOF-001 — An out call creates one local proof lineage

A call with out arguments creates a compiler-only proof lineage connecting the returned status result to exactly those output targets. The lineage has no runtime address or user-visible value. It exists only in the caller's local flow analysis and does not cross an ordinary function call.

### OPENC-STATUS-COPY-001 — Status copy shares handling and proof lineage

Copying a status value copies its visible fields and preserves the compiler-only result lineage. The copies are not independent fallible operations. Observing or returning any copy handles that result lineage, while output proof remains available through every unambiguous live copy.

### OPENC-OUT-NOPARTIAL-001 — Output publication is all-success or none

A normal status return publishes all outputs simultaneously when `ok` is true and publishes none when `ok` is false. The caller cannot observe provisional output state while the call executes. An implementation may write directly into exclusive caller storage, but its observable behavior shall match this transactional publication rule.

### OPENC-OUT-COMMIT-001 — Multiple outputs commit as one result

For a call with multiple outputs, successful return publishes every output together. Failure publishes none. There is no caller-observable state in which only some outputs from one call have committed.

### OPENC-OUT-OWNCOMMIT-001 — Successful owning output publication creates one caller owner

For `out ResourceType` and `out own ptr T`, successful return publishes the complete resource or unique pointer obligation as part of the call's all-success commit. The callee's provisional output obligation ends at the same commit where the caller's conditional target becomes the one live owner.

### OPENC-OUT-OWNTAIL-001 — Owning output assignment is a final non-failing commit step

After a callee assigns a resource or owning raw pointer to an output slot, the only remaining operations on that path are other non-failing output commits from already stable owners and preparation/return of a definitely successful status.

A branch, failure return, checked-failing operation, nested call, cleanup registration, second assignment, or other observable work after an owning output assignment is invalid. This tail rule prevents a provisional owner from requiring hidden rollback through a write-only out slot.

### OPENC-OUT-OWNFAIL-001 — Failure and checked failure occur before owning output commit

A path that returns failed status or may leave through language-generated checked failure shall do so before assigning any owning output. Local resources used to prepare a possible output remain ordinary local obligations and are discharged by explicit transfer or cleanup on those paths.

### OPENC-OPTIONAL-COPY-001 — Optional copy and equality follow the contained plain type

`optional T` is copyable when `T` is copyable and equality-comparable when `T` is equality-comparable. Two absent values are equal; an absent and present value are unequal; two present values compare their contained values.

### OPENC-OPTIONAL-PRESENT-READONLY-001 — Whole-optional assignment changes presence and invalidates proof

The `.present` property is read-only. Assigning `none` makes the optional absent. Assigning a compatible `T` or another optional replaces the whole optional. Any whole-value mutation invalidates earlier presence proof for that binding and its aliases.

### OPENC-OPTIONAL-ASSIGN-001 — A plain value may initialize or replace a matching optional

A value of type `T` may initialize or assign `optional T`, producing a present optional containing a copy of that value. No unrelated implicit conversion is introduced; the ordinary exact conversion rules apply before containment.

### OPENC-OPTIONAL-NESTED-001 — Nested optional types are outside Core Candidate 2

`optional optional T` is not a Core Candidate 2 type. A domain requiring multiple absence states uses a distinct enum or struct so the states have explicit names.

# 13. Ownership, borrowing, and lifetimes

### OPENC-LIFETIME-ACTIVE-001 — Safe access requires an active object lifetime

Reading, writing, borrowing, or returning an object before lifetime start or after lifetime end is invalid.

### OPENC-COPY-PLAIN-001 — Plain copy creates an independent value

Changing the copy does not change the original. A type with identity-bearing or ownership-bearing fields is not a plain copyable type.

### OPENC-OWN-USEAFTER-001 — Moved or discharged owners are unusable until reinitialized

After whole transfer, output publication, field commitment, or a consuming call, the source owner binding is moved. Reading, borrowing, consuming again, registering cleanup, or using it as an ownership source is invalid until a new ownership-producing value initializes that definitely owner-empty binding.

A diagnostic should identify both the invalid use and the operation that moved or discharged the obligation.

### OPENC-BORROW-MANYREAD-001 — Multiple read borrows may coexist

Multiple `ref const T` borrows are permitted while no conflicting write borrow or ownership operation is active.

### OPENC-BORROW-ONEWRITE-001 — A write borrow is exclusive

A `ref T` borrow shall not coexist with another active borrow that may access the same object or overlapping range.

### OPENC-BORROW-LASTUSE-001 — Local borrows end at last use when provable

The compiler may end a borrow before lexical scope end after its final use, enabling later safe mutation or transfer.

### OPENC-BORROW-NOMOVE-001 — Borrowed owners are not moved or destroyed

An owner shall not be consumed, destroyed, or released while a safe borrow remains active.

### OPENC-LIFETIME-RETURNLOCAL-001 — References to local storage do not escape

A function shall not return or store a safe reference or slice that can outlive a local owner.

### OPENC-LIFETIME-SLICE-001 — Slices do not outlive viewed storage

The lifetime of a slice is bounded by the lifetime of its owner and any narrower borrow scope.

### OPENC-OWN-SCOPE-001 — Cleanup-reserved owners remain usable but cannot change ownership state

A resource or owning raw pointer reserved by a consuming `scope` action remains readable and borrowable according to its ordinary API until cleanup executes. It shall not be moved, returned, reassigned, destroyed, committed into another resource, published through an output, reserved by another consuming action, or used as a resource-construction ownership source.

### OPENC-OWN-RETURN-001 — Returning an ownership-producing value transfers its obligation

A resource result type carries its own ownership contract and is written directly as `ResourceType`. A uniquely owning raw-pointer result is written `own ptr T`.

Preparing a return transfers the selected owner obligation into the result slot before scope cleanup runs. The returned value shall be a complete resource or owning pointer with no active borrow or pending cleanup reservation. `own ResourceType` result syntax remains invalid redundancy.

### OPENC-OWN-PRODUCE-001 — Ownership begins only at a defined production event

One new owner obligation begins only when a resource initializer commits, a resource or owning-pointer call result successfully returns into a stable owner destination, or a proven successful owning output is published. A failed call, failed resource initializer, unproven output, or rejected expression creates no owner.

### OPENC-OWN-CONSUME-ARG-001 — An `own` argument moves after argument evaluation and before callee entry

Function arguments evaluate left-to-right. After all earlier arguments are fully evaluated and the selected `own` argument is validated as one live unborrowed unreserved owner, its obligation transfers to the callee before the callee body begins. The caller binding becomes moved even when the callee later returns a recoverable failure.

### OPENC-OWN-CHECKEDGE-001 — Every structured checked-failure edge preserves exactly-once discharge

Flow analysis models an exit edge for every operation that may cause a language-generated checked failure, including such behavior propagated through a called function's interface metadata.

A live local resource or owning raw pointer may reach that edge only when its obligation is already moved/discharged or reserved by a valid consuming scope action. OpenC does not silently destroy an unreserved owner during checked-failure unwinding.

### OPENC-OWN-EXIT-001 — Every structured exit has a terminal owner state

At normal block completion, `return`, `break`, `continue`, recoverable function return, and language-generated checked failure, every owner binding leaving scope shall be moved/discharged or protected by one consuming cleanup reservation. A definitely live unreserved owner, maybe-live owner, ambiguous owner, or unresolved conditional owner is invalid.

### OPENC-OWN-PRODUCER-PLACEMENT-001 — Core has no unnamed ownership-producing temporaries

An ownership-producing expression requires a stable owner sink as defined by `OPENC-RESOURCE-INIT-PLACEMENT-001`. This rule applies uniformly to resource initializers, resource-returning calls, and `own ptr` results. Binding first makes movement, cleanup, diagnostics, and checked-failure edges explicit.

### OPENC-PTR-OWNCOPY-001 — A unique raw-pointer obligation never copies

A raw pointer binding known by flow analysis to own one allocation shall not be duplicated by ordinary assignment, argument passing, aggregate storage, or optional storage. A non-owning `ptr T` view may copy as an address value, subject to provenance and lifetime rules.

Ownership moves only through `own ptr T`, `out own ptr T`, commitment into an `own ptr` resource field, or an ownership-producing return/destination.

### OPENC-PTR-OWNCONTAIN-001 — Unique raw-pointer obligations appear only in explicit owner positions

A unique raw-pointer obligation may be held by a flow-tracked local `ptr T` binding, returned as `own ptr T`, published through `out own ptr T`, passed to `own ptr T`, or committed into an `own ptr T` field of a resource.

It shall not appear in an ordinary struct, optional, array, module constant, typed storage object, or unnamed temporary.

### OPENC-OWN-SCOPE-RESERVE-001 — A consuming scope action reserves one live owner obligation

Registration of a consuming scope action reserves exactly one live resource or owning raw-pointer obligation for discharge at the current lexical scope's structured exit. A moved, conditional, maybe-live, ambiguous, borrowed-incompatibly, already reserved, or non-owning value is not a valid consuming cleanup argument.

The reservation is not an immediate move. Cleanup execution performs the transfer exactly once.

### OPENC-OWN-SCOPE-BORROW-001 — Temporary borrows may coexist with a pending consuming cleanup

Read and write borrows may be created while a consuming scope action is pending because the owner remains live until cleanup execution. Every such borrow shall end before the cleanup call begins. A borrow shall not escape the cleanup scope or be used to justify a later ownership transfer.

# 14. Typed storage, raw pointers, and memory

### OPENC-STORAGE-NOVALUE-001 — Storage cannot be read as a value

Field access, copying, comparison, or borrowing as `T` is invalid before construction.

### OPENC-STORAGE-NORESOURCE-001 — Typed storage does not contain resource types

`storage T` requires a complete non-resource object type. Resource values are created, moved, and destroyed through their defining module's domain operations; generic placement construction and `destroy(reference)` do not substitute for those contracts.

### OPENC-CONSTRUCT-001 — Construct transactionally begins one object lifetime

`construct(storage_binding, value_expression)` requires empty `storage T`. The value expression is evaluated and checked to produce exactly `T` before the object lifetime begins. After complete preparation succeeds, one non-failing commit writes the value, begins one new lifetime generation, and yields `ref T`. If preparation checked-fails, the storage remains empty and no reference is produced.


### OPENC-CONSTRUCT-VALUE-001 — Construct accepts every legal storage target through an exact typed value

The second operand of `construct` is an ordinary expression whose static type is exactly the `storage T` target after only lossless implicit conversion. This covers primitive, enum, struct, text, status, optional, and fixed-array storage targets permitted by the storage grammar. Resource targets remain excluded.

### OPENC-CONSTRUCT-PLACEMENT-001 — A constructed lifetime begins only through one stable reference binding

A successful `construct` expression is valid only as the initializer of one new mutable local `ref T` binding in the same statement. It shall not be discarded, nested in another expression, returned from local storage, assigned to an existing reference, or used as an argument. This rule ensures that every live constructed object has an immediately usable reference through which `destroy` or `scope destroy` can end its lifetime.

### OPENC-CONSTRUCT-DOUBLE-001 — Live storage is not constructed twice

Constructing into storage that already contains a live object is invalid.

### OPENC-DESTROY-001 — Destroy ends one constructed non-resource lifetime

`destroy(reference)` ends the active non-resource object lifetime created by `construct`, after verifying that no conflicting borrow or slice remains. Destruction is non-fallible in Core. The storage becomes empty and may later be reconstructed.

### OPENC-DESTROY-BORROW-001 — Active conflicting borrows prevent destruction

An object shall not be destroyed while other safe references or slices remain active.

### OPENC-DESTROY-USEAFTER-001 — Access after destruction is invalid

The underlying storage may be constructed again after all references to the previous object are dead.

### OPENC-STORAGE-LIVEEXIT-001 — Constructed storage is destroyed before its storage lifetime ends

If `storage T` contains a live `T`, that object shall be destroyed before the storage binding leaves scope, is reused, or otherwise ceases to exist. Merely leaving the storage scope does not silently abandon a live constructed object.

### OPENC-STORAGE-RECONSTRUCT-001 — Storage may be reconstructed only after destruction

After `destroy(reference)` completes and every reference to the former object is dead, the same `storage T` may be used by a later `construct` to begin a new `T` lifetime.

### OPENC-STORAGE-REFINVALID-001 — Destruction invalidates references to the former object

Every `ref T`, `ref const T`, slice, or raw pointer access that depended on the destroyed object lifetime becomes unusable for typed access. Reconstructing the storage creates a new object lifetime and does not revive references to the earlier object.

### OPENC-PTR-NOLENGTH-001 — Raw pointers carry no general `.length`

A raw pointer is not a slice and shall not be indexed as safe bounded data.

OpenC Core Candidate 2 does not define `p[index]` for raw pointers. Canonical raw access is `*(p + index)` inside unsafe code.

### OPENC-PTR-ALIGN-001 — Typed pointer access requires target alignment

Dereferencing `ptr T` requires an address divisible by `align_of(T)` and a target context that supports the type. Misaligned access violates an unsafe precondition and produces a declared target fault; it does not grant arbitrary optimizer behavior.

### OPENC-PTR-LIFETIME-001 — Typed dereference requires one active compatible object lifetime

Dereferencing `ptr T` requires a live initialized object of compatible type at the addressed bytes. `ptr byte` may inspect initialized representation bytes under the byte-access rules. Reinterpretation alone does not create compatibility or begin a lifetime.

### OPENC-PTR-BYTE-001 — Byte pointers distinguish representation reads from writes

Inside unsafe code, `ptr const byte` may read initialized non-padding representation bytes of one live object, subject to provenance and bounds. Padding and uninitialized bytes are not values. A `ptr byte` may write byte objects, byte-array elements, or declared raw provider storage. It shall not mutate the representation of another live typed object under `OPENC-PTR-BYTEWRITE-001`.


### OPENC-PTR-BYTEWRITE-001 — Byte writes do not leave an invalid live typed representation

Writing representation bytes of a live non-byte object through `ptr byte` is invalid, even in unsafe code, because it could create invalid boolean, enum, pointer, resource, reference, optional, or padding state observable by safe typed access. A low-level operation that must rewrite representation first ends or invalidates the typed lifetime under a separately named unsafe contract, performs raw-byte mutation, and begins a new valid lifetime before safe typed access resumes.

### OPENC-PTR-DERIVED-NONOWNING-001 — Derived raw pointers do not duplicate allocation ownership

Pointer arithmetic, address-taking within an allocation, const-view conversion, and other non-consuming derivations produce non-owning pointer values. The original owning allocation pointer retains the unique free obligation until it is consumed or explicitly transferred by a domain operation.

### OPENC-PTR-ONEPAST-001 — One-past pointers may be formed but not accessed

Pointer arithmetic may form the address exactly one element past the permitted extent of one array or allocation. A one-past value may participate in equality, same-provenance ordering, and subtraction, but shall not be dereferenced, used as an object address, or deallocated.

### OPENC-PTR-CROSSALLOC-001 — Pointer arithmetic cannot leave its provenance extent

A derived pointer remains associated with the provenance of its origin. Arithmetic may produce positions from the first byte/element through the one-past position of that provenance. Producing or accessing a position outside that closed range violates an unsafe precondition and follows the target-fault model.

### OPENC-PTR-CONST-001 — Pointer constness controls pointed-to mutation

`ptr const T` may read a live initialized `T` in unsafe code but shall not write it. Converting `ptr const T` to `ptr T` requires an unsafe declared operation that proves the underlying object is mutable.


### OPENC-PTR-BINDING-MUTABLE-001 — Pointer constness applies to the pointed-to object, not the binding

`ptr const T` forbids mutation of the pointed-to `T` through that pointer. The local pointer binding remains reassignable unless ordinary declaration rules otherwise prevent assignment. Core 1.0 has no separate immutable-pointer-binding spelling such as `const ptr T`.

### OPENC-PTR-PROVENANCE-001 — Raw pointers retain origin and extent metadata abstractly

The abstract semantics of a raw pointer include nullness, target type/constness, provenance identity, byte offset, and lifetime validity. An implementation may represent this metadata implicitly, but its behavior shall match the abstract model.

### OPENC-PTR-BASE-001 — Only the owning base pointer can release an allocation

An allocation provider designates one owning base pointer. Derived pointers, const views, one-past values, reinterpreted views, and interior addresses are non-owning and cannot release that allocation. Release consumes the live owning base exactly once.

### OPENC-PTR-DEREF-RANGE-001 — Dereference requires a complete in-range object representation

Dereferencing `ptr T` requires the byte range `[offset, offset + size_of(T))` to lie completely inside the active provenance extent. A one-past or partially overlapping address is not dereferenceable.

### OPENC-PTR-INVALIDATE-001 — Lifetime end invalidates typed use of dependent pointers

Destroying an object or releasing an allocation invalidates typed and byte access through every raw pointer derived from that lifetime. Reusing the same numeric address for a later lifetime creates new provenance and does not revive old pointers.

### OPENC-PTR-SUBTRACT-001 — Pointer subtraction returns an element distance

Subtracting two compatible `ptr T` values with common provenance yields an `isize` element distance. Their byte-offset difference shall be exactly divisible by `size_of(T)` and representable by `isize`; otherwise the operation violates an unsafe precondition.

### OPENC-STORAGE-EMPTY-001 — Typed storage has an explicit empty/live state

Each `storage T` binding is either empty or contains one active `T` lifetime. Declaration creates empty storage. Successful `construct` changes empty to live. `destroy` changes live to empty. Copying or comparing storage is invalid.

### OPENC-STORAGE-COMMIT-001 — Construction publishes no partial object

A construction transaction evaluates initializer expressions and validates ownership/borrow conditions before lifetime start. The object becomes observable only after all fields/elements commit. A checked failure before commit leaves the storage empty.

# 15. Unsafe code and safe-wrapper obligations

### OPENC-UNSAFE-BOUNDARY-001 — Unsafe operations are lexically visible

A raw pointer dereference, raw address acquisition, raw pointer arithmetic, unchecked memory operation, reinterpretation, or foreign unchecked call requires an unsafe boundary.

### OPENC-UNSAFE-LOCAL-001 — Unsafe regions are no larger than necessary

Unsafe regions should contain only the low-level operations that require special trust. Unrelated safe work should remain outside the unsafe block.

### OPENC-UNSAFE-CALL-001 — Unsafe calls require unsafe context

A safe caller shall not invoke an unsafe function without entering an unsafe boundary.

### OPENC-UNSAFE-CONTRACT-001 — Unsafe preconditions are documented and testable

An exported unsafe function shall state the pointer validity, bounds, alignment, lifetime, aliasing, initialization, and ownership conditions required from the caller.

### OPENC-CAST-UNCHECKED-INT-001 — `cast_unchecked` is a deterministic integer conversion

In OpenC Core Candidate 2, `cast_unchecked(integer_type, integer_value)` is defined only between fixed or machine integer types and `byte`. For an N-bit destination, it keeps the low N bits of the source's fixed representation and interprets those bits according to the destination type. This may change the mathematical value and therefore requires unsafe context.

### OPENC-CAST-UNCHECKED-LIMIT-001 — Unchecked casts do not cover floating, pointer, enum, or aggregate conversion

Float-to-integer truncation, inexact integer-to-float conversion, floating narrowing, pointer conversion, enum conversion, and aggregate conversion are not silently supplied by `cast_unchecked` in plain OpenC Core Candidate 2. A dedicated declared operation or future rule is required.

### OPENC-REINTERPRET-VALUE-001 — Value reinterpretation is limited to equal-size bit-complete scalars

`reinterpret(T, value)` may copy the complete object-representation bits between equal-size fixed integers, machine integers, `byte`, `f32`, and `f64`. Every bit pattern of these destination categories is defined. `bool`, enum, text, status, optional, slice, struct, resource, safe reference, and storage values are not value-reinterpretation destinations in OpenC Core Candidate 2.

### OPENC-REINTERPRET-SIZE-001 — Value reinterpretation requires equal size

If source and destination value sizes differ, the expression is invalid. Reinterpretation neither truncates nor pads.

### OPENC-REINTERPRET-PTR-001 — Raw-pointer reinterpretation preserves address and provenance

`reinterpret(ptr U, pointer)` may change the raw pointed-to type while preserving the same address, allocation/object provenance, lifetime bound, and constness. It shall not remove pointed-to constness. Dereference under the new pointer type is valid only when alignment, active-object type, byte-access, and target rules separately permit it.

### OPENC-REINTERPRET-NOLIFETIME-001 — Reinterpretation does not create an object lifetime

Changing bits or a raw pointer's declared target type does not construct an object, initialize storage, legalize an inactive representation, or create unrelated provenance.

### OPENC-UNSAFE-WRAPPER-001 — Safe wrappers enforce all caller-independent safety conditions

A safe wrapper may contain unsafe operations only when it checks or structurally guarantees every condition necessary for safe callers.

If a caller must uphold a condition that can violate memory or type safety, the wrapper itself is unsafe.

### OPENC-UNSAFE-FAULT-001 — Unsafe faults are target-bounded, not arbitrary compiler behavior

An implementation shall document the permitted consequences of invalid unsafe operations for each target and optimization mode.

### OPENC-UNSAFE-NOASSUME-001 — Assertions and assumptions are distinct

Core Candidate 2 defines no optimizer-assumption operation. Any future assumption facility that can invalidate safety shall be explicit and unsafe.

### OPENC-UNSAFE-PROVENANCE-001 — Unsafe pointer use obeys target provenance rules

Unsafe does not permit a pointer to acquire unrelated allocation provenance merely through arithmetic, bit reinterpretation, or integer round-trip.

### OPENC-UNSAFE-HISTORY-001 — Defined effects before an unsafe fault remain defined

An implementation may trap before a physical unsafe fault, but it shall preserve observable safe-code effects completed before the fault under `OPENC-EXPR-ORDER-001` and the applicable `OPENC-EVAL-*` sequencing rules, except where the target itself physically prevents observation.

### OPENC-UNSAFE-PRECONDITION-001 — Every unsafe operation has a finite caller obligation

An unsafe operation shall state every condition required for defined behavior: provenance, extent, alignment, lifetime, initialization, constness, aliasing, ownership, and target capability as applicable. Conditions not stated by the operation are not silently imposed on callers.

### OPENC-SAFE-GUARANTEE-001 — Safe Core preserves memory, lifetime, type, and bounds safety

A valid safe Core program does not read uninitialized values, access outside a live object or slice extent, dereference null or invalid raw pointers, use an object after lifetime end, duplicate a unique ownership obligation, violate borrow exclusivity, or reinterpret storage as an unrelated live value. Environmental denial of service and logic correctness remain outside this guarantee unless separately specified.

### OPENC-SAFE-WRAPPER-001 — A safe wrapper owns every caller-independent proof obligation

A safe wrapper around unsafe implementation work validates or structurally guarantees every precondition that a safe caller cannot be required to know. If correctness still depends on caller-supplied provenance, alignment, lifetime, initialization, aliasing, or ownership facts, the wrapper is declared unsafe.

### OPENC-EXTENSION-SAFETY-001 — Extensions cannot silently weaken Core safety

An implementation extension may add syntax or capabilities only when declared in active context and conformance records. It shall not make invalid safe Core operations silently valid, reinterpret a Core rule, or remove a required diagnostic while claiming plain Core conformance.

# 16. Diagnostics, rule identity, and validation

### OPENC-DIAG-STRUCTURE-001 — Every diagnostic has stable structured identity

A machine-readable diagnostic contains schema version, primary rule ID, phase, category, severity, message, primary source span, zero or more related spans, and optional help/trace data. Human wording may improve without changing the stable identity fields.

### OPENC-DIAG-QUALITY-001 — A diagnostic explains the violated contract and relevant state

A diagnostic identifies what was invalid, the declaration or operation that established the rule, and the flow/ownership/provenance locations needed to understand it. Suggested fixes are included only when they preserve the programmer's likely intent and are mechanically safe.

### OPENC-DIAG-MACHINE-001 — Machine-readable diagnostics are a required interface

An implementation claiming Core Tooling support emits diagnostics in the normative versioned schema. Editors, fixtures, and conformance tools use structured fields rather than scraping human terminal text.

### OPENC-DIAG-TRACE-001 — Diagnostics preserve original and transformed source traceability

When a diagnostic originates in generated, expanded, or transformed source, it reports both the compiler-visible location and the user-authored origin chain. Core source processing does not hide the source unit where a declaration entered a logical module.


### OPENC-DIAG-SPAN-001 — Machine-readable source spans use portable coordinates

A source span is half-open and records a 1-based logical line, a 1-based Unicode-scalar column, a 0-based UTF-8 byte offset, and a UTF-8 byte length. A tab counts as one source scalar for the normative column; visual display width is UI-only. An initial BOM removed by `OPENC-SOURCE-BOM-001` contributes no position. Related and expansion spans use the same coordinate system.

### OPENC-DIAG-PHASE-001 — Core diagnostics use one stable phase taxonomy

The Core phases are: `source`, `lexical`, `syntax`, `declaration`, `name`, `type`, `constant`, `flow`, `ownership`, `borrow`, `unsafe`, `target`, and `runtime`. A rejection fixture names one expected primary phase and rule ID.

### OPENC-DIAG-SEVERITY-001 — Core distinguishes errors, warnings, notes, and help

An `error` rejects the current compilation or reports a runtime checked failure. A `warning` does not change plain Core validity unless a selected validation overlay elevates it. `note` and `help` entries support one primary diagnostic and never replace its rule identity.

### OPENC-DIAG-PRIMARY-001 — One primary rule identifies each rejection

When one source defect violates several consequences, the implementation selects the earliest causal rule in the defined compilation phase order as primary and reports dependent violations as related diagnostics. Conformance tests rely on the primary identity, not wording order.

### OPENC-GRAMMAR-AUTHORITY-001 — Normative EBNF is the only source-structure authority

Lexical rules define tokens, the normative EBNF defines source structure, and prose defines semantic validity of parsed structures. Prose shall not introduce syntax absent from EBNF. Any disagreement is a specification defect, not implementation discretion.

### OPENC-GRAMMAR-COVERAGE-001 — Every grammar production has conformance coverage

Before Core 1.0 freeze, every normative production has at least one accepted fixture and every significant rejection boundary has an invalid fixture with expected phase and rule ID. Directional or historical syntax is excluded from normative fixtures.

# 17. Deterministic evaluation and sequencing

### OPENC-EVAL-FULL-001 — Full expressions complete before the next full expression

All value computations, checked failures, assignments, ownership transitions, and observable calls caused by one full expression complete before evaluation of the next full expression begins.

### OPENC-EVAL-NOUNSPEC-001 — OpenC has no unspecified operand order

An implementation shall not select an arbitrary operand or argument evaluation order. Where this standard does not state a special rule, evaluation is left-to-right.

### OPENC-EVAL-CALL-001 — Call arguments evaluate left-to-right

Call arguments are evaluated completely from left to right before function-body execution begins.

### OPENC-EVAL-CALLEE-001 — The called declaration is fixed before argument evaluation

For every user or built-in overload set, name lookup and overload selection complete before argument evaluation begins. The selected declaration does not change in response to argument side effects, later source declarations, or declaration origin.

### OPENC-EVAL-ARGMODE-001 — Parameter-mode transitions occur at the call boundary

Borrow activation, output-slot reservation, and ownership consumption occur after all ordinary argument expressions have evaluated successfully and immediately before the call begins.

If argument evaluation fails, no `own` value is consumed and no `out` target becomes conditionally initialized by that call.

### OPENC-EVAL-BINARY-001 — Binary operands evaluate left-to-right

For a binary expression `left op right`, `left` is evaluated completely before `right`, except that `&&` and `||` additionally apply short-circuit rules.

### OPENC-EVAL-SHORT-001 — Short-circuit operators skip the right operand when required

For `left && right`, `right` is evaluated only when `left` is true. For `left || right`, `right` is evaluated only when `left` is false.

### OPENC-EVAL-UNARY-001 — A unary operand evaluates before the unary operation

The operand of a unary operation is evaluated completely before the operation is applied.

### OPENC-EVAL-ASSIGN-001 — Assignment evaluates the destination once

The destination location of an assignment is evaluated exactly once before the right-hand expression. The right-hand expression is then evaluated completely, converted under OpenC conversion rules, and written to the destination.

### OPENC-EVAL-COMPOUND-001 — Compound assignment evaluates its destination once

`target += value` and other compound assignments evaluate `target` once, read its existing value, evaluate `value`, perform the corresponding checked operation, and write the result.

A compound assignment is not permission to duplicate an indexing call, pointer calculation, or other destination side effect.

### OPENC-EVAL-ARRAYINIT-001 — Array initializer expressions evaluate left-to-right

Array initializer expressions evaluate from the first written element to the last. An array value becomes fully initialized only when every required element initializer completes successfully.

### OPENC-EVAL-STRUCTINIT-001 — Named struct initializer expressions evaluate in source order

Explicit named field expressions evaluate in the order written. Omitted field defaults then evaluate in field declaration order.

All initializer values are prepared before the new struct object's lifetime begins. If evaluation fails, no completed object exists.

### OPENC-EVAL-DEFAULT-001 — A field default is evaluated for each construction that uses it

A field default is evaluated independently each time an initializer omits that field, subject to the declared evaluation order.

### OPENC-EVAL-CONSTRUCT-001 — `construct` begins lifetime only after complete initialization

`construct(storage, initializer)` first verifies the storage state, evaluates the initializer, and then begins the object lifetime. If the initializer fails, the storage remains uninitialized and may be used for a later construction attempt.

### OPENC-EVAL-RETURN-001 — Return values are prepared before scope actions run

A return expression is evaluated and its value or ownership transfer is prepared before scope-exit actions execute. Scope actions then execute in required order, after which the prepared value is transferred to the caller.

A return shall not prepare a borrow to an object that is destroyed by the same return's scope exit.

### OPENC-EVAL-BREAK-001 — Loop exit state is prepared before exited-scope cleanup

For `break` and `continue`, control-flow destination is determined before cleanup actions for exited scopes run. The transfer occurs only after those actions complete.

### OPENC-EVAL-SCOPE-REGISTER-001 — A `scope` statement registers; it does not call immediately

At a `scope` statement, the called declaration is resolved and arguments are captured according to `OPENC-CLEANUP-CALLEE-001`, `OPENC-CLEANUP-VALUE-001`, `OPENC-CLEANUP-REF-001`, and `OPENC-CLEANUP-OWN-001`. The cleanup call itself executes only when the lexical scope exits.

### OPENC-EVAL-SCOPE-NESTED-001 — Scope arguments cannot hide deferred nested calls

A `scope` action argument shall not contain a nested fallible call, ownership-producing call, or other operation whose timing would be ambiguous. Such work shall be performed in an ordinary preceding statement and its resulting stable binding passed to the scope action.

### OPENC-EVAL-OBSERVABLE-001 — Optimization preserves defined observable order

An optimizer may reorder internal work only when the change cannot alter defined calls, explicit device or target effects, checked-failure location, ownership state, cleanup order, or other observable Core behavior.

# 18. Flow-sensitive state analysis

### OPENC-FLOW-STATE-001 — Each reachable path has a binding state

A read, borrow, move, assignment, destruction, or output operation is valid only when the binding state on every reachable path permits that operation.

### OPENC-FLOW-REACHABLE-001 — Unreachable paths do not create false initialization obligations

Definite-state analysis considers only reachable paths. Code after an unconditional `return`, `break`, `continue`, fatal checked failure, or exhaustive terminating switch case does not participate in the current path merge.

### OPENC-FLOW-IF-001 — An `if` merge keeps only facts true on every continuing branch

After an `if`/`else`, a binding is definitely initialized only when every branch that reaches the merge initializes it.

```c
i32 value;

if ready {
    value = 1;
} else {
    value = 2;
}

use(value);
```

is valid.

### OPENC-FLOW-IF-NOELSE-001 — An `if` without `else` preserves the pre-branch state

Initialization performed only inside an `if` body does not make a previously uninitialized binding definitely initialized after the statement unless the false path cannot continue.

### OPENC-FLOW-SWITCH-001 — Exhaustive switches merge all continuing cases

An exhaustive enum switch may establish definite state when every case that continues initializes or otherwise establishes the same required fact.

### OPENC-FLOW-WHILE-001 — A `while` body may execute zero times

Initialization performed only in a `while` body does not establish initialization after the loop unless the compiler proves entry and all exits preserve the fact.

### OPENC-FLOW-FOR-001 — A `for` body may execute zero times

The same rule applies to `for`. Loop initializer declarations are initialized according to their own declarations but remain loop-local.

### OPENC-FLOW-CONTINUE-001 — `continue` participates in the next-iteration merge

Every path that reaches the next iteration, including `continue`, shall satisfy the loop's required initialization, ownership, and borrow state.

### OPENC-FLOW-BREAK-001 — Loop-exit state merges all reachable breaks and condition exits

A state fact holds after a loop only when it holds for every reachable way the loop may terminate.

### OPENC-FLOW-OUT-TOKEN-001 — Out targets are conditional until the status lineage is refined

After `status result = make(out value);`, `value` is in a conditional state: initialized exactly on the success side of `result` and uninitialized exactly on its failure side. Until a recognized proof resolves that state, `value` cannot be read, assigned, borrowed, moved, destroyed, passed, or registered for cleanup.

### OPENC-FLOW-OUT-PREDICATE-001 — Only explicit status predicates refine output proof

The mandatory proof atoms are `result.ok`, `!result.ok`, `result.code == 0`, `0 == result.code`, `result.code != 0`, and `0 != result.code`. Equality of `code` to a compile-time known nonzero value proves failure only on the equal branch. Parentheses, `!`, `&&`, and `||` compose these atoms using ordinary short-circuit path semantics. A copied `bool`, helper function result, message test, status equality, or unrelated arithmetic expression carries no output proof.

### OPENC-OUT-PENDINGUSE-001 — Conditional outputs are unusable before proof

A conditional out target shall not be read, assigned, borrowed, moved, destroyed, passed to another call, or registered in a scope action before its lineage is resolved. This uniform rule prevents successful resource output from being overwritten or leaked while the call result remains unknown.

### OPENC-FLOW-OUT-SUCCESS-001 — Proven success initializes associated outputs

On a path that proves a single proof-bearing status lineage successful, every target associated with that lineage becomes definitely initialized. Owning targets also acquire their ownership obligations on that path.

### OPENC-FLOW-OUT-FAILURE-001 — Proven failure restores associated targets to uninitialized state

On a path that proves a single proof-bearing status lineage failed, every target associated with that lineage becomes definitely uninitialized and may be assigned normally or reused as an out target. No owning obligation exists on that path.

### OPENC-FLOW-OUT-MERGE-001 — Merges retain only common output facts

At a control-flow merge, an output is definitely initialized only when every continuing predecessor proves it initialized, definitely uninitialized only when every predecessor proves it uninitialized, and still conditional only when every predecessor carries the same unresolved lineage. Success on one predecessor and failure on another produces a maybe-initialized plain state that cannot be read until ordinary code initializes it on all continuing paths. Distinct unresolved lineages produce an ambiguous state that cannot prove any output.

### OPENC-FLOW-OUT-LOOP-001 — Unresolved output proof does not cross a loop back-edge

A loop-local out result may be proved and used within one iteration. An unresolved or ambiguous output lineage shall not cross a `continue` or loop back-edge. After a loop, output state is merged from the zero-iteration path, the condition exit, and every reachable `break`; loop-only initialization does not prove later availability.

### OPENC-OUT-PROOF-LOST-001 — Losing proof never guesses output state

If the last carrier of a lineage is lost while a target remains conditional or ambiguous, the program is invalid. The implementation shall identify the producing call, the lost status binding, and the affected outputs. It shall not guess success, silently discard a possible owner, or default-initialize the target.

### OPENC-FLOW-OUT-COPY-001 — Direct status copies preserve one proof lineage

A direct copy of an immutable proof-bearing status carries the same lineage; it does not create a second call result. Any copy may be used for recognized proof. Overwriting one copy does not lose proof while another live binding still carries the lineage.

### OPENC-FLOW-OPTIONAL-001 — Presence checks refine optional access

Inside a branch that proves `value.present`, `value.value` may be accessed without a runtime presence check.

### OPENC-FLOW-OPTIONAL-ELSE-001 — A terminating absence branch proves later presence

After:

```c
if !value.present {
    return 1;
}

use(value.value);
```

execution that continues has proven presence.

### OPENC-FLOW-OPTIONAL-INVALIDATE-001 — Mutation invalidates optional presence proof

Assigning to an optional value, passing it by mutable borrow, moving it, or calling an operation that may change its presence invalidates an earlier presence proof.

### OPENC-FLOW-MOVED-001 — Resource and owning-pointer move state is path-sensitive

Flow analysis tracks resource and owning-pointer states independently on every path: uninitialized, conditional, live, cleanup-reserved, moved, maybe-live, and ambiguous. A merge preserves a definite live or moved fact only when every continuing predecessor agrees. Live plus moved becomes maybe-live; unrelated conditional lineages become ambiguous. Neither state permits use, reassignment over a possible live owner, or scope exit without further proof.

### OPENC-FLOW-BORROW-001 — Borrow activity is tracked to last provable use

A local borrow may end at its final use. Mutation, movement, destruction, or conflicting borrowing may follow only after the compiler proves the earlier borrow inactive.

### OPENC-FLOW-DESTROYED-001 — Destruction state is path-sensitive

A destroyed or freed value is unavailable. If destruction occurs on only some continuing branches, later use is invalid unless all branches reinitialize an appropriate value.

### OPENC-FLOW-DIAG-001 — State diagnostics show the path-defining locations

A state diagnostic should identify the invalid use and relevant declaration, initialization, move, output call, presence mutation, borrow, destruction, or branch location that established the conflicting state.

# 19. Exact numeric execution

### OPENC-NUM-TWOS-001 — Signed fixed-width integers are two's complement

For signed type `iN`, the range is `-2^(N-1)` through `2^(N-1)-1`, and its object representation is two's complement without padding bits.

### OPENC-NUM-UNSIGNED-001 — Unsigned fixed-width integers have range zero through 2^N minus one

For unsigned type `uN`, the range is `0` through `2^N-1`, with no padding bits.

### OPENC-NUM-BYTE8-001 — A byte contains exactly eight bits

`byte` has values `0` through `255` and an eight-bit object representation. It remains semantically distinct from `u8`.

### OPENC-NUM-MACHINE-001 — Machine integers use the target pointer width

`usize` and `isize` use the target's declared pointer width. `usize` represents every valid object size and byte offset; `isize` represents signed pointer differences supported by the target.

### OPENC-NUM-LITERAL-CONTEXT-001 — Integer literals are context-typed when possible

An integer literal takes the expected integer type when the literal value is representable by that type.

### OPENC-NUM-LITERAL-DEFAULT-001 — Unconstrained integer literals have one default across all bases

An unconstrained decimal, hexadecimal, or binary integer literal has type `i32` when its exact mathematical value is representable, otherwise `i64` when representable. A larger value requires an expected representable integer type and otherwise produces a diagnostic. Literal base does not change the default signed type rule.

### OPENC-NUM-LITERAL-NEGATIVE-001 — A negative literal is unary minus applied to a positive literal

The minimum signed value is accepted when the complete constant expression is representable. Implementations shall not reject `-2147483648` merely because the positive token exceeds `i32`.

### OPENC-NUM-ADD-001 — Ordinary integer add, subtract, multiply, and unary minus are checked

For a destination integer type, ordinary `+`, `-`, `*`, and unary `-` compute the mathematical result and succeed only when it is representable. A compile-time known failure is a diagnostic; a runtime failure is a checked failure. No operation wraps silently.

### OPENC-NUM-DIV-001 — Signed integer division truncates toward zero

For nonzero divisor, signed integer division truncates the exact mathematical quotient toward zero.

### OPENC-NUM-REM-001 — Integer remainder follows the dividend sign

For `a % b`, `a == (a / b) * b + (a % b)` and the nonzero remainder has the sign of `a`.

### OPENC-NUM-DIV-MIN-001 — Minimum divided by negative one is checked overflow

For a signed type, `minimum / -1` and the corresponding remainder operation are checked failures because the quotient is not representable.

### OPENC-NUM-DIVZERO-001 — Integer division and remainder by zero are checked failures

A compile-time zero divisor is rejected. A runtime zero divisor produces a checked failure after evaluating operands in the defined order. It does not produce a value and does not become optimizer undefined behavior.

### OPENC-NUM-BITWISE-001 — Ordinary bitwise operations use unsigned integers or byte

`&`, `|`, `^`, and `~` operate on matching unsigned integer types and `byte`. Signed operands require explicit conversion.

### OPENC-NUM-SHIFT-001 — Shift counts are checked before shifting

The right operand of `<<` or `>>` shall be nonnegative and less than the bit width of the left operand type. A statically invalid count is rejected; a runtime invalid count produces a checked failure.

### OPENC-NUM-SHIFTRIGHT-001 — Right shift of unsigned values is logical

Unsigned right shift inserts zero bits.

### OPENC-NUM-SHIFTLEFT-001 — Ordinary left shift is checked

A left shift whose mathematical result is outside the destination type range is a checked failure. Core defines no separate wrapping-shift intrinsic; programmers use an explicit valid count and the fixed wrapping arithmetic intrinsics when modulo arithmetic is required.

### OPENC-NUM-WRAP-001 — Wrapping intrinsics compute modulo 2^N

Core defines the built-in overloads `wrap_add(T,T) -> T`, `wrap_sub(T,T) -> T`, and `wrap_mul(T,T) -> T` for every signed or unsigned integer type, including `isize` and `usize`. They return the low N bits of the mathematical result. Signed results use the fixed two's-complement interpretation. They are safe operations and do not checked-fail for overflow.

### OPENC-NUM-SATURATE-001 — Saturating intrinsics clamp to the destination range

Core defines the built-in overloads `saturating_add(T,T) -> T`, `saturating_sub(T,T) -> T`, and `saturating_mul(T,T) -> T` for every signed or unsigned integer type, including `isize` and `usize`. A result below the minimum becomes the minimum; a result above the maximum becomes the maximum. These operations do not checked-fail for overflow.


### OPENC-NUM-INTRINSIC-001 — Core arithmetic variants are a closed intrinsic set

The six overload families named by `OPENC-NUM-WRAP-001` and `OPENC-NUM-SATURATE-001` are the complete Core 1.0 arithmetic-variant intrinsic set. Core defines no separate unchecked arithmetic operation because deterministic modulo arithmetic is already expressed by wrapping intrinsics. Division by zero and invalid shift counts remain checked failures.

### OPENC-NUM-CAST-INT-001 — Integer-to-integer `cast` succeeds only when the value is representable

A checked integer cast preserves the mathematical value. Otherwise it produces a defined checked failure.

### OPENC-NUM-CAST-FLOATINT-001 — Float-to-integer `cast` requires a finite integral value in range

`cast(integer_type, floating_value)` succeeds only when the source is finite, has no fractional component, and lies within the destination range.

### OPENC-NUM-CAST-INTFLOAT-001 — Integer-to-float `cast` requires exact representation

A checked integer-to-floating cast succeeds only when the destination floating type represents the integer exactly.

### OPENC-NUM-CAST-FLOAT-001 — Floating narrowing `cast` requires exact representation

A checked `f64` to `f32` cast succeeds only when the value, including signed zero and non-finite category, is exactly representable under the destination model.

### OPENC-NUM-UNCHECKEDCAST-001 — Unchecked integer conversion uses low-bit modulo semantics

The exact integer semantics of `cast_unchecked` are defined by `OPENC-CAST-UNCHECKED-INT-001` and `OPENC-NUM-UNCHECKEDCAST-001` and use the fixed representation rules of this chapter. The operation does not inherit a target-specific C conversion rule.

### OPENC-NUM-FLOAT-FORMAT-001 — Floating formats are fixed

`f32` and `f64` use IEEE 754 binary32 and binary64 value sets and encodings respectively.

### OPENC-NUM-FLOAT-ROUND-001 — Ordinary floating arithmetic uses round-to-nearest, ties-to-even

Ordinary floating arithmetic uses round-to-nearest, ties-to-even. Hidden process rounding-mode changes shall not alter ordinary Core expression meaning.

### OPENC-NUM-FLOAT-NONFINITE-001 — Infinity and NaN are defined values

Positive infinity, negative infinity, and NaN are defined floating values. NaN comparisons follow IEEE behavior: equality with NaN is false and inequality is true.

### OPENC-NUM-FLOAT-DIVZERO-001 — Floating division by zero follows IEEE behavior

A finite nonzero value divided by signed zero produces the correspondingly signed infinity. Zero divided by zero produces NaN. These are defined floating results, not integer-style checked failures.

### OPENC-NUM-FLOAT-ORDER-001 — Floating comparisons are ordered except for NaN

`<`, `<=`, `>`, and `>=` are false when either operand is NaN.

### OPENC-NUM-CONST-001 — Compile-time numeric evaluation matches runtime semantics

Constant evaluation uses the same ranges, rounding, checked-failure rules, casts, shifts, and comparison semantics as runtime evaluation.

### OPENC-NUM-AUTHORITY-001 — The numeric execution chapter is authoritative

Rules in expression, conversion, constant-evaluation, and target chapters defer to this chapter for exact numeric results. Duplicate summaries do not define alternative algorithms.

### OPENC-NUM-COMPOUND-001 — Compound assignment uses one checked arithmetic operation

`x op= y` evaluates `x` once, evaluates `y`, applies the corresponding ordinary checked operation, converts exactly to the destination type, and stores only on success. A checked failure leaves the destination unchanged.

### OPENC-NUM-FLOAT-CONST-001 — Compile-time floating evaluation matches runtime format and rounding

A constant floating expression uses the same `f32` or `f64` value format, round-to-nearest ties-to-even mode, NaN comparison behavior, and non-finite values as runtime evaluation. An implementation shall not use wider host arithmetic when that changes the required result.

# 20. Scope actions, cleanup, and termination

### OPENC-CLEANUP-REGISTER-001 — `scope` registers one statically no-fail cleanup call

A `scope` statement registers one call in the current lexical scope. The selected declaration is resolved at registration, returns `void`, contains no `out` parameter, and is proven transitively no-fail: no reachable path may return recoverable failure, produce a language-generated checked failure, execute an unsafe operation, or create an ownership-producing result.

```c
scope buffer_destroy(buffer);
scope destroy(object);
```

The call is not executed at registration. A fallible `finish`, `flush`, `commit`, or domain-equivalent operation is handled explicitly before scope exit; only its no-fail release/discard operation is registered.

### OPENC-CLEANUP-CALLEE-001 — Cleanup declaration and parameter modes are fixed at registration

Overload resolution, module qualification, and parameter modes for a scope action are fixed when the statement is registered. Later declarations, shadowing, or state changes do not select another cleanup operation.

### OPENC-CLEANUP-VALUE-001 — By-value cleanup arguments are captured at registration

A plain by-value argument is evaluated and copied at registration. The later cleanup receives that captured value. The argument expression shall not contain a nested call, assignment, allocation, ownership transfer, or other deferred work; such work is completed in a preceding statement.

### OPENC-CLEANUP-REF-001 — Borrowed cleanup arguments keep one borrow until execution

A `ref` or `ref const` cleanup argument creates a borrow at registration that remains active until the cleanup call executes. The referent shall outlive the registration, and conflicting mutation, movement, reconstruction, or destruction is rejected while the cleanup borrow is active.

### OPENC-CLEANUP-OWN-001 — Consuming cleanup reserves exactly one owner obligation

When the selected cleanup parameter is `own ResourceType` or `own ptr T`, registration reserves the named owner for that cleanup. The value remains usable through ordinary borrows, but it cannot be moved, returned, reassigned, manually consumed, committed into another resource, or registered for a second consuming cleanup.

### OPENC-CLEANUP-OUT-001 — Scope actions cannot contain `out` arguments

A scope action shall not initialize a value for later ordinary use because it runs only while the scope is leaving.

### OPENC-CLEANUP-ARG-001 — Cleanup arguments are literals or stable name paths

The grammar permits only literals and qualified name paths as scope arguments. A name path shall resolve at registration to a stable local binding, module constant, or stable non-ownership field path accepted by the selected parameter mode. Arbitrary arithmetic, calls, indexing, ranges, assignment, allocation, ownership transfer, and other computed expressions are invalid in a scope argument; the programmer binds a computed value in a preceding statement.

### OPENC-CLEANUP-DESTROY-001 — `scope destroy(reference)` reserves the object lifetime endpoint

Registering `scope destroy(reference);` records destruction of the currently referred object at scope exit. It does not hold an exclusive read or write borrow for the entire remaining scope. Ordinary safe use and temporary borrowing remain allowed while the object stays live.

### OPENC-CLEANUP-DESTROY-RESERVE-001 — A destruction-bound object is not ended or reconstructed early

Before the registered destruction runs, the object shall not be explicitly destroyed, have its storage reconstructed, escape beyond the cleanup scope, or be bound to another destruction action. Every temporary borrow shall end before cleanup execution.

### OPENC-CLEANUP-DESTROY-STORAGE-001 — Scope destruction discharges typed-storage lifetime obligation

When the object was created in `storage T`, successful execution of the registered `destroy` action ends the object lifetime before the storage binding leaves scope and permits later reconstruction only after that cleanup has completed.

### OPENC-CLEANUP-LIFO-001 — Cleanup runs in reverse registration order

Within one scope, the last registered action executes first.

### OPENC-CLEANUP-NESTED-001 — Inner scopes clean before outer scopes

When several lexical scopes are exited, all actions of the innermost exited scope run before actions of its enclosing scope.

### OPENC-CLEANUP-ONCE-001 — A registered scope action executes at most once

A scope action is removed after execution. Re-entering a loop body creates new registrations for that iteration's block instances.

### OPENC-CLEANUP-STRUCTURED-001 — Every defined structured exit runs all registered cleanups

Normal block completion, `return`, `break`, `continue`, a recoverable status return, and a language-generated checked failure run every cleanup registered in each exited scope. Inner scopes execute before outer scopes, and each scope executes in reverse registration order.

### OPENC-CLEANUP-RETURN-001 — Return state is prepared before complete no-fail cleanup

A return expression and any explicit ownership transfer required by it are evaluated and reserved before cleanup begins. Every applicable cleanup then executes in deterministic order. Because registered cleanup is statically no-fail, the prepared return is delivered after all cleanup completes. A binding reserved for cleanup cannot simultaneously supply the return value.

### OPENC-CLEANUP-CHECKFAIL-001 — A pending checked failure runs complete no-fail cleanup before termination

When a language-generated checked failure exits one or more scopes, the failure becomes pending, all registered cleanup actions for those scopes execute completely in LIFO order, and then the original checked failure is reported and terminates the current operation. Cleanup cannot replace, mask, aggregate with, or resume the pending failure because cleanup actions are statically no-fail.

### OPENC-CLEANUP-UNSAFEFAULT-001 — Target faults do not promise structured cleanup

An unsafe precondition violation may produce a declared target fault. Core does not guarantee that a target fault executes pending scope actions. The target contract shall state whether any cleanup or diagnostic delivery is possible; no implementation may retroactively erase effects sequenced before the fault.

### OPENC-CLEANUP-NOFALLIBLE-001 — Fallible finalization is explicit before no-fail cleanup registration

An operation whose meaningful finalization may fail recoverably is called and handled in ordinary control flow. After successful finalization—or when abandoning uncommitted state—the program registers or invokes a separate no-fail ownership release.

```c
status finished = file_finish(file);
if !finished.ok {
    return finished.code;
}
scope file_release(file);
```

The exact Hosted names are domain-defined; Core fixes the separation of fallible finalization from no-fail release.

### OPENC-CLEANUP-FAILURE-001 — A cleanup action with a possible checked failure is ineligible

If a callable body, imported interface contract, or transitive callee can produce a language-generated checked failure, target fault, recoverable result, or implementation-dependent failure, that callable is not eligible for `scope`. The programmer first performs any fallible finalization in ordinary control flow and then registers a separately proven no-fail release/discard operation.

### OPENC-CLEANUP-NOCANCEL-001 — Core has no implicit scope-action cancellation

A consuming scope action remains pending until it runs. Code that intends to transfer or return the resource shall delay registration or use a narrower lexical scope. An implementation shall not silently cancel cleanup because ownership was moved illegally.

### OPENC-CLEANUP-VOID-001 — A cleanup target returns void and exports a no-fail contract

The selected cleanup declaration returns `void` and its interface metadata proves transitive no-fail eligibility for every valid input accepted by the public contract. A safe cleanup wrapper may contain internal unsafe operations when it proves every precondition and admits no target fault for valid inputs. A call returning `status`, a resource, an owning pointer, or another value is invalid as a scope action.


### OPENC-CLEANUP-SAFEWRAPPER-001 — Proven safe release wrappers remain cleanup-eligible

Internal unsafe implementation does not by itself make a cleanup target ineligible. Eligibility depends on the exported function contract and transitive effect summary: valid callers must be unable to trigger recoverable failure, checked failure, or target fault. If any safety precondition remains the caller's responsibility, the function is unsafe and cannot be registered as a safe Core scope cleanup.

### OPENC-CLEANUP-ALL-001 — Every registered cleanup completes on every structured exit

Once structured cleanup begins, each registered action in every exited scope executes exactly once in required LIFO order. Since all eligible actions are no-fail, no cleanup action suppresses or prevents a later action. Only an external or unsafe target fault, which is outside the safe structured-exit guarantee, may physically prevent completion.

### OPENC-CLEANUP-PRIMARY-001 — The initiating return or checked failure remains the sole terminal outcome

Cleanup introduces no competing recoverable or checked-failure outcome. A normal return remains the return outcome; a language checked failure remains the primary failure after cleanup. Core therefore defines no hidden cleanup-failure precedence or failure aggregation mechanism.

### OPENC-CLEANUP-FINISH-001 — Resource APIs separate fallible protocol completion from no-fail obligation release

A resource whose `flush`, `finish`, `commit`, or synchronization step can fail exposes that step as an ordinary fallible operation. Its release/discard operation consumes ownership and is guaranteed no-fail for every valid owner state accepted by its contract. Only that no-fail operation is cleanup-eligible.

### OPENC-CLEANUP-STATE-001 — Cleanup reservation is part of flow state

Flow analysis records whether an owner is live, cleanup-reserved, moved, or conditionally live. A cleanup-reserved owner may leave scope only through the registered consuming action. Merges with incompatible reservation states are rejected unless every continuing path establishes the same reservation.

# 21. Target model and portability

### OPENC-TARGET-CONTEXT-001 — One declared target record supplies every Core target fact

Before semantic analysis, the implementation provides an inspectable target record containing target identity, pointer width, endianness, object-size limits, required alignments, and unsafe fault outcomes. Every target-dependent rule names a field from this record; undeclared host facts cannot influence conformance.

### OPENC-TARGET-BYTE-001 — Addressable bytes are eight bits

The smallest addressable storage unit used by OpenC object representations is eight bits.

### OPENC-TARGET-ENDIAN-001 — Endianness is declared but does not change value semantics

The target record declares little- or big-endian byte order for object representations and Native boundaries. Integer, floating, array, struct, and text value semantics are independent of endianness unless a byte-level operation explicitly observes representation.

### OPENC-TARGET-ALIGN-001 — Every complete object type has a reported alignment

An implementation shall provide size and alignment information to tooling for complete object types relevant to the active target.

### OPENC-TARGET-ARRAYLAYOUT-001 — Arrays are contiguous without inter-element padding

For `T[N]`, elements occupy N consecutive `T` slots with the alignment of `T`. The address difference between adjacent elements is the target-reported size of `T` in target bytes.

### OPENC-TARGET-STRUCTLAYOUT-001 — Ordinary struct layout is not a portable wire format

Field order is semantically fixed, but physical offsets and padding are target-defined and reported through the active target record. Exact external or wire layout is outside Core Candidate 2.

### OPENC-TARGET-PADDING-001 — Padding is not part of value semantics

Padding bytes do not participate in equality, copying meaning, hashing, serialization, or initialization state. Reading padding as initialized data requires an unsafe target operation and remains subject to target policy.

### OPENC-TARGET-SIZEOF-001 — size_of reports one positive complete object size

`size_of(T)` is a compile-time `usize` value for a complete Core object-representation type. Valid operands are primitive object types, enum, struct, resource, fixed array, slice, optional plain value, `ref T`, `ptr T`, and `storage T`. `void` and incomplete types are invalid. Every complete object type occupies at least one target byte, including an empty struct or resource.

### OPENC-TARGET-ALIGNOF-001 — align_of reports one positive complete object alignment

`align_of(T)` is a compile-time nonzero `usize` value for the same complete object-representation domain accepted by `size_of(T)`. The alignment is expressed in target bytes and is a power of two unless the target record explicitly declares another finite alignment model supported by the implementation.


### OPENC-TARGET-QUERYDOMAIN-001 — Type-query operands form one closed complete-object domain

Type queries reject `void`, incomplete declarations, parameter modes such as `own` and `out`, and any syntax that is not a type. A supported implementation shall report size and alignment for every valid Core type in the closed domain; it cannot accept the type in source while leaving the query meaning unspecified.

### OPENC-TARGET-STORAGESIZE-001 — Typed storage has the target size and alignment of its target

For valid `storage T`, `size_of(storage T) == size_of(T)` and `align_of(storage T) == align_of(T)`. Compiler-only lifetime state is not part of the runtime object representation exposed by these queries.

### OPENC-TARGET-ARRAYSIZE-001 — Fixed-array size is element size multiplied by length

For `T[N]`, `size_of(T[N]) == size_of(T) * N`. A type whose required size exceeds the target's maximum object size is unsupported and diagnosed before translation succeeds.

### OPENC-TARGET-QUERY-001 — Type queries do not evaluate runtime expressions

`size_of` and `align_of` accept a type, not an expression. They introduce no hidden runtime evaluation or object access. Target-dependent results are included in portability and build-context reporting when they affect observable layout or external interfaces.

### OPENC-TARGET-PTRPROV-001 — Every usable raw pointer carries declared provenance

A non-null raw pointer used for typed or byte access carries provenance identifying one active object, fixed array, typed-storage object lifetime, or allocation. Address-of establishes object provenance; allocator/provider contracts establish allocation provenance; derivation preserves provenance. Integer-derived or foreign pointers require an explicit target contract before access.

### OPENC-TARGET-PTROFFSET-001 — Pointer offsets are bounded by provenance and element size

For `ptr T`, adding or subtracting an integer changes the offset by `size_of(T)` bytes. The resulting position shall remain within the provenance extent or exactly one-past. Arithmetic on `ptr byte` advances by one byte.

### OPENC-TARGET-PTRCROSS-001 — Pointer derivation never changes provenance by arithmetic

Arithmetic cannot move a pointer into another object or allocation, even when numeric addresses are adjacent. A pointer that numerically falls inside another object but retains the wrong provenance is not valid for access to that object.

### OPENC-TARGET-PTRCOMPARE-001 — Ordered pointer comparison uses one common provenance

`<`, `<=`, `>`, `>=`, and pointer subtraction are valid only when both non-null pointers have the same provenance and compatible element interpretation. Equality remains defined under `OPENC-PTR-COMPARE-001`.

### OPENC-TARGET-PTRINT-001 — Pointer/integer conversion is unsafe and target-contract bound

Converting a pointer to an integer or an integer to a pointer requires unsafe context and a declared target operation. Pointer-to-integer conversion exposes a target address representation. Integer-to-pointer conversion does not invent usable provenance unless the target operation explicitly associates the address with a declared region. A pointer lacking usable provenance cannot be dereferenced.

### OPENC-TARGET-FAULTMODEL-001 — Unsafe precondition violations produce bounded target faults

When an unsafe operation violates a documented precondition, the consequence is one of the target's declared fault outcomes, such as a synchronous trap, operating-system fault, hardware fault, or implementation termination. The target record names the permitted outcomes. No such violation authorizes unrelated arbitrary compiler behavior.

### OPENC-TARGET-NOARBITRARY-001 — Unsafe invalidity does not authorize unrelated compiler invention

The compiler shall not use a possible invalid unsafe operation as unrestricted permission to remove or invent unrelated observable behavior before the fault. Optimizations may rely only on explicit safe rules, proven conditions, or declared unsafe assumptions.

### OPENC-TARGET-SANITIZE-001 — Sanitizing targets may trap earlier

An implementation may add bounds, provenance, alignment, lifetime, and use-after-free checks to unsafe operations and trap before the physical target would fault.

### OPENC-PORTABILITY-PLAIN-001 — Plain OpenC excludes undeclared ABI assumptions

A program that depends on undeclared struct offsets, native serialization layout, hidden calling conventions, or unreported target state is not portable plain OpenC.

### OPENC-TARGET-SCHEMA-001 — Core target records have a minimum portable schema

The minimum target record contains: stable target name, architecture, pointer width, endianness, maximum object size, supported integer widths, alignment for each primitive type, floating formats, and the permitted target-fault outcomes. Implementations may add fields without changing Core meaning.

### OPENC-TARGET-CROSS-001 — Cross-compilation uses target context exclusively

When build host and target differ, source validity, `isize`/`usize`, layout queries, pointer behavior, and fault classification use the declared target record. The host filesystem, ABI, pointer width, or endianness cannot silently substitute.

# Appendix A. Operator precedence

### OPENC-EXPR-PRECEDENCE-001 — Precedence and associativity are fixed by this table

Implementations, formatters, validators, and tutorials shall use the following table, which is normative and mechanically checked against the expression EBNF. Parentheses override the table.

| Rank (highest first) | Forms | Associativity / grouping |
|---:|---|---|
| 1 | postfix call `()`, member `.`, index `[]`, range `[..]` | left-to-right |
| 2 | unary `!`, `~`, unary `+`, unary `-`, address `&`, dereference `*`; `cast`, `cast_unchecked`, `reinterpret`, `construct`, `destroy`, `size_of`, `align_of` | right-to-left for prefix unary; named forms group by parentheses |
| 3 | `*`, `/`, `%` | left-to-right |
| 4 | `+`, `-` | left-to-right |
| 5 | `<<`, `>>` | left-to-right |
| 6 | `<`, `<=`, `>`, `>=` | left-to-right; semantic rules reject invalid chains/types |
| 7 | `==`, `!=` | left-to-right |
| 8 | bitwise `&` | left-to-right |
| 9 | bitwise `^` | left-to-right |
| 10 | bitwise `|` | left-to-right |
| 11 | logical `&&` | left-to-right with short-circuiting |
| 12 | logical `||` | left-to-right with short-circuiting |
| 13 | assignment `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=` | right-to-left |

# Appendix B. Candidate completeness and review boundary

Every active rule in this book has a final CC2 disposition of `keep`, `rewrite`, or `add`. Every retired inherited rule has an explicit successor. All P0 and P1 coherence issues identified by Specification Control CB1 have a candidate resolution in this package.

Remaining gates before OpenC Core 1.0 are external to candidate authoring:

- independent grammar, type-system, security, ownership, and usability review;
- a complete implementation exercising the normative grammar and semantic algorithms;
- execution of the Core conformance corpus;
- maintained real programs;
- resolution of defects exposed by implementation evidence;
- owner ratification of licensing, governance, and release authority.
