# SH-27 per-module COFF-set vertical slice (isolated experiment)

`openc artifact --kind=module-coff-set --output=PREFIX` now emits one COFF
object for each function-bearing module and a `PREFIX.modules.json` manifest.
It remains opt-in and does **not** change ordinary PE, COFF, DLL, or library
emission. The compiler still accepts, lowers, and emits the whole project in
one `IrContext`; this command splits the completed native stream at its
length-delimited function records. It is not independent module compilation,
incremental reuse, a compiler-speed win, or SH-27 Step 6 completion.

Each object defines its local functions as COFF external symbols with the
existing `$openc$` + 64-hex stable identity. A relocation to a function in
another module becomes an undefined external with the *same* stable name.
The per-module writer retains numeric global IDs only while translating the
current in-memory stream; no numeric ID enters the cross-object link contract.
The stable-name projection rejects unsupported declaration kinds such as
`when_decl`. These external COFF symbols are internal OpenC link identities,
not PE/DLL exports or C-ABI names. The object writer explicitly fails closed
on relocations into its whole-project `.data` section; runtime-state and
several intrinsic-heavy programs therefore remain unsupported.

Module order is lexical and object paths are `PREFIX.<SHA256(module-name)>.obj`.
Empty modules have no object entry. The command caps the native stream at
64 MiB, module count at 64, prefix length at 4096 bytes, and module names at
1024 bytes; it rejects empty/duplicate module names. Its subset extraction is
two-pass: count selected record bytes first, then allocate only that exact
subset, not a full-stream copy per module.

## Output-set failure semantics

The command first overwrites `PREFIX.modules.json` with a small
`status: INCOMPLETE` marker. It writes the object files, hashes their emitted
bytes, and only then replaces the manifest with `status: COMPLETE` plus
paths, hashes, and function counts. A late failure leaves an INCOMPLETE or
malformed manifest, not an apparently valid old COMPLETE manifest. Existing
object files may have been overwritten before failure; a rerun may recover.
The writes are **not atomic**, do not protect against concurrent writers, and
do not read back object bytes for content validation. No production consumer
or cache uses this output set. The manifest hash is an emission record, not a
validated cache key. The command never reads an arbitrary existing output
file merely to check its presence.

## Executable falsification and guards

`OpenC-1.0/compiler/selfhost/test_module_coff_set.py` builds a two-module
fixture with a cross-module call. It parses the independently emitted COFF
symbol tables and requires the importer's undefined external to equal the
provider's stable definition. Using `lld-link` and a kernel32 import library
strictly as test oracles, it links and executes the pair (exit 7); a callee
body edit changes only the provider object and executes as exit 8. Manifest
key reorder and unrelated declaration insertion leave the importer object
byte-exact. A same-prefix rerun reproduces the manifest and object bytes.
Replacing the second object's output path with a directory forces a late
failure and leaves the manifest INCOMPLETE; removing that obstacle and
rerunning restores COMPLETE with matching emitted hashes and bytes. The
existing `test_coff_stable_symbols.py` ten-check suite also passed, including
byte-exact ordinary COFF and PE parity with the previous isolated compiler.

The guarded bootstrap record is
`OpenC-1.0/build-output/sh27-module-coff-20260924-e/bootstrap-current/bootstrap-current.json`.
Stage 1/2/3 passed 512 MiB private and 128 MiB working-set guards. Working-set
peaks were 61,337,600 / 68,444,160 / 60,940,288 bytes; private peaks were
194,883,584 / 263,962,624 / 258,736,128 bytes. Stages 2 and 3 are byte-exact
with SHA-256
`52f6f991a264bdbad2bebf0e81bc4e033dc278afa7026069b53014a231a58c6f`.
This does not prove a 64 MiB working-set gate (Stage 2 exceeded 64 MiB), nor
any compilation-throughput improvement. The earlier failed bootstraps from
attempted file-existence helpers are retained under sibling `-a` through `-d`
directories as negative evidence; those helpers are absent from this source.

## Remaining promotion blockers

1. Move acceptance/lowering/emission to independently compilable module
   units with a deterministic imported/exported symbol interface; this slice
   still performs all whole-project work before partitioning the stream.
2. Define shared data and runtime-helper ownership/relocations across
   modules. Current `.data` relocation cases fail closed.
3. Implement an OpenC-native multi-COFF reader/linker with system-DLL import
   resolution. `lld-link` and its kernel32 import library are test oracles,
   not new OpenC toolchain dependencies.
4. Build dependency-complete interface/content keys, atomic artifact creation
   and read-back validation, correct invalidation, and real warm reuse that
   skips lowering/emission for unchanged modules. Only then measure a warm
   compile-speed claim under strict memory and correctness gates.
