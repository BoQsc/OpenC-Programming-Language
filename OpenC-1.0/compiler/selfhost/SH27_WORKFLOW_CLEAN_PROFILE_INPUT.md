# SH-27 workflow clean-profile input (isolated candidate)

The native `openc workflow` command now accepts optional
`--clean-profile=EVIDENCE.json`, passes that path to its existing
`finalization-audit` task, and records the selected path in the workflow
report. With no option, it retains the historical SH-25 review path. An
explicit empty value is rejected by the CLI. This is input plumbing only:
the finalization audit still independently verifies the VSIX and compiler
SHA-256 identities and all 44 checks. The historical review JSON was not
edited or replaced.

The isolated branch passed guarded Stage 1→3 bootstrap with byte-exact
Stage 2/3 SHA-256
`51ccaf3008571a84583522cf2699feb6457106271b63aa8d5528b54876389ef2`.
The bootstrap report is ignored local evidence at
`build-output/sh27-workflow-clean-profile-20260924/bootstrap-current/bootstrap-current.json`.
An empty `--clean-profile=` argument returned usage without launching any
workflow task.

A guarded `workflow --mode=daily` using the newly built compiler and an
explicit path to the **real clean-profile report from the previous production
compiler** recorded exactly that supplied path and completed 13/14 tasks.
The finalization task passed 42/44 checks; only
`clean_profile_vsix_identity` and `clean_profile_compiler_identity` failed.
This is the expected fail-closed result: the prior report names a different
compiler and VSIX, whereas this source change alters the compiler binary
(SHA-256 above) and VSIX (SHA-256
`ddc0eeb4c33611bf23304f20f9e11001c325386a6e9f2c34d6f9265111d3deea`).
The workflow child process and Job stayed within the 512 MiB guard; peak Job
private bytes were 69,132,288. Local records are
`build-output/sh27-workflow-clean-profile-20260924/workflow-daily.json`,
`sh25-native-finalization-audit.json`, and `workflow-guard.json`.

This candidate does **not** establish a 14/14 daily workflow pass or SH-27
completion. After the final compiler source is selected, package its VSIX,
run a fresh user-approved empty-profile VS Code exercise for that exact
compiler/VSIX, then pass its real JSON report through this option and require
44/44 finalization and 14/14 workflow. Never rewrite the historical report
or substitute an edited identity record.
