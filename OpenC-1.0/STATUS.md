# OpenC canonical mainline status

```text
version:                            1.0.0
canonical development tree:         YES
release scope:                      WINDOWS X86-64 HOSTED

Core specification:                 1.0 FINAL AUTHORITY
Hosted specification:               1.0 FINAL AUTHORITY
Linux/freestanding/Native sources:   EXPERIMENTAL; OUT OF 1.0 SUPPORT SCOPE

canonical OpenC compiler source:     221 `.p` UNITS; SELF-HOSTED
legacy D reference source:           OPTIONAL AUDIT; NOT AUTHORITY
legacy Python bootstrap source:      OPTIONAL AUDIT; NOT AUTHORITY
official OpenC source extension:      .p; 281 MIGRATED, 547 TOTAL `.p` SOURCES
compiler-in-OpenC lexer:              SH-2A/SH-2B PASS; 304/304 EXACT PARITY
compiler-in-OpenC parser:             SH-2C PASS; 303/303 EXACT PARITY
project/module frontend:              SH-2D PASS; 22/22 EXACT PARITY
full syntactic/project frontend:      SH-2 PASS
declaration/symbol/type tables:       SH-3A PASS; 17/17 EXACT PARITY
name/constant/overload resolution:    SH-3B PASS; 10/10 EXACT PARITY
flow/safety semantics:                SH-3C PASS; RC9 CURRENT 240 COMPARISONS
semantic outcomes/canonical IR:       SH-3D PASS; RC9 153 REJECT + 123 IR MATCHES
full semantic/IR pipeline:            SH-3 PASS; 33/33 REACHABLE IR OPCODES
bootstrap D-source backend:           SH-4A PASS; 4 PROJECTS, 28/28 FILES EXACT
stage-1 self-compilation:             SH-4B PASS; STAGE 1 BUILDS STAGE 2
bootstrap closure:                    SH-4C PASS; STAGE 2/STAGE 3 STABILIZED
self-hosted compiler:                 YES; SH-25 PASS, DIRECT X64/PE32+/COFF FIXED POINT
trusted native rebuild:               PASS; 20/20 BYTE-IDENTICAL
public compiler throughput:           C/D-CLASS; SH-20 PASS
public validating self-build:         12.843 S MEDIAN; VALIDATION 6.282 S
coverage-granularity milestone:      PASS; 466/466 RULES, 174/174 GRAMMAR PAIRS
native validation budget:            PASS; 76.081-233.841 S <= 300 S, 278/278
native self-rebuild budget:          PASS; 9.965-14.502 S <= 30 S, BYTE-IDENTICAL
unchanged daily conformance:         PASS; 0.002 S, 0 FIXTURES RE-EXECUTED
public native CLI:                    SH-9 PASS; CHECK/RUN/VERSION/TARGET/EXPLAIN
native project workflow:              SH-10 PASS; FMT/INFO/TEST, 21/21
native language service:              SH-11 PASS; LIFECYCLE/DIAGNOSTICS/FMT, 19/19
native semantic language service:     SH-12 PASS; SYMBOLS/NAV/COMPLETE/RENAME, 23/23
human + machine diagnostics:          PASS; `openc.check.v1` + STABLE STREAMS
completed engineering milestone:     SH-26 OWNER-AUTHORIZED 1.0 PUBLICATION
next engineering milestone:          SH-27 POST-RELEASE INTEGRITY/PRODUCTION PERFORMANCE
SH-25 finalization audit:             PASS; 44/44
SH-25 deterministic VSIX:             PASS; 9 ENTRIES, 081ff8dd, BYTE-EXACT PAIR
SH-25 clean-profile editor:           PASS; VSCODE 1.137.0, ACTIVATE/SERVER/DIAGNOSTICS
SH-25 editor/OpenC RAM guards:        PASS; 1,495,654,400 / 9,289,728 BYTES
SH-25 independent review intake:      5 TRACKS OPEN; 0 RECEIVED; NONE CLAIMED
SH-25 current fixed point:            eadbef1f; 7,119,360 BYTES; 278/278
SH-25 complete workflow:              PASS; NATIVE DAILY 14/14, FULL 19/19
SH-25 contract/repository audits:     PASS; 38/38, 507 FILES, 39 HASHES
SH-25 native benchmark:               PASS; 20/20; 12.843 S BUILD, 6.282 S VALIDATE
SH-25 compiler RAM guards:            PASS; 175,710,208 PRIVATE / 60,731,392 WORKING SET
SH-25 artifact-tool RAM guard:        PASS; 96 MiB DISTINCT FROM 64 MiB COMPILER GATE
SH-25 native release:                 PASS; BYTE-EXACT ZIPS + RELOCATED FINALIZATION
SH-26 GitHub workflow:                PASS; RUN 34770148453
SH-26 final tag/release:               v1.0.0; d0f77f6; PUBLISHED
SH-26 public assets:                   PASS; 15/15 STREAM-DOWNLOADED + SHA-256 EXACT
SH-27 public integrity baseline:       PASS; 15/15, 48,681,989 BYTES
SH-27 production C/D corpus:           CLEAN WINDOWS PASS; RUN 35797651687
SH-27 runtime file/allocation corpus:  CLEAN OPENC/MSVC/CLANG/DMD PASS; ALL <=1.25x
SH-27 control-flow compile parity:     PASS MSVC 1.044x / CLANG 0.950x; DMD OPEN 2.806x
SH-27 pointer-free validation scan:    FIXED; 13.138 S -> 0.000 S
SH-27 indexed acceptance scans:        FIXED; 6.78 S -> ABOUT 0.12 S
SH-27 candidate-free flow scans:       FIXED; FOUR GROUPS -> 0.000 S
SH-27 stateless-source flow parse:      FIXED; 7/8 SOURCES SKIP REPARSE
SH-27 prefix-type resolution scan:      FIXED; 0.70 S -> ABOUT 0.27 S
SH-27 lowering source reparse:          FIXED; 0.27 S -> 0.000 S
SH-27 resolution source reparse:        FIXED; ABOUT 0.28 S -> 0.000 S
SH-27 flow-validation source reparse:   FIXED; 0.031 S -> 0.000 S
SH-27 flow feature discovery:           FIXED; 7-10 SOURCE SCANS -> 1
SH-27 absent expression scans:          FIXED; CANDIDATE-GATED
SH-27 ordered IR sort:                  FIXED; IDENTITY FAST PATH
SH-27 call-free constant pools:         FIXED; BOUNDED BY IR LITERAL SPANS
SH-27 duplicate-function search:        FIXED; QUADRATIC -> INDEXED BUCKETS
SH-27 native binary copying:            FIXED; CHECKED BULK COPY
SH-27 per-function unwind arenas:       FIXED; DIRECT SINGLE-OP ENCODING
SH-27 retained parser copying:          FIXED; FIVE-WORD LOOPS -> BULK COPY
SH-27 call-free native scratch:         FIXED; IR-BOUNDED CODE/RELOCATIONS
SH-27 non-cast relocation scratch:      FIXED; FOUR-EDGE IR BOUND
SH-27 source-text cache:                FIXED; 10 MIB -> 640 KIB
SH-27 path-join cache:                  FIXED; 3 MIB -> 768 KIB
SH-27 transition bootstrap:             FIXED; STAGE 2 == STAGE 3
SH-27 parser token dispatch:            FIXED; TWO CALL LAYERS REMOVED
SH-27 native byte emitter:              CLEAN PAIRED 10 WINS/1 TIE; -12 MS MEDIAN
SH-27 four-byte x64 field emission:     LOCAL FIXED POINT/278 PASS; -59 MS LARGE, -11/-27 MS CONTROL
SH-27 benchmark disk headroom:          256 MIB FLOOR; FREE BYTES RECORDED
SH-27 large Clang parity:               PRIOR CLEAN PASS; RUN 35803835781, 0.862x
SH-27 large-corpus scaling:             OPEN; PRIOR RUN 35797651687: 0.890/0.498/0.313 S OPENC/MSVC/DMD
SH-27 latest five-comparator run:       35814722551 PASS; EVIDENCE_COMPLETE_DEFICIT
SH-27 adaptive native workers:          CLEAN RUN 35831483331 PASS; OPT-IN, PARITY OPEN
SH-27 parallel flow validation:         CLEAN RUN 35837859544 PASS; OPT-IN, PARITY OPEN
SH-27 pre-flow paired self-build:        LOCAL 11/11 WINS; -2.601 S PAIRED MEDIAN
SH-27 pre-flow large functions:         LOCAL 6/11 WINS; NON-REGRESSION ONLY
SH-24 complete workflow:              PASS; NATIVE DAILY 11/11, FULL 16/16
SH-24 editor resilience audit:        PASS; 33/33, 12 + 12 DETERMINISTIC FRAMES
SH-24 contract audit:                 PASS; 36/36
SH-24 repository audit:               PASS; 495 FILES, 39 HASHES, FULL COVERAGE
SH-24 native benchmark:               PASS; 20/20, 11.765 S BUILD, 6.023 S VALIDATE
SH-24 current fixed point:            d7bf359a; 5/5 PROGRAMS, 278/278
SH-22 complete workflow:              PASS; NATIVE DAILY 9/9, FULL 14/14
SH-22 PE/COFF ecosystem audit:        PASS; 40/40, LOAD-TIME + RUN-TIME DLL CALLS
SH-22 contract audit:                 PASS; 31/31
SH-22 repository audit:               PASS; 475 FILES, 39 HASHES, FULL COVERAGE
SH-22 native benchmark:               PASS; 20/20, 11.406 S BUILD, 5.677 S VALIDATE
SH-22 current fixed point:            bd86520d; 5/5 PROGRAMS, 278/278
SH-22 native release:                 PASS; BYTE-EXACT ZIP PAIRS + RELOCATED CLOSURE
SH-21 complete workflow:              PASS; NATIVE DAILY 8/8, FULL 13/13
SH-21 process supervision:            PASS; OUTPUT/RAM/WORKING-SET/TIME 4/4
SH-21 repository audit:               PASS; 380 FILES, 39 HASHES, FULL COVERAGE
SH-21 native PE audit:                PASS; 16/16, 30 IMPORTS, NO CRT
SH-21 native LSP audit:               PASS; 42/42, FRAMED + DETERMINISTIC
SH-21 native benchmark:               PASS; 20/20, 23.094 S BUILD, 14.827 S VALIDATE
SH-21 current fixed point:            7eea1c05; 5/5 PROGRAMS, 278/278
SH-21 native release:                 PASS; BYTE-EXACT ZIP PAIRS + RELOCATED CLOSURE
SH-14 stability/scaling gate:         20/20 CLOSURE; WORST DOUBLING 2.112x
SH-15 ABI/encoder verification:       PASS; 25/25 EXECUTABLE + STATIC CHECKS
SH-16 PE/runtime verification:        PASS; 34/34, KERNEL32-ONLY, NO MICROSOFT CRT
SH-17 WinMD projection verification: PASS; 30/30, 7 MODULES, 71,425 RECORDS
SH-18 friendly Windows verification: PASS; 27/27, 12 MODULES; 10.103 S REBUILD MEDIAN
SH-19 native backend verification:   PASS; 63/63 SCALARS, 6/6 MEMORY, 20/20 RELEASE
SH-20 public throughput verification: PASS; OPENC 17.064 S, C 22.732 S, D 17.504 S
COM/IUnknown/WinRT projections:       SH-23 PASS; 33/33 NATIVE ABI CHECKS
first-party editor client:            PASS; VSCODE, INCREMENTAL/CANCEL/WORKSPACE/RECOVERY
active critical path:                 SH-27 PRODUCTION C/D PERFORMANCE EXPANSION
DMD/TinyCC-independent compiler:     YES; PUBLIC `openc build`, DIRECT PE32+
standalone compiler distribution:    YES; NO C/TCC/D/PYTHON/ASM/LINKER
normal compilation independent:      YES; PYTHON IS OPTIONAL EVIDENCE ONLY
runtime and Hosted library source:   SOURCE-COMPLETE; WINDOWS EXECUTED
first-party tool source:             SOURCE-COMPLETE; BUILT AND TESTED
build/test/release source:           SOURCE-COMPLETE; EXECUTED

legacy D audit targets:              9/9 DEBUG; 9/9 RELEASE ON WINDOWS
external evidence tests:            8/8 D AUDITS; 42/42 PYTHON TESTS
conformance fixtures:                NATIVE 278/278 PASS; 0 INFRASTRUCTURE FAILURES
diagnostic matching:                 EXACT CURRENT; PRIOR 93 COMPATIBILITY DISCLOSED
runtime fixtures:                    35/35 BUILT AND EXECUTED
maintained/runtime programs:         5/5 CHECKED, BUILT, AND RUN
active rules with dedicated fixture: 466/466
dedicated-fixture backlog:           0
dedicated grammar-production pairs: 174/174 ACCEPTING + REJECTING

Windows behavior verified:           YES, WITH LOCAL RECORDED TOOLCHAIN
Windows Hosted C providers compiled: YES; SH-5 TINYCC BUILD AND EXECUTION PASS
Linux/freestanding verified:         NO; OPTIONAL FUTURE TARGETS
independent third-party review:       NOT PERFORMED; RECOMMENDED/NONBLOCKING
maintainer release review:            PASS; NO OPEN P0/P1 FINDINGS

licensing/governance:                HD-012 RATIFIED
software license:                    0BSD
specification/docs/assets:           CC0-1.0
vendored TinyCC audit component:     OPTIONAL; LGPL-2.1 + BUNDLED TERMS
release authority:                   OPENC PROJECT OWNER
formal release ready:                YES FOR DECLARED WINDOWS HOSTED SCOPE
final 1.0 authorization:             AUTHORIZED 2026-09-13T16:29:48Z
final public release tag:            v1.0.0 -> d0f77f6268154ac06f4206c01cd349b226b53c1b
latest published release:            v1.0.0; 15/15 ASSETS VERIFIED
published/released final 1.0:         YES; 2026-09-13T17:08:01Z
```

`RELEASE_READY` means the declared local gates pass. Owner authorization,
immutable source tagging, and release-asset publication are distinct actions.
This does not imply independent certification or verification on targets
outside the declared scope.

The RC8 and RC9 tags remain immutable historical release-candidate records.
The final 278-fixture OpenC 1.0 release is published at
`https://github.com/BoQsc/OpenC-Programming-Language/releases/tag/v1.0.0`.

SH-8 makes the OpenC-native compiler the default Windows Hosted
compiler-under-test, enforces measured validation/rebuild budgets, and skips
unchanged daily corpus work using an exact-input cache. Full and release gates
force fresh native evidence. The retained D seed is only available through the
separate optional audit command. SH-9 adds public native `check`/`run`,
human diagnostics with stable machine records, version/target/rule
explanation, and direct CLI execution of all six demos. SH-10 adds the native
formatter, project inspection, and deterministic test workflows, with all 21
contracts in the relocated standalone gate. SH-11 adds native
`openc lsp --stdio` lifecycle, full-document synchronization, stable rule-ID
diagnostics, SH-10 formatting, and deterministic transcripts, with all 19
contracts in the relocated standalone gate. SH-12 adds a bounded synchronized
project workspace, native symbols, typed hover, definition/references,
name-sorted completion, collision-checked rename, and 23/23 deterministic
project-semantic contracts. SH-13 addresses native build throughput, canonical
OpenC-only implementation authority, and removal of D/Python source from the
standalone compiler. SH-14 then reduces the five-run clean median from the
500.311-second SH-13 monitored baseline to 4.137 seconds and passes every
D-relative, small/incremental, scaling, memory, correctness, deterministic
closure, and 20-run stability gate. SH-15 then adds the OpenC-authored
Microsoft x64 ABI/LLP64 classifier, typed machine-code encoder, relocations,
version-one unwind records, and 25/25 executable/static probes. SH-16 adds the
deterministic PE32+ writer and a CRT-free runtime proof with imports,
relocations, TLS, unwind data, UTF-8 command-line conversion, process-heap
allocation, file I/O, cleanup, and 34/34 verification checks while retaining
the throughput budgets. SH-17 then parses the real pinned Win32 Metadata image
in OpenC and reproducibly generates seven raw modules with 71,425 records and
30/30 checks. SH-18 adds twelve friendly Windows modules and passes 27/27
checks. SH-19 then replaces generated C and TinyCC in the normal compiler path
with OpenC-owned x64 lowering and deterministic PE32+ emission. Its standalone
release passes 20/20 checks, 278/278 conformance, and byte-identical compiler
closure without C, TinyCC, D, Python, an assembler, an external linker, or a
Microsoft CRT. SH-20 then reduces the fully validating public self-build to a
17.064-second five-run median, with an 11.352-second validation median, while
20/20 chained builds close exactly under the 256 MiB private / 64 MiB
working-set guards. That is faster than the measured 22.732-second optimized
ISO C reference and 17.504-second D reference medians. SH-21 is complete: its
130-source fixed-point compiler owns the 13/13 full workflow, 278/278
conformance, 5/5 program checks, bounded child supervision, 380-file repository
audit, 16/16 native PE audit, 42/42 framed LSP audit, 29/29 residual contracts,
and deterministic relocated release archives. SH-22 then completes the
OpenC-owned Windows PE/COFF ecosystem: AMD64 objects, DLL imports and exports,
static and import libraries, manifests and resources, console/GUI subsystem
selection, and both load-time and secure run-time C-ABI DLL calls. Its
217-source fixed-point compiler passes the 40/40 PE/COFF audit, 31/31 public
contract audit, 475-file repository audit, 278/278 conformance, and 20/20
exact rebuild chain. The measured medians are 11.406 seconds total and 5.677
seconds validation, with 170,627,072 private bytes and 57,749,504 working-set
bytes at peak. D/Python/C/TinyCC/assemblers/external linkers remain absent
from the required compiler, artifact, workflow, and release paths.
SH-23 completes optional COM and WinRT projections. Its 219-source compiler
passes 33/33 real ABI/runtime checks, including `IUnknown`, HSTRING,
runtime-instance activation, and `IInspectable`, plus the 15/15 full workflow
and deterministic relocated release. SH-24 completes the dependency-free
first-party VS Code client, incremental monotonic synchronization,
cancellation, workspace lifecycle, bounded recovery, and 33/33 deterministic
editor audit. Its 220-source compiler passes the 16/16 workflow and 20/20
closure at `d7bf359a…c186`. SH-25 then freezes the final `1.0.0` identity,
adds OpenC-native deterministic VSIX packaging and a 44/44 finalization audit,
and passes a real clean-profile VS Code activation/server/diagnostic run under
separate editor and OpenC memory guards. SH-26 then records owner authorization,
the exact annotated tag, the successful GitHub workflow, and 15/15 remotely
verified final assets. External review remains openly invited and honestly
unclaimed. SH-27 now owns public-artifact monitoring and broader production
MSVC/Clang/DMD performance work. Clean Windows runs through 34810131926 rebuild
checked-out source twice under RAM guards, prove exact fixed points, and pass
every compiler-version, correctness, execution, output, and memory check.
Semantic pointer gating first removed the 13.138-second pointer-arithmetic
scan. Indexed expression, block, call, control, and return traversal then
reduced expression acceptance to about 0.12 seconds. Project/source candidate
gates now reduce pointer facts, unsafe primitives, scope actions, and unsafe
calls to 0 milliseconds when absent. A conservative whole-source flow gate now
skips syntax construction for seven of eight stateless large-corpus sources.
Bounded prefix-type lookup then reduces large resolution from 703–718
milliseconds to 265–282 milliseconds without adding allocation. Exact parsed
source reuse then removes lowering's 0.27-second reparse and reduces its phase
to 501–531 milliseconds. Moving cache creation into declaration collection
then eliminates resolution parsing and reduces the 2,048-function median to
0.931 seconds, 96.4% below the original 25.983-second baseline. Small and
24-file OpenC builds pass the target against every comparator. Flow validation
then reuses the same parsed-source cache and records 0 milliseconds of parsing
in all clean large samples. Host-wide variance moves that run's absolute large
median to 1.305 seconds, but the same-run ratio reaches 1.235x Clang and passes
that gate. Large MSVC and DMD64 parity remain open at 2.453x and 3.850x;
the next run replaces seven to ten feature searches with one source pass,
reduces flow to 31–47 milliseconds, and reaches a new 0.805-second large
median. Comparator variance leaves latest large ratios open at 1.949x MSVC,
1.342x Clang, and 3.073x DMD64, so the earlier Clang pass is not treated as
sustained. Remaining acceptance, indexing, IR lowering, and native emission
are next. Candidate-gated expression families, an identity fast path for
already ordered IR, and IR-bounded call-free constant pools then preserve exact
closure and all guards. Two consecutive large OpenC/Clang ratios passed at
1.218x and 1.213x before the latest shared-runner observation moved to 1.302x,
so that gate remained intermittent. Indexed duplicate-function validation then
removes its quadratic all-functions comparison, reduces clean acceptance to
187–204 milliseconds, and restores a comfortable 1.120x Clang pass. Latest
MSVC and DMD64 ratios remain open at 2.360x and 3.736x; the many-file DMD64
ratio is narrowly open at 1.255x.
Checked bulk copying then removes per-byte function-call loops from native
function assembly, linking, and PE construction. The clean large median reaches
1.045 seconds and beats Clang at 0.991x; every small and many-file gate now
passes. Large MSVC and DMD64 remain open at 2.053x and 3.339x.
Direct encoding of the single stack-allocation unwind record then removes two
heap allocations per function and reaches a 0.869-second clean large median.
Large Clang passes at 1.060x; MSVC and DMD64 remain open at 1.735x and 2.776x.
Bulk transfer of retained token and syntax records then replaces field-by-field
five-word copy loops while preserving the exact-size cache and its memory bound.
Local paired builds reduce the declaration median from 344 to 328 milliseconds.
Clean run 34787810925 proves compiler fixed point and all correctness, execution,
output, and memory checks; host variance places the large median at 1.096 seconds
and same-run ratios at 2.162x MSVC, 1.148x Clang, and 3.502x DMD64. Small builds
beat all comparators, and the 24-file lane passes at 0.528x MSVC, 0.220x Clang,
and 1.201x DMD64. Large MSVC/DMD and broad C/D parity remain open.
Call-free, scope-free native functions now reserve code and relocation scratch
from audited IR bounds instead of the general runtime-intrinsic allowance.
Seven paired local large-corpus builds reduce the total median from 1.500 to
1.453 seconds and lowering/emission from 643 to 595 milliseconds with exact
output and effectively unchanged peak memory. Clean run 34809511246 proves the
7,173,632-byte `7cc72649...4472501f` fixed point and every workflow guard. Its
large median is 1.091 seconds: 2.118x MSVC, 1.117x Clang, and 3.209x DMD64.
Small and 24-file builds remain within the 1.25x gate against every comparator;
large MSVC/DMD and broad C/D parity remain open.
The relocation reserve then distinguishes ordinary call-free instructions from
the exceptional six-edge cast path. Eleven order-alternated local pairs give
the candidate 8 wins, 1 tie, and 2 losses, a -78 millisecond median paired
delta, and a 234-to-219-millisecond native-emission median with exact output.
Clean run 34810131926 proves the 7,174,144-byte
`eeecf5dd...4b350901` fixed point and records a 1.075-second large median:
2.125x MSVC, 1.116x Clang, and 3.446x DMD64. Large MSVC/DMD remain open.
The enum validator now uses the existing top-level symbol index to skip its
full syntax pass for enum-free sources, while retaining exact enum and
non-indexed paths. Local paired evidence reduces its containing group from 31
to 16 milliseconds and acceptance from 282 to 269 milliseconds. Clean run
34811322028 proves the 7,175,680-byte `53394df7...dbde83e6` fixed point and
passes every guard. The large median is 1.058 seconds: 2.058x MSVC, 0.999x
Clang, and 3.094x DMD64. Expression acceptance and combined native
lowering/emission are next; large MSVC/DMD and broad parity remain open.
Plain-name assignment validation now resolves its destination once, and
variable-left binary type inference/lowering no longer evaluates an unused
right integer literal. Local paired evidence records -14 milliseconds for
expression acceptance, -31 milliseconds for IR lowering, and exact output.
Clean run 34835402812 proves the 7,178,240-byte
`d681b6fd...74ba3cee` fixed point and reaches a 1.014-second large median:
2.016x MSVC, 0.992x Clang, and 3.130x DMD64. Every small/many-file and large
Clang gate passes; large MSVC/DMD and broad parity remain open.
The explicitly initialized source-text cache is now bounded from 10 MiB to
640 KiB. Removing its clear was rejected by run 34839072231 when the stronger
bootstrap check exposed a generation transition; the harness now permits that
transition and requires byte-exact stage-two/stage-three closure. Run
34863528233 passes at `0787d816...32059`. Eleven local alternating pairs
preserve exact output while reducing private bytes by 9,748,480 and working
set by 9,830,400 in every pair. The collision-safe path-join cache then falls
from 3 MiB to 768 KiB. Eleven more pairs give 8 wins, a -31-millisecond paired
total, and another 2,355,200 private / 2,363,392 working-set byte reduction.
Clean run 34864294052 proves the `6c1baf87...d87e9` fixed point and every guard.
Its large median is 1.056 seconds: 2.112x MSVC, 1.099x Clang, and 3.280x DMD64.
Temporary profiling identifies parsing itself as the next declaration target;
large MSVC/DMD and broad parity remain open.
Parser token access now reads packed-record fields directly instead of routing
through a generic wrapper, and token matching reads its start/length once.
Eleven alternating local pairs reduce declarations by 94 milliseconds in all
11 pairs and total time by 109 milliseconds with 10 wins. Direct match/check
dispatch then removes another two parser call layers; eleven more pairs reduce
declarations by 31 milliseconds and total time by 47 milliseconds. Both retain
the exact `54fe73ad...90746b` output, effectively flat memory, three-stage exact
closure, structure, and 278/278 conformance. A direct cursor-advance candidate
with no targeted improvement is discarded. Clean run 34866286255 proves the
`ec395588...e73a0` fixed point and every guard. Its large median is 1.002
seconds: 1.942x MSVC, 1.018x Clang, and 3.074x DMD64. Declarations fall to a
188-millisecond median; native emission is now the largest measured subphase.
Integer literals that fit the signed parser range now enter IR as numeric
immediates, and the native backend emits those bits directly; larger unsigned
and negative literal paths retain their prior parsing behavior. Eleven
order-alternated local pairs show a 46-millisecond median paired total gain
(9 wins, 1 tie), with exact large-corpus output and effectively flat RAM.
The 7,179,776-byte stage-two/stage-three compiler is byte identical at
`ebf1c4f4...fddcd45`; 278/278 conformance fixtures pass. A new executable
probe covers signed/unsigned limits, decimal separators, binary/hex radix,
negative literals, and enums; its PE bytes match the previous compiler and
both binaries exit successfully. Clean Windows run 35774378673 passes every
correctness, version, execution, bootstrap, and RAM guard. Its large OpenC/
MSVC/Clang/DMD medians are 0.914/0.509/1.027/0.324 seconds: 1.796x MSVC,
0.890x Clang, and 2.821x DMD. Every small and many-file gate passes. The
clean trace now measures 265 milliseconds validation (186 acceptance, 79
flow), 125 IR lowering, and 141 native emission; expression acceptance is
the next measured target. Large MSVC/DMD and broad parity remain open.
Assignment validation is now separately reported in the normal throughput
trace, adding only one clock boundary per source. It accounts for about
172–188 milliseconds of the 219-millisecond local expression group on the
large corpus. Five plausible short paths were rejected when paired tests
showed no total gain or a regression. The name hash now reduces its modulus
once per four bytes rather than once per byte while preserving the exact
polynomial hash, including the empty-name seed edge. A 6,425-case arithmetic
equivalence check passes; 21 alternating local build pairs for the exact final
revision keep output and RAM unchanged while improving the paired compiler-
owned total by 16 milliseconds, assignment validation by 3 milliseconds,
and wall time by 5 milliseconds. The stage-two/stage-three compiler is byte
identical at `3dc01bc0...480067`, and native conformance remains 278/278.
Clean Windows run 35782427590 passes every correctness, version, execution,
bootstrap, and RAM guard. Its large OpenC/MSVC/Clang/DMD medians are
0.747/0.409/0.847/0.251 seconds: 1.826x MSVC, 0.882x Clang, and 2.976x
DMD. Small and many-file gates pass. Assignment validation is 93 of 108
milliseconds in clean expression acceptance. Large MSVC/DMD and broad
parity remain open; lower absolute time alone does not prove relative gain
because the comparators also sped up on this runner.
Linux, freestanding, and ARM64 remain optional later targets.
