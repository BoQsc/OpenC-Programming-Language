# OpenC standalone Windows distribution

This package is the OpenC 1.0 Windows x86-64 Hosted standalone distribution.
Its `openc.exe` compiler is built from the canonical OpenC `.p` compiler
source and uses the included TinyCC 0.9.27 Win64 backend.

Build an OpenC project from any working directory:

```powershell
C:\path\to\OpenC\openc.exe build `
  --project=C:\path\to\project\openc.project.json `
  --output=C:\path\to\project\program.exe
```

The compiler locates its runtime, native runtime shim, and backend relative to
its own executable. DMD, DUB, and Python are not compiler or backend
dependencies.

Check or run a project directly:

```text
openc.exe check --project=C:\path\to\project\openc.project.json --output=check-record.json
openc.exe run --project=C:\path\to\project\openc.project.json -- arguments
```

`check` prints concise human diagnostics and optionally preserves stable
machine streams in `openc.check.v1`. `version`, `target`, and
`explain RULE-ID` provide compiler, target, and canonical rule information.

The retained D bootstrap seed is
`bootstrap/openc-stage0.exe`. It is included only as an optional comparison
oracle for reproducibility audits. It is not invoked by `openc.exe build` or by
the required conformance gate.

Run the OpenC-authored conformance gate with:

```text
openc.exe validate --manifest=conformance/fixtures/MANIFEST.json --output=conformance-report.json
```

For the supported Windows Hosted mode, `openc.exe` provides the six
`system.file`, `system.io`, `system.memory`, `system.path`, `system.process`,
and `system.text` modules and links them to the packaged C runtime/native shim.
The authored `.p` Native-provider library sources are included for future
Native work; that separately scoped provider is not part of the SH-9 gate.

Package integrity is recorded in `STANDALONE-MANIFEST.sha256`; component roles,
input paths, and compiler/backend hashes are in `STANDALONE-RELEASE.json`.
The applicable project licenses are `LICENSE`, `LICENSES/0BSD.txt`, and
`LICENSES/CC0-1.0.txt`. TinyCC licensing and corresponding-source information
are under `third_party/tinycc-win64/`.

The supported release target is Windows x86-64 Hosted. Linux, freestanding,
and the separately scoped Native provider are optional future work and do not
gate this package.
