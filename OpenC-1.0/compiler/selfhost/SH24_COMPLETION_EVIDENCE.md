# SH-24 native editor integration and language-service resilience evidence

Status: **PASS**

SH-24 ships a dependency-free first-party Visual Studio Code client for `.p`
source. It starts the packaged `openc.exe lsp --stdio` server, provides the
language features completed in SH-11 and SH-12, synchronizes incremental UTF-8
edits with monotonic versions, propagates cancellation, follows workspace
folder changes, and resynchronizes documents after a bounded restart.

The client and server share explicit ceilings: 4 MiB messages, 8 KiB client
headers, 128 pending client requests, 8 open documents, 8 remembered cancelled
request IDs, and 3 restart attempts. An oversized native server frame is
rejected before its body allocation. Multi-change editor events fall back to
one bounded full snapshot so a single document version is never applied more
than once.

`openc editor-audit` passes 33/33 checks. Its resilience session proves
incremental editing, stale-version rejection, cancellation, workspace-root
transition, close/reopen recovery, clean shutdown, and byte-deterministic
replay. Its capacity session proves that an ignored ninth document cannot evict
or corrupt the first eight.

The final 220-source compiler is 6,903,808 bytes and reaches a byte-identical
fixed point at
`d7bf359a19bff4d4f4301678f15026ff65ff599af3921927c339fde3bdccc186`.
The full workflow passes 16/16, including 278/278 conformance, 36/36 residual
contracts, 495/495 required repository paths, 39/39 pinned hashes, and 20/20
exact chained rebuilds. Build/validation medians are 11.765/6.023 seconds;
private/working-set peaks are 174,501,888/59,146,240 bytes, inside the
unchanged 256/64 MiB gates.

The OpenC-native release proof packages the editor and reruns its 33/33 audit
from the relocated standalone tree. Python, D, C, TinyCC, Node/npm, an
assembler, an external linker, and the network remain absent from every
required compiler, audit, workflow, and release path.

Final fixed-point, workflow, benchmark, conformance, repository-audit, and
relocated-release measurements are recorded in
`compiler/selfhost/SELF_HOSTING_STATE.json` and `VERIFICATION_STATUS.md`.
