# OpenC 1.0 final internal review

Date: 2026-09-13
Review class: `INTERNAL_MAINTAINER_REVIEW`
Scope: Windows x86-64 Hosted

## Result

No open P0 or P1 finding is known in the declared scope. This is not an
independent third-party review and is not recorded as one. The five external
review tracks remain open through `SH25_REVIEW_INTAKE.json`.

The final internal review covers the specification authority chain, 466 active
rules and 174 grammar productions, 278 conformance fixtures, safe-code and
resource ceilings, compiler fixed-point and throughput evidence, Windows ABI,
PE/COFF/runtime/WinMD/friendly API/COM/WinRT surfaces, the packaged editor,
licensing, governance, signing authority, release manifests, and publication
separation.

Final tagging and publication remain owner actions. Passing SH-25 freezes the
candidate evidence; it does not itself create or publish `v1.0.0`.

## 1.0.1 SH-27 follow-up (2026-11-02)

Review class remains `INTERNAL_MAINTAINER_REVIEW`. Compiler
`7c6f7bbaa5b9ed737a23c5779c560e54e0954d51f8756c412aad7f5ab05d42f5`
retains exact resolved-cell/type eligibility, pre-commit overflow/carry/narrow
checks and used assignment results in compact native updates. References,
conversions, other cells and unsupported operands preserve generic lowering.
C/audit lowering retains its original representation.

The identity worker starts only after its compilation owner has a stable
address. It writes a separate hash buffer, resolves all required pool APIs
before creation, and retains its owned work record through the mandatory
join. Identity use and every destruction path join before reading/freeing
worker-owned data. The explicit deferred flag avoids reading a concurrently
written hash length. Missing APIs and creation failure use serial fallback.
The complete bounded compiler hash, cache authentication, invalidation and
full-validation retry are preserved. Validated COFF borrows remain read-only
and partial selections retain exact owned extents.

Two independent hosted production certificates pass all 20 original pinned
C/D ratios and both scaling suites; two cache/package certificates pass
strict 20-generation closure, ordinary cold/warm/edit economics and the
four retained projects. Local full workflow 19/19, 278 conformance fixtures,
25 ABI checks, 28 worker failures, 30 cache cases, 32 integer/fallback cases,
fresh editor/finalization, deterministic native packages and the independent
extracted-package audit pass. Memory limits remain unchanged.

Rejected scheduling/projection candidates, the wrong local DMD-version
observations and the detected mutable-source archive mismatch remain in the
raw verification record. No known P0/P1 finding remains in this follow-up.
Independent review remains unclaimed, and owner publication authorization is
still required for the new version.
