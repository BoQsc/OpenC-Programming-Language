# SH-27 frozen native type ownership and RAM headroom

Status: **local fixed-point, exact-output, correctness, strict RAM and paired
nonregression PASS; clean hosted confirmation and final-source parity open**.

The normal parallel native build closed all derived types before launching
workers but still allocated and copied the entire project-sized type arena
for each worker. The only writer of type records is `semantic_add_type`.
Workers now borrow the closed project type table read-only, advertise no
append capacity, and retain private layout caches. An attempted append is
rejected before a shared write and marks the worker invalid. This removes
four redundant type-arena copies without changing the serial path or the
source-chunk policy.

The discarded first hypothesis was per-worker flow diagnostic buffers:
validator-reported peak live allocation fell from about 215 to 146 MB, but
whole-process private/working-set peaks and self-build wall time did not
improve. A 5 ms bounded timeline placed the process peak during parallel
lowering/emission, after flow validation. A second trial avoided the
transient whole-project output reservation before chunked emission; its
sampled peak changed by less than 0.1 MiB. Both trials were removed.

The candidate reached a byte-exact three-stage self-hosted fixed point at
SHA-256 `53ce21e774c1e28614e1175707240ff1f094f9e8aabf1978955722a09f985364`.
The local 11 order-alternated self-build pairs used baseline compiler
`08f08ee45fa0a46411224c0fff6ae2a9adf5ec25e6fdaf6c63ae8bf739d41476`.
All 11 produced byte-identical executables. Baseline/candidate medians were
4.599/4.577 s, with seven candidate wins and a -0.046 s median paired delta;
the 5% nonregression gate passed. Maximum sampled private memory fell from
247,087,104 to 226,656,256 bytes (19.5 MiB); working set fell from
64,704,512 to 53,370,880 bytes (10.8 MiB). These are same-host paired
measurements, not a claim of a speed gain beyond noise. The ignored raw
report is `OpenC-1.0/build-output/sp27-shared-frozen-types/selfhost-pairs11.json`.

The candidate also passed:

- Strict 13/13 checks and 20/20 exact chained self-build generations under
  256 MiB private and 64 MiB working-set caps. Maximum sampled private /
  working set was 226,295,808 / 53,489,664 bytes.
- Native conformance 278/278; exact serial-vs-auto and serial-vs-two-chunk
  executable and invalid-diagnostic proofs on the self-host, small,
  many-file, large-function and control-flow cases.
- 2/8/32 deterministic COFF objects and seeded fixed point; 32-partition
  cold/warm/corrupt/body-edit/fresh/interface-edit cache recovery.
- Three representative workloads including a two-generation compiler
  self-build. The first representative attempt placed its copied self-host
  project near the Windows legacy path-length limit and stopped before
  loading any source; the identical suite passed from a shorter output path.

The strict, chunk, conformance, COFF and representative reports remain in
ignored local `build-output` paths. The branch's hosted module/partition
proof must repeat the result on a clean runner. This is a RAM ownership cut;
SH-27 still requires final-source normal-default C/D parity, selective
edited-source semantic work, representative breadth and release gates.
