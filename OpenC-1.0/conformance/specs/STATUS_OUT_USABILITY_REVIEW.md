# Status/Out Usability Review Gate

The strict proof-lineage model remains the candidate direction. Before Core freeze, reviewers must test whether programmers can understand these diagnostics:

- output used before success proof;
- status overwritten before outputs resolve;
- copied bool does not carry proof;
- final proof carrier abandoned;
- branch merge produces maybe-initialized output;
- owning output creates conditional obligation.

Acceptance requires users to correct representative cases using only rule explanations and compiler diagnostics. If the model remains frequently misunderstood, the specification may improve diagnostics and syntax-local guidance without introducing hidden exceptions or result-wrapper declarations.
