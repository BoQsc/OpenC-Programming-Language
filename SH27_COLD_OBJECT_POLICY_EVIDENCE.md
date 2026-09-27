# SH-27 cold source-partition object cost

Status: **local paired cold-worker gain and focused fixed-point PASS;
final-source hosted RAM/representative proof pending** (2026-09-27).
The source-partition path is still opt-in. This does not certify the normal
compiler's C/D throughput or close SH-27.

The prior selective-semantic cut made one-source edits fast, but a cold
32-object compiler build remained substantially slower than normal direct PE.
A guarded five-pair same-source matrix measured 4.600 s direct PE versus
6.911 s cold cached COFF. Worker wall time accounted for about one second:
the cache's conservative full-rebuild policy forced two native workers while
direct PE used four. The other roughly one second followed worker completion
in object construction, publication, and link.

## Worker policy experiment

With the frozen shared worker type table and per-range output budgets now in
place, cold cache misses can retain four native workers. A bounded,
order-alternated 11-pair comparison against the immediately preceding source
completed with 10/11 exact-output candidate wins: baseline/candidate cold
COFF medians **8.401/7.111 s**, median paired delta **-1.502 s**. Candidate
peak sampled child private/working-set bytes were **226,795,520/58,216,448**,
under 256/64 MiB. Worker-wall medians were 4,047/2,656 ms. A separate
five-pair direct-versus-four-worker COFF run measured 4.380/5.641 s; their
worker-wall medians were 2,000/2,016 ms, leaving about 0.9 s of post-worker
COFF cost. The original baseline before this policy has compiler SHA-256
`e6b4e31c3db74494364f65dbd511b2c10532f5e3d852449e758873cb69603c63`.

The worker-only compiler reached a three-stage byte-exact fixed point at
`edf33c12f7daef65e9b16be857773d18f1da67823ccced4716a70201ab719334`.
Its full source-partition cache suite, strict 20/20 chained self-build,
278/278 conformance, and 2/8/32 COFF/seeded fixed-point tests passed locally.
These checks precede the later uncached-writer change below.

## Object hash cost

CLI validation had restricted uncached source-partition COFF output to one
source worker even though the four-worker backend already supported it. The
uncached four-worker path is now allowed for a like-for-like cold comparison.
This exposed an independent bottleneck: five matched-mode cold builds had
uncached/cached medians of 12.857/5.420 s. The uncached writer used the pure
OpenC SHA-256 implementation for every large object, then read and hashed
each published object again. The cached writer already used the optional
Windows SHA accelerator for large buffers, falling back to the exact OpenC
implementation.

The uncached writer now uses that same digest function for both hashes. It
still publishes each object to disk and authenticates the file-backed bytes
before native link. The new five-pair uncached/cached medians were
6.551/6.260 s, with exact linked output. Ten order-alternated old/new
uncached revision pairs completed with exact output and 10/10 new-revision
wins; the eleventh old-revision run could not write its PE because the host
drive reached zero free bytes, so that pair is **invalid and excluded**.

The final combined source reached a three-stage byte-exact fixed point at
`5d1bfbb5dce6df40b27fd244dd74541d77e6eaeda5513178c17b147424fae793`.
Its focused 2/8/32 COFF proof and seeded self-host fixed point passed under
the child RAM caps. Final-source full cache, strict 20/20, conformance,
representative, and hosted module/COFF gates remain to be run on a host with
adequate system RAM and disk headroom. Local raw JSON reports are in ignored
`OpenC-1.0/build-output/ss-verified/`, `sp27-cold-four/`,
`sp27-cold-four-uncached/`, and `sp27-cold-sha/`.

## Remaining architectural cost

This removes a measured worker scheduling penalty and the avoidable slow
uncached hashing path, but it does **not** make cold 32-object output match
normal direct PE. The next architecture target is the roughly one-second
post-worker COFF construction/link path, without replacing a verified file
read with an unchecked in-memory shortcut. A normal-default incremental
policy must still pass cold/edit/no-op/real-project economics and two
independent final-source pinned C/D parity runs.
