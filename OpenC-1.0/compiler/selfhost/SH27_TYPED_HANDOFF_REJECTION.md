# SH-27 typed lowering handoff: correct, not a throughput cut

Candidate `codex/sh27-lowering-consumption-cut` at `84aad55` starts from
production compiler source `1b58d5e`. It reuses source-lifetime cache slots
that are disjoint by syntax kind: kind-29 literals retain the parsed integer
value; kind-36 binaries retain a single classified operator. The required
type/acceptance visit produces each fact and lowering consumes it. There is no
additional syntax-sized allocation or eager traversal. Missing facts use the
old parse/classification semantics and are counted separately.

Guarded Stage 1/2/3 self-build passed, with Stage 2 and 3 byte-identical.
Stage 3 SHA-256 is
`15bc2dc15a491a179307f53437781d3b768dc9b67a19eabaecea489481f14d1a`.
Stage peaks were at most 255.4 MB child private and 59.9 MB working set,
below the 512 MiB guard. Its self-build timing record shows 18,613 integer
reuse / 120 integer fallback and 15,061 binary reuse / 0 binary fallback.
These count avoided lowerer re-parses/reclassifications, not elapsed time.

The ten-case differential report `build-output/sh27-lowering-consumption/focused-02.json`
passed against the frozen `1b58d5e` Stage 3. It covers signed/unsigned/narrow
integer boundaries and overflow runtime, native scalars, nested aggregates,
invalid shift expressions under both short-circuit forms, a semicolon-only
declaration, and an invalid operator. `check` and `build` diagnostics matched
byte-for-byte. Every accepted case produced an identical PE and matching
runtime exit/output; rejected cases produced no PE. Peak guarded child private
was 20.8 MB, working set 10.0 MB, and Job private 23.3 MB. The invalid
operator case checks diagnostic preservation, not the lowerer's binary-cache
miss path; that path was zero on the measured valid corpus.

The serial 11-pair large/control matrix with baseline-vs-baseline null
controls is `build-output/sh27-lowering-consumption/typed-handoff-matrix-20260924.json`.
All compiles, executions, 512 MiB guards, generated PE bytes, and program
outputs matched. Nevertheless, both throughput lanes failed:

| Workload | Candidate − production paired median | Wins | Null noise floor |
| --- | ---: | ---: | ---: |
| Large functions | −7 ms | 6/11 | 60 ms |
| Control flow | −3 ms | 6/11 | 71 ms |

The matrix peak child private/Job private was 172.2 MB and working set
78.0 MB. Critical-worker phase medians were too coarsely rounded and shifted
in opposite directions between workloads to establish a real reduction:
large critical wall +15 ms, acceptance +16 ms, lowering 0 ms; control
critical wall 0 ms, acceptance −15 ms, lowering +16 ms. These nested/rounded
phases are not additive. The 11-pair whole-wall result is decisive for this
candidate: a large count of mechanically avoided replays did not produce a
gain above measured host noise. Do not promote or spend the full 278-case /
20-generation gate on this isolated cut.

This is not DMD's semantically annotated expression tree. It leaves the
source-wide assignment/binary acceptance traversals, first-visit recursive
type work, and IR lowering walk intact. The next viable architecture must
remove one of those whole traversals or combine validation and lowering in a
single function-local semantic/IR walk while retaining diagnostic-order replay
on error; it must not add another fact cache beside the existing passes.
