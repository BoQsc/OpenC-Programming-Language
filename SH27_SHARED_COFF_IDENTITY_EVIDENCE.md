# SH-27 shared COFF identity preparation

Status: **local fixed-point, exact-output, 11-pair speed, conformance and
strict RAM PASS; clean hosted repeat pending; SH-27 active**.

The opt-in source-partition writers previously called
`coff_stable_prepare` for every native object. That re-read and parsed the
same 228 source files and recomputed every stable function identity up to
32 times in one build. The two partition writers now prepare the identity
table once per complete object set and lend a read-only buffer view to each
COFF encoder. The ordinary single-object API retains its original wrapper.
The native COFF bytes and linked PE are unchanged for identical source.

The current compiler reached a byte-exact Stage 1/2/3 fixed point at
`08f08ee45fa0a46411224c0fff6ae2a9adf5ec25e6fdaf6c63ae8bf739d41476`.
The prior snapshot compiler SHA is
`5ee5588523253df035b2e6263bc9266570af3f95dd7a5634c3fd4bb492dff671`.
The paired test's 228-source project input SHA is
`80097077b5e215379223d060ad9ea486143650492edb27ed3694886f5a95af39`.

The guarded, order-alternated **11-pair** cold 32-object comparison built
the same current source with both compilers, without cache. All 11 pairs
produced byte-identical COFF objects and linked PE, and all 11 favored the
shared-identity compiler. Baseline/candidate median wall times were
31.382/16.794 s (1.869x); the paired median saving was 14.629 s. The
lowering/emission phase median fell from 24,984 to 10,502 ms while the
validation phase stayed approximately 5.7 s. Maximum sampled baseline
private/working set was 176,689,152/54,444,032 bytes; candidate maximum
was 173,027,328/55,672,832 bytes. Both obeyed 256/64 MiB child caps.
The ignored raw report is
`OpenC-1.0/build-output/sp27-stable-once/final/identity-pairs11.json`.

The complete 32-object cache proof also passed on the candidate: cold
0/32 in 7.865 s, exact warm 32/32 with validation skipped in 0.449 s,
one-body edit 31/32 in 4.111 s, exact fresh rebuild in 16.888 s, and
public-interface edit 0/32 in 6.156 s. Corrupt-object recovery and exact
invalid-source diagnostics passed. The 2/8/32 uncached COFF proof passed
with 1,673 functions and a linked compiler fixed point; the existing
per-module cache and large-COFF overflow/relink proofs also passed.
The 20-generation strict chain passed 13/13 checks, with maximum sampled
child private/working set of 247,422,976/65,126,400 bytes. Native
conformance passed 278/278 fixtures.

This removes a repeated full-project parse from the **opt-in COFF path**.
It does not speed the ordinary direct PE default, make an edited build
revalidate only changed functions, or certify the final 20-ratio C/D matrix.
The changed-source path still spends about 1.3-1.7 s on full-project
validation locally, and direct compiler self-build remains faster than the
opt-in edited path on this host. Next: repeat this exact source on clean
Windows, then target selective semantic acceptance and bounded native link
overhead before any default-policy decision.
