# SH-27 1.0.1 qualification

Status: **SH-27 remains open pending final certification and publication**.
The current verification candidate adds early owned compiler-identity hashing:
`7c6f7bbaa5b9ed737a23c5779c560e54e0954d51f8756c412aad7f5ab05d42f5`.
The hash task starts while declarations are collected, touches only its separate
hash buffer, and is joined before identity use or destruction on every return.
All four pool APIs resolve before submission; failed setup uses the existing
serial path. A stable compilation owner retains its 24-byte work record.
Cold preparation is selected from the explicit deferred state, rather than a
hash-buffer length that the worker can change concurrently.

This candidate reaches a byte-exact fixed point, passes 30 native-cache cases
and 28 worker fault variants, and passes all 13 strict stability checks with
20 exact native generations. Strict private/working-set peaks are
240,553,984/58,900,480 bytes. The new identity-launch failure and all four
missing-API cases retain exact output, invalid diagnostics and serial fallback.
Its fresh VS Code 1.144.0 profile and 44/44 finalization audit pass; VSIX hash
is `fe156d1f1b3bb98f9901eb4198f234a990481ee3863af0dc09b5ae61652e63a5`.
Editor/OpenC working-set peaks are 1,633,779,712/5,656,576 bytes.
Hosted source `7faeee5635d5eaf2b4d2d5a6a7acfbfb36fd877f` is being certified.

The predecessor's two hosted production attempts both pass all 20 original
ratios and both scaling suites. Its module repeat fails medium cold:
+9.013 ms against an unchanged 8.960 ms five-percent budget; warm/edit win
11/11. The failure remains in
[attempt 2](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41486598314/attempts/2),
artifact `13166337326`, ZIP SHA-256
`995874e829a9f395bb65bc1f39aba590103faf237671dc7bf05493992e462420`.
It is not replaced with another favorable sample.

The cold encoding, early frontend snapshot, fused declaration projection and
their combinations remain unpromoted after two hosted portfolio batches:
[scheduling](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41498878175)
and [projection](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41500030932).
Every candidate fails the repeated above-null gain requirement. Fusion's
same-source oracle passes exact contribution/projection bytes, but correctness
does not qualify its speed. Those compiler changes have been removed.
The new identity comparison predeclares two repeats of 31 blocks, five
interleaved cold processes per side, against the frozen predecessor and a
same-source serial control. It keeps every observation; normal cold/warm/edit
acceptance and the original 20-ratio contract are unchanged.

The immutable 1.0.0 audit passes again: exact tag, all 15 streamed asset hashes
and the mandatory checksum list. No new public tag or release is authorized.

The preceding compact-update compiler is
`f97d4610573391cb4d8f5d4acd71b38a5a2337462e5992c2568413cb8a06a44d`.
Canonical-source Stage 2/3 reproduces the measured candidate byte for byte.
Both predetermined four-CPU DMD runs now pass all available public ceilings:
large is **1.050x/1.120x**, control **0.694x/0.684x**. Both large results also
meet the unchanged 1.20x engineering target. Local C/Clang/LDC are absent,
so these remain `PARTIAL_COMPARATOR_SET`, not five-tool certificates.
Those constrained-host observations certify that predecessor, not a later binary.

## Normalized checked local updates

Native lowering now resolves a same-cell integer update into one typed IR
operation. It replaces the generic load, constant, binary and store records
for a local value parameter/variable updated by a nonnegative immediate at
most 127. The already-supported pure multiplication-by-one identity can be
normalized before this proof. Resolved symbol/type equality is mandatory;
references, other cells, conversions, pointers, enums and larger/complex
operands retain the old lowering. The compiler's historical allocation-pattern
fault compatibility also retains its old path. C and audit lowering do not
enable this private native operation.

Emission uses the existing signed-overflow/unsigned-carry and narrow-width
checks before committing the cell. An assignment expression still returns
its value; the existing function use counts omit only an unused result's
stack store. No new full-source arena, per-function analysis pass or retained
scratch pool is introduced. Old cache entries cannot bypass the new compiler
identity key.

On the original large corpus, generic IR instructions fall from 105,229 to
31,501, and native code from 1,281,299 to 888,083 bytes. The first balanced
11-pair full candidate gains 52.448 ms in 10/11 pairs against 31.914 ms null.
Its independent 31-pair repeat gains 25.611 ms in 21/31 against 25.151 ms null;
that repeat margin above null is narrow and is not rounded into a larger gain.
Control, many-file and small medians remain within the protected budget.
The 11-pair compiler self-build check also passes: -147.849 ms paired median,
7/11 wins, with exact per-compiler outputs and unchanged 256/64 MiB guards.
The direct-only variant and the always-store-result variant do not qualify
the independent target selection and remain outside production.

All 27 worker faults, 30 native-cache cases, reread retry, frontend publication
and edge cases, module/source caches, overflow COFF, 278 conformance fixtures,
25 ABI checks and the extended internal handoff oracle pass. Strict 20/20
closes exactly with 240,005,120-byte private and 60,207,104-byte working-set
peaks. The maintained integer verifier adds 28 differential cases to its four
existing cases, covering all ten integer widths, both arithmetic boundaries,
assignment results, escaped locals, loops and exact fallback bytes. It builds
a guarded same-source compiler with only the compact policy disabled, and
asserts actual IR removal in eligible cases. Initial fixture mistakes (an
unsupported reference arithmetic expression and the legacy fault's distinct
stderr) remain retained; corrected fixtures compare supported reference
assignment and require the original target-fault text.

The preceding metadata/scratch, output-buffer reuse and four-way dispatch/layout
portfolios failed target selection and remain isolated. A stale freed pointer
in an early output-pool prototype caused heap corruption during its bootstrap;
it was fixed before measurement, and none of that prototype entered production.
Only the normalized update plan is retained from this round.

The fresh VS Code 1.144.0 profile, finalization 44/44, editor 33/33 and contract
38/38 audits pass. The deterministic VSIX is
`1ea0365d710fcb5ce0bc2902270b9c75eb381b526857be2ff00631bd95863cc1`;
profile SHA-256 is `04b29a9444e9202866ca82f153e562bfabcdf3557dc688ada9dd31b501700356`.
VS Code/OpenC working-set peaks are 1,701,007,360/5,750,784 bytes. The native
relocated release audit passes all nine checks. Independent manifests cover
every standalone/source payload and all 230 compiler units. Frozen staged
snapshot `release-input-compact` ZIP pairs hash to
`2cd5dbeaec656e45876543355519d4cfadcdcfdc0a4dbfd579d46766f6060bd9`
(standalone) and `af7b0c28c1fc75d7f921ca59d44392712a4a970e426046b1a660d852c890eb7a`
(source). These precede this evidence paragraph; exact-checkout hosted packaging
is required before release authorization. No public release/tag is published.

| Current report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `compact-repeat/matrix31.json` | `de1f5792be1e34608568b7106066489047ceed4b73ec6034b88769ad50e635dc` |
| `compact-repeat/self-pairs.json` | `534c736b79909a20107253bd084d976867267b54243837c6aeecb55ef1a923be` |
| `compact-dmd20-a.json` | `6fbfbc71c034476508f4e4ddc30787b42ea82c5c5fb2a23a1a7435d8940119ae` |
| `compact-dmd20-b.json` | `5f24cbc9e731d06d1ecc9f1928e40ea41965adf325800d6303d51fbc0f31c56f` |
| `compact-final-workers.json` | `fbd1157ecdb76e4e14505f26fc4db9ed7e88b1eb15db7e07e46297f538b4e876` |
| `compact-final-cache.json` | `0ac1848566a88fc60031eae5b75d73d746bdce6b8a54d9e44e7e3792ec92d252` |
| `compact-final-strict20.json` | `09f79f060b6cfafc2b69fa857c53d2a2962fa6af36f0d82a42a06248ac7cfcbd` |
| `compact-final-coff.json` | `66b4ff71c78f3aabe8c10284a6c72e4fbc0127a311833fd863faa21e17042c69` |
| `compact-final-handoff.json` | `44d2dc45b245b85c034e0d4db825594b6cf9c1a05d9dfbd4cd8f47d824c6bdf7` |
| `compact-integer-final.json` | `153b98a7d7f174b75955a11a3ab50e6224105dba634603ef943a97e6ac9c98ce` |
| `release-compact/native-release-result.json` | `e1b1239eb339d4ffa05e8b863babb2ce8a8a7c0c4c8cfd52f5355cd68bcf4327` |
| `compact-final-archive-manifests.json` | `f1c440b02d0ba867d57ce8426c96f5e4e7ca8735c852aa3cc9c4da7726ffebfc` |
| `native-scratch-portfolio3/matrix11.json` | `6f7e3c32457af1a62fbab4239b5003468905b0fef1d51524f476bcc21b7e3fca` |
| `native-output-portfolio2/matrix11.json` | `b94d12ffd857136bfceb19ea9cd25fe50fa1cf5d906a7b53d2378ccd057f995d` |
| `dispatch-portfolio/matrix11.json` | `9d1c52299a3cea4d1fa633ec7864221a882fe7bbad89788b4fbce98bf8ae43fb` |

The preceding COFF/cache compiler is
`17430ed22c0c79db0c52684604bedf4e715dc7ad1fa3a4caf49d426570e0ea39`.
It passes exact Stage 2/3, all 13 strict stability checks (20 generations),
27 worker faults, 30 ordinary-cache cases, retry/publication/edge recovery,
278 conformance fixtures, 25 ABI checks, module/source cache invalidation,
overflow COFF and fresh editor/finalization/contract audits. The large-function
four-CPU DMD ceiling still fails in both predetermined runs. Hosted proof
must be obtained on this source; preceding-source results do not transfer.

The preceding package-integrity compiler is
`0feaf99c92f07b773b47a9436ae620940b3596a550c0f515787dee699ff8943b`.
It passes guarded exact Stage 2/3, 278 conformance fixtures, 25 ABI checks,
the extended native regression and the fresh editor profile. Final-source
At that preceding checkpoint, hosted certification and constrained-host
throughput remained open.

Release audit findings routed to the project owner:

- **H1 preceding failure, retained:** compiler `17430ed2...` measures 1.261x/1.382x
  large and 0.753x/0.790x control against the same pinned DMD 2.112.0 in the
  two planned 20-observation runs. The original 1.25x ceiling and 1.20x
  engineering target are unchanged. Neither run closes large-function parity.
  Affinity remains 0xf. A topology audit shows those four logical processors
  occupy two physical cores; the worker-policy batch below does not establish
  a qualifying gain, so production policy is unchanged.
- **H1 prior failure, retained:** the predecessor's v3 four-CPU DMD run is 1.295x on
  large functions, above the unchanged 1.25x ceiling. The first predetermined
  run of the integrity compiler is also above that ceiling at 1.274x; the
  predetermined second run is 1.195x. OpenC medians are 281.369/288.274 ms,
  DMD 220.901/241.312 ms. Both results are retained. Neither
  hosted-green results nor a faster opt-in candidate waive this finding.
- **H2, fixed and verified:** native standalone archives
  retained four nested `dub.json` files, and the source archive copied a stale
  `MANIFEST.sha256` with 75 mismatches. The native filter excludes D build
  manifests at every depth; extracted standalone manifest validation enforces
  that rule. Source archives now generate their manifest from the actual
  archive members and verify it after extraction. The absence flag derives
  from validation instead of an unconditional true value. Published v1.0.0
  remains immutable.

The preceding integrity compiler's editor VSIX is deterministic at
`c365bf7f59af5e47acf991a3d6d4e05f3c0bf026a9f6cd4f6b2bbb697f7047f7`.
The new empty-profile report is retained in `review/SH27_WINDOWS_EDITOR_EVIDENCE.json`
at SHA-256 `7885b9da521f74d9f5f06654eb44da7c8ed7bd980a50192cd6e4852dbb070da9`.
VS Code/OpenC working-set peaks are 1,746,329,600/5,656,576 bytes; finalization
44/44, editor 33/33 and contract 38/38 checks pass.

## COFF lifetime and cache-stream successor

Hosted predecessor module run
[41460531058](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41460531058)
failed cold serial compiler COFF at 68,390,912 bytes working set, above
67,108,864. Its medium ordinary-cache cold delta also missed the unchanged
five-percent budget. Production run
[41460531129](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41460531129)
passed, but that does not erase either module/cache failure.

The successor validates selection before copying. A module covering the
whole native stream borrows it read-only; a partial selection owns exactly
its selected bytes plus the buffer sentinel. Both raw and cached COFF
writers release only owned selections. Cold/fresh serial self-host COFF now
passes at 56,578,048/56,291,328 bytes working set, with overflow relocations,
authenticated readback and seeded fixed point intact. Empty, partial, full
and malformed selection probes verify ownership and independent mutation.

Entry-module selection is handed from frozen global declarations to warm
key preparation, cold workers and image publication. Function identity rows
retain their existing little-endian format using four bounded native-word
stores. The compiler-private four-byte reader preserves the portable byte
oracle's exact bounds/error-state behavior and emits one unaligned x64
32-bit load. Differential tests cover 1,480 length/offset/prior-state cases,
empty/null buffers and maximum offset in serial and adaptive builds.

The retained 31-pair ordinary 24-file cold check is within its existing
budget: +8.163 ms against 174.464 ms direct and 10.963 ms null. The reader's
paired candidate gain is below null; it is not credited as a separately
demonstrated end-to-end speedup. Earlier entry-only and identity-only
four-CPU cold checks failed, and remain retained.

Current deterministic VSIX SHA-256 is
`e737d97955826614e0965ada243e083f16d5dd46d346d4e3a1cfdd866875ea42`.
Fresh profile SHA-256 is
`c937c89ddba33f57a2bdf9a46b01272fb721a3a2f19f1ddd4473f22c83ed287c`;
working-set peaks are 1,771,208,704 bytes for the owned VS Code tree and
5,738,496 for OpenC. Finalization 44/44, editor 33/33 and contract 38/38 pass.

The native relocated release audit passes all nine checks on this compiler,
including exact stage closure, both deterministic ZIP pairs, 278 relocated
conformance fixtures and complete daily/CLI/editor workflow checks. Independent
manifest validation covers all 1,532 standalone and 1,901 source payload
entries against the frozen `release-input-word` authored snapshot. Its ZIP
hashes are `db22bce0a6a717b777c14d3e9b34e52ca98781b6c9545c003c1dca4cb3629df4`
(standalone pair) and
`fd1e62298c6e4f52cb6525365823106b0183259ca100ff7ac3c0de6c4f81f9ed`
(source pair). These identify that staged snapshot, preceding this evidence
paragraph; the hosted workflow regenerates archives from its exact checkout.
They are candidate evidence, with no public tag or release publication.

| Current report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `word-final-workers.json` | `996c62a0d8ce466b828b81a4a0fbc7f71afe4fed48761532134a958119c6e91d` |
| `word-final-cache.json` | `6a8be5b6805b8e0a61d47e45265c9007d2338d42ba372024cd5c5a5b6bb4a482` |
| `word-final-retry.json` | `eaa97088eac8c23224641b886d0c5bf4cbac35200068f97e0107b2d438317ccd` |
| `word-final-publication.json` | `448b4681f285fda3a6ef52844e89d406e176e8e7fcaebd3698c376340695caaf` |
| `word-final-edges.json` | `35498bb091ff04cf0edc9e7a8f1a39d8eeae13b0893c919c2111dfd469e77d25` |
| `word-final-strict20.json` | `069dee14ccf35320e8d682197aad80f09d1cec79f2c1a1273f1f6c4cd30dd66b` |
| `word-final-coff.json` | `50aa740024848d960760c1e220e0a6f2ebf90f87399264b92dabd291bb42becf` |
| `word-final-source-cache.json` | `ed9aabaa739c4b3542c01278afbd5ddf767c1e505583ba285e66b2e53554a9b6` |
| `native-word-reader/word-reader2.json` | `30c26aed4e92edae09956e9f0d1b237a4667270458bac3a5ac21e3ceb412782a` |
| `reader-target31/report.json` | `0ad9f1f9bd26cc883ff37f777bb893183068533f896dae791d0427af48f3d63b` |
| `word-dmd20-a.json` | `0840c5f503073ad58a42739873684e4df01f4594c8ebd90d2083b817283e7cc5` |
| `word-dmd20-b.json` | `cb022c286ec04d2f1b9fc0947867924926bdfa8930217ffff06232b6f19fad0d` |

Three additional isolated portfolios remain unpromoted. Four combinations
of native/parser workers yield no above-null target gain. Length/character
keyword dispatch, operator dispatch and their combination also fail. A
bounded SSA-literal comparison emitter, alone and combined with lexer
dispatch, fails its 31-pair target selection. All outputs were exact in the
retained matrices; their `PASS` status means correctness, not speed selection.
The original first literal prototype failed native compilation because it
used an unsupported byte-load spelling; the corrected prototype is the
one measured below. No failed observation was substituted with a retry.

| Unpromoted report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `worker-portfolio/matrix11.json` | `235d8d336294ca0baa1ec15a2d8184e65733dc2ce49e3534e26e5f98eac48817` |
| `lexer-portfolio/matrix11.json` | `abf4a8c5efbb0f03306c19786a38d733705e8172e216338f6dbbe8557a5efad9` |
| `literal-portfolio2/matrix31.json` | `c319234a465345d04c32cd443e1c4ce8138eb2eeefe6918e75aed51cc765b556` |

The following `81787a12...` observations precede the integrity fix and do not
certify its final source.

The 230-source 1.0.1 compiler reaches an exact Stage 2/3 fixed point:
`81787a122301898ce36c0caabe4c7c4a8449cdff8e80f773c63f8bf033549139`.
Only release-version strings changed in compiler code from the previously
certified `1859f47f...` implementation. The project manifest, VSIX and runtime
oracles now agree on 1.0.1; Core/Hosted language editions remain 1.0.

The mixed-project audit exposed a process-start race in the Python evidence
harness: a fast child could finish before Job assignment. Measurement v3
uses `CREATE_SUSPENDED`, assigns the child to its bounded Job, then resumes
the primary thread. It retains the process handle through post-exit peak
accounting. Duplicated output handles use an explicit inheritance allowlist.
The child receives a null input stream; this is a noninteractive audit API.
Assignment/resume failures terminate the suspended child and close its handles.
Seven detecting guard tests cover delayed assignment, both startup failures,
concurrent output, unrelated handle exclusion, and high-water memory limits.
The 256/64 MiB compiler and 512 MiB aggregate limits are unchanged.

This follows the documented Windows
[process-creation flags](https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags),
[Job assignment](https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-assignprocesstojobobject)
and [thread resumption](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-resumethread)
contracts. V2 and v3 timing observations retain distinct labels; old timing
certificates are not relabelled as new measurements.

Current local 1.0.1 checks pass 27 worker fault variants, 30 native-cache
cases, failed-publication cleanup, named-layout/invalid-input replay, strict
20-generation closure, 278 conformance fixtures, 25 ABI checks, large overflow
COFF/seeded bootstrap, and source-partition invalidation. Strict self-build
private/working-set peaks are 240,336,896/60,837,888 bytes.

| Raw report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `v101-workers.json` | `a230a9a40b475cd055377a6f663eba0cef994d19e9779bcba9956839ab23075a` |
| `v101-cache.json` | `195035b2f4a4ebd250eff5dacc69d9519984b2225fce492ce848f9e183e78665` |
| `v101-publication.json` | `5f1410471a567a92f8b59d3972941119bbe01b0bf3ba463118ebdcf9d3ddf523` |
| `v101-strict20.json` | `0942c1f9a53a19dfe104ed7e4279b1de6919fdfc16642873464f8f2079767ae9` |
| `v101-coff3.json` | `0327f548614cbdb79d3633f0151f68667c1301a9d1a8e83cf14f5f7b5ccdfec9` |
| `v101-source-cache.json` | `68c80f345f1f3cdd21572ac88083a411167b21e786264c4b20b376c7b3d2a04f` |

The 1.0.1 editor package is byte-identical across two builds at SHA-256
`d225c5d35c3654c5a662f518ea2acaab145c9aba5f1b6d52af08cc3adf5bd588`.
A fresh VS Code 1.144.0 profile passes installation, packaged-compiler identity,
language-server startup and diagnostics. VS Code/OpenC working-set peaks are
1,712,590,848/5,668,864 bytes. Native finalization 44/44, editor 33/33 and
contract 38/38 checks pass. The published 1.0.0 profile remains preserved in
`review/SH25_WINDOWS_EDITOR_EVIDENCE_V1_0_0.json`.

The preceding compiler's v3 mixed-project proof covers 240 measured builds
and 160 primes across cold/unchanged/edited four-project batches. Warm/edit
concurrency wins 5/5 above null; cold stays within the unchanged budget.
The Job peaks at 268,611,584 private bytes. Twenty-sample four-CPU scaling
measurements cover 64/256/1,024 operations per function and 1/8/24/64 files.
All available DMD ratios pass, but local C/Clang/LDC tools are absent. These
preceding-source observations remain separate from 1.0.1 certification.
CI now reruns both scaling suites on all five tools and the actual retained
four-project batch on the final compiler.

The predecessor's final-source hosted run
[41450479851](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41450479851)
passes all 20 original ratios at 20 samples per cell, the actual negative
parity-CLI proof, and both additional scaling corpora on all five tools.
Large/control OpenC:DMD are 0.512x/0.233x. Its downloaded artifact ZIP is
`7d9514ac74e1ffc42810be4d1b64781359563d4d926622c56ec7877fde7e2cd6`;
raw production JSON is
`7d579e3d409c86d74386d6ced9becd7c4b1551b9d2f1a1d745f9aeacc22eec8f`.

[41450479807](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41450479807)
passes the full module/cache/strict-20 suite and all 400 retained-project
builds. Cold batch overhead is +5.006 ms within 50.602 ms null; warm/edit
paired gains are 27.363/38.462 ms above 3.388/1.623 ms null, with 3/5 and
5/5 wins. Its downloaded ZIP is
`719d7047a93394dd905de2d445b62ea03de08e5471e7f207c36ee88eb93d665b`.
The pinned application proof
[41451611361](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/41451611361)
also passes; its ZIP is
`b98d2b42078f210716db0fbf9a02df7fbc43cbc0f19efd7e4e6a7a533e602d5a`.
The new runner identity uses the same previously reviewed cl/link/DMD hashes.

## Current broad optimization audit: no promotion

All ten isolated fixed-point candidates remain outside production: binary
and cached disjoint-parent ranges; 128/512/2048-node growing IR arenas;
function-context reuse, LEA record addressing and their combined arena variant;
and two scalar load-slot coalescing variants. The latter changes generated
code, passes 278 conformance fixtures on each compiler, and excludes references,
address escapes and cross-block SSA uses. Its independent 31-pair repeat fails:
large +10.556 ms (10/31 wins) against 38.649 ms null; control +0.556 ms
(15/31) against 18.527 ms null. No failed candidate is credited as a speed fix.
The owned-thread sampler now attaches through the v3 guarded process factory,
finishes sampling before handle closure and retains owned-child-only termination.
All eight sampler safety/lookup tests pass.

| Raw report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `v101-large-owned-profile.json` | `1ddf25af5764dfe8b65fea4d46a3e54105df52ce52f0565025c6d52914599f5b` |
| `interval-matrix11.json` | `7f381803ddf68152a9986a46107b1614d2dbbb2a53bf36588a71acc42d0ed78c` |
| `arena-matrix11.json` | `88c6d7f356f4afcfffca01b1ce5d6c9bd7ea68308cd6a6cbe7bf82d14c64e9b5` |
| `owner-matrix11.json` | `524cad71759434ce9789409fb26fc5478d9aba5f8dd0aad2415b60f9ed046c66` |
| `coalesce-matrix11.json` | `deab6b525d526f9f8123a643c41f9b12fabc2284a8102b730c59baa3778e3400` |
| `coalesce-repeat31.json` | `6457cb74285f5a5d5e8272ae83da4ee0ba433a1044a5a741f62ab5189f4d9308` |

The two final-integrity-compiler local comparisons were planned together in
`build-output/z27/integrity-constrained-plan.json`, 20 observations per tool/cell,
affinity 0xf, same DMD 2.112.0 bytes. Other local comparator tools are absent.
All available checks except run A's large ratio pass. These do not replace
full hosted certification, and the mixed verdict does not close H1.

| Report under `build-output/z27/` | Large/control DMD ratios | SHA-256 |
| --- | --- | --- |
| `integrity-dmd20-a.json` | 1.274/0.801 | `a68be593db4c1dd46c378d570446498ba8b282f38e81a45356571d9732bb4e2e` |
| `integrity-dmd20-b.json` | 1.195/0.788 | `93a24fb0adf3d6c896e36f99b66b649b120280d94e0c0f278932d22b0d2004ae` |

## Package-integrity compiler validation

Compiler `0feaf99c...` passes all 13 strict stability checks, including 20/20
byte-identical self-builds under the unchanged 256/64 MiB child limits and an
outer 512 MiB Job. The native release command passes all nine checks, including
both deterministic archive pairs and the newly enforced source manifest.
The independent Python standalone v6 check also passes: 278 conformance,
153 exact diagnostics, 35 runtime fixtures, four maintained programs, CLI 12/12,
project workflow 21/21, LSP 19/19 and semantic LSP 23/23, from a foreign working
directory with no Python/D/C/TinyCC available to native child builds.

The independently verified staged archive snapshot has 1,532 standalone and
1,901 source manifest payload entries, with exact coverage and hashes for every
member. Source members also match the frozen authored inputs. The standalone
pair SHA-256 is `9fb81c0a4f0e92a63bc6c1db792c5500ee2e97f6d16c46d81b16f64bade65047`;
the source pair is `cfb2644cd6826c44095b78b1bc79368664ae76a34a5b8e45b2de7bdc69f1a3c9`.
These identify that staged snapshot; subsequent evidence-document edits do not
retroactively change its content. CI now repeats native packaging and an
independent manifest/authored-input audit on the exact checked-out revision,
on push and manual dispatch, and retains the four ZIPs and raw reports.
Detecting tests reject stale checksums, unlisted members, altered authored
inputs and a nested D manifest with an otherwise valid checksum.

| Current report under `build-output/z27/` | SHA-256 |
| --- | --- |
| `integrity/strict20.json` | `5ebdb5acce65dff3406ab2e90f8cf3a1ffcd1f4afb077ccbba1ce43706095201` |
| `release-integrity/native-release-result.json` | `35a1909390ae2dddb36e29ced50347871968816a4490d40a228b592652a5993c` |
| `standalone-integrity-verified/standalone-release-result.json` | `5f33cd31db29db2e5666682f2efa118824c541cf2495f5f9aae4b2d0b4351197` |
| `integrity/archive-manifests.json` | `cb05baa1ff507b6cb24d17bd116269fab1cdf6d6d30f6a9a0210e10cc0fc22ce` |

At this preceding checkpoint H1 remained open. Package integrity and hosted
predecessor passes did not close SH-27 or authorize a new public release.
