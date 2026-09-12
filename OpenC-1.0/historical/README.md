# Optional historical bootstrap and audit kit

This directory names the only boundary where retained D, Python, generated-C,
TinyCC, and differential tooling belongs after SH-21. The payload remains in
its original source-tree locations so historical scripts and citations remain
stable, but `historical/HISTORICAL_BOOTSTRAP_AUDIT_KIT.json` is its canonical
inventory and policy.

The kit is optional. `openc build`, `openc check`, `openc test`, `openc
validate`, `openc benchmark`, `openc workflow`, and `openc release` do not
search it, invoke it, or package its implementation files. It may be used only
when a developer explicitly requests first-binary recovery, archaeology, a
differential audit, or an external C/D timing comparison.

The normal Windows x86-64 Hosted toolchain consists of a pinned previous OpenC
compiler, canonical `.p` source, and documented Windows system DLLs. Linux and
freestanding remain optional future targets.
