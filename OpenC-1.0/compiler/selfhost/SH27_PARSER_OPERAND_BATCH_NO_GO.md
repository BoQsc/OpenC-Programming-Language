# SH-27 parser-owned operand/operator batch: no-go

Status: **four compiler candidates built and rejected; all trial source removed**.
The retained compiler remains `27a1f830...`, committed at `6ad7ba9`.
This is a measured rejection of a proposed architecture, not SH-27 closure.

## What was tested

Binary, assignment and unary construction know their operand records. The
trial stores encoded child IDs in the upper halves of the existing two
operator-span words. No syntax arena, record stride, table or worker is added.
Sources/node IDs outside the packed bounds retain untagged records. Logical
span accessors preserve the original offsets; all audited operator-span
consumers use them. Names, declarations, calls, members, indexes and ranges
retain their original representation. Public syntax output uses unchanged
kind/start/length fields. Exact-boundary queries use published links; arbitrary
range and legacy/manual queries retain the old search.

Four variants were built: links with helper calls; links plus cached operator
spelling; inline child decoding; and direct native span-decoding intrinsics.
The first three have three identical bootstrap generations. The fourth has
an expected old-seed transition and identical stages 2/3. All measured
application PEs and runtime outputs match the retained compiler exactly.

## Same-host decision

The original production-v1 corpus, normal default, owned four-logical-CPU
affinity, serial guarded compiler jobs, 11 adjacent rotated pairs and a
same-run null control are unchanged. All samples are retained.

| Candidate | Large delta / wins / null | Control delta / wins / null |
| --- | ---: | ---: |
| Published links | +15.041 ms / 2 of 11 / 5.710 ms | +6.103 ms / 5 of 11 / 7.793 ms |
| Links + operator spelling | +13.123 ms / 4 of 11 / 5.710 ms | +4.925 ms / 3 of 11 / 7.793 ms |
| Inline child decoder | +11.078 ms / 5 of 11 / 5.710 ms | +5.794 ms / 4 of 11 / 7.793 ms |
| Native span decoder, separate run | +10.643 ms / 3 of 11 / 36.760 ms | -0.821 ms / 6 of 11 / 7.947 ms |

Negative means faster. None qualifies a target gain. The first three have
positive large deltas above null; the fourth is below a much higher null
floor, not evidence of improvement. Small/many-file effects also remain below
their respective null floors. A matrix `PASS` here means guarded correctness,
not a speed win: `--require-gain` was not used for this rejection batch.

The final variant also passes an independent structural probe covering all
binary and compound-assignment spellings, precedence, right-associative
assignment, parenthesized/unary expressions, nested calls, casts, indexing,
member access and pointer expressions. Copies of the old span-search
algorithms provide the oracle. Tagged, legacy and unrelated-boundary queries
are checked, with serial/adaptive exact probe binaries and runtime. Two
earlier probe attempts failed before execution because of the test fixture's
out-value initialization; the corrected fixture passes. No structural
mismatch or production semantic change is claimed from those setup failures.
Full conformance/strict-RAM certification was not spent on rejected variants.

## Retained artifacts

Under ignored `build-output/sh27-parser-operand-links/`:

- `batch-four-cpu11.json`: `2ed7c2ae2bb812487e9ab0d06d02246371ba2a840c99cd54e4750a60add5d57a`.
- `decoded-four-cpu11.json`: `1a6ccfba822375c02bd24bb6144e57a03c2daef920123f21e9877613c7c7616b`.
- `decoded-probe-v3.json`: `e0d55d2886a40ca877a83e0aea8419f8a6db110a6623c136c52e4e614c916893`.
- `rejected-decoded-source.patch`: `a1e93189e939dcf6bd2cf60c80a7761cefee712316b91cdff5724c5b9c08b52d`.
- `probe.p`, guarded bootstrap reports and all four candidate binaries.

Candidate SHA-256 values, in table order:
`5c0889688f4210bd89d07e8a8e0da48e169201b518ec364b536b68075e942ab4`,
`78c338e945bf5ebdd000ca0233ad4d443755cd4cc611f62819b3fee370c8ea35`,
`14d894008635488d103f4bb41a60a8ae10e7cef94f68831a7cd844ca85bea5e5`,
`984356b6686f2f51658e6365bc40b9d89e7c5592a6461e0c80b121e75d0e8782`.
The archived source is the final decoder variant; intermediate binaries and
reports are retained without claiming a separate archived patch for each.
All 228 current compiler source hashes again match the retained compiler's
passing worker proof after the trial was removed.

## Next architectural cut

Do not repeat parser-link variants without a new source of removed work.
The corrected compiler's owned profile ranks node-index construction first
among in-image endpoints. Inspection shows `ir_initialize_node_indexes`
clears a source-byte-sized head array and then fills a second usize successor
array in a reverse pass over every source byte. The latter has only five
query sites across four files; two constructors own its allocation.

The next bounded candidate should replace that dense successor array with
compact expression-start occupancy and a word-skipping successor query,
without duplicating the dense array. Preserve exact candidate order, ties,
half-open/arbitrary spans, end sentinels and unindexed fallbacks. First prove
the successor against a dense reference at every boundary, including empty,
adjacent, sparse and final-word starts; then run the original protected lanes,
expression scaling, full correctness and strict RAM before promotion.

This can remove the dense reverse fill and reduce requested successor bytes;
it does not yet establish a wall gain or close the 14.055 ms internal budget.
The original constrained DMD repeat, normal-default incremental, real-project,
repeated final-source and release requirements remain open.
