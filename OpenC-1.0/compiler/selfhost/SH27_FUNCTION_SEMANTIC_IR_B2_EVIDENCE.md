# SH-27 function semantic IR, Phase B2 isolated evidence

Status: **correctness and synthetic-corpus activation only** on
`codex/sh27-function-semantic-ir`, based on production compiler source
`1b58d5e`. No throughput claim or promotion is made.

The function visitor now covers exact signed `i32`/`i64` arithmetic
(`+`, `-`, `*`, `%`), assignment, and relational/equality conditions. It
accepts literal-only local initializers. A call can be a legacy semantic
leaf only when the linear ownership census proves that no covered
assignment/binary is nested in its arguments; call selection retains the
existing callee-before-argument behavior. The native worker omits the
assignment, binary and condition acceptance sweeps for an eligible source.
Its private bytes cannot merge until every covered node and condition is
visited exactly once with no covered uncached type call. Any invalid rule or
coverage miss destroys the speculative worker state and replays full legacy
validation from the clean serial base. `check` stays on the legacy path.

The guarded Stage 1→3 bootstrap report is the ignored local artifact
`build-output/sh27-function-semantic-ir-phase-b2-bootstrap-02/bootstrap-current/bootstrap-current.json`.
It passed a byte-exact Stage 2/3 compiler fixed point, SHA-256
`c7fa57c9ae8109a80f253fe0a9deba9c45f1cb89e5d1e0a58bdf221e`.
Stage 3 peaked at 257,818,624 private bytes and 60,018,688 working-set
bytes under the bootstrap's 512/512 MiB guard. This is **not** proof of the
strict 64/256 MiB repeated self-build gate.

| Guarded project | Fast sources | Covered assignments | Covered binaries | Conditions | Exact output |
| --- | ---: | ---: | ---: | ---: | --- |
| Generated large functions | 8/8 | 24,832/24,832 | 32,769/32,769 | 1/1 | 1,344,512-byte PE and runtime equal frozen production |
| Generated control flow | 4/4 | 3,904/3,904 | 6,913/6,913 | 1,537/1,537 | 486,912-byte PE and runtime equal frozen production |
| Focused call/loop/if/else/prototype fixture | 2/2 | 5/5 | 9/9 | 3/3 | 6,656-byte PE and runtime equal frozen production |

Every active source above reported zero legacy assignment/binary sweep
visits, zero covered uncached type calls, and zero clean replays. The PE
SHA-256 values were respectively
`81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e`,
`31b8906a62a954d885b37fe8a03a94010eefaa619648f42626620ca455590e50`,
and
`49a718408436d30d188910ea7dc05b67fb66d0d565210d8eac5a0d1056756109`.
Each generated program exited 0 with exact empty stdout/stderr. The
focused fixture includes a semicolon-only function declaration.

Exact negative proof used the versioned fixtures under
`tests/sh27_function_semantic_ir/`: unresolved name in a never-executed
branch, mixed signed/unsigned `%`, mixed signed/unsigned comparison, and an
invalid right side of a short-circuit condition. The first three exercised
clean speculative replay; short-circuit was rejected by preflight and took
the legacy path. For each, candidate and frozen-production exit code,
stdout, stderr and diagnostic category/span/order matched byte-for-byte;
no PE was written. Valid and invalid `check` commands likewise matched
exactly. All focused compiles/checks ran under 64 MiB working-set and
256 MiB private-process guards.

The compiler self-build is **0/223 fast sources**: 218 sources reject at
their first unsupported expression kind, three contain no covered work,
and two fail the conservative ownership grammar. Thus this cut cannot
improve the compiler self-build critical path. One unpaired control sample
was flat at 172 ms whole-wall despite the omitted expression sweep; its
critical worker increased from 125 to 141 ms and the pointer-acceptance
bucket shifted upward. That sample is diagnostic only, not a speed result.
`acceptance_validate_pointer_order` still scans all syntax nodes and
performs name resolution for relational expressions; this is a concrete
next first-visit/migration investigation, with counters needed before any
claim that work disappeared.

Next gates: categorize the 218 self-build expression rejections, run an
adjacent 11-pair large/control candidate-vs-baseline matrix with a
baseline-vs-baseline null as **triage only**, then decide whether the
function-scoped design is worth extending. Do not promote without a
strict 20-generation 64/256 MiB self-build, full conformance/diagnostic
coverage, substantial real-project/self-build activation, and whole-wall
gain above noise on every protected lane. All paths above are local ignored
artifacts unless separately published.
