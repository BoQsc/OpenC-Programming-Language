# SH-27 compact child/name sidecar: quantified no-go

Status: **no source candidate built or timed**. This clean isolated branch is
from `6794d56`. The required proof threshold was to materially reduce the
measured child **and** name candidate visits in acceptance **and** IR lowering
without a new comparably expensive pass or extra RAM. Inspection of the
existing indexes shows that such a combined sidecar would mostly move
first-visit work rather than remove repeated work. No compiler code was
changed, merged, or pushed.

## Work already indexed and cached

- `ir_index_initialize.p:170` (`ir_initialize_node_indexes`) scans syntax
  once and builds compact
  expression-start heads and next links; a reverse source-position pass builds
  `expression_next_start`. Bounds/child queries therefore skip empty source
  positions and traverse only candidate lists. An additional index pass
  cannot be credited as saved work unless it replaces one of these passes.
- `ir_part1c_expression.p:113,176` (`ir_left_expression` and
  `ir_right_expression`) search their candidate lists
  **only on their first call per syntax node**, then write the selected node,
  including a miss sentinel, into existing `left_expression_cache` and
  `right_expression_cache` (initialized at
  `backend_c_project_source.p:230-241`). Acceptance populates these caches; the same
  per-source `IrContext` (`backend_c_project_source.p:268,280,281,364,462`)
  is then used by `ir_lower_function` (`ir_project.p:7`), which does not
  clear them. A second parent-to-child table would duplicate the two direct
  links already allocated, not eliminate a repeated acceptance-to-lowering
  traversal of those links.
- `ir_part2_resolution.p:7` (`ir_resolve_name`) checks `name_cache` first and
  `ir_part2.p:182` (`ir_cache_name_resolution`) stores `resolved + 1` even
  for an unresolved
  symbol. The indexed local/member/top lookup uses symbol hash buckets
  (`ir_index_lookup.p:30,99`, `ir_part1b.p:404`). The
  parser has the child `NodeResult` for binary/assignment construction
  (`parser_statements.p:212`, `parser_statements_part2.p:11`), but
  `ParserContext` (`parser.p:12`) has no symbol table, scope, import, or
  overload decision. A parse-time
  resolved-name sidecar is therefore impossible; resolving all name nodes
  later during indexing is precisely the forbidden eager traversal/cache.
- `ir_bounds.p:78` (`ir_root_in_bounds`) answers arbitrary span ranges,
  including call arguments
  and initializers. A fixed parent-to-child pair cannot replace this general
  indexed span query. Covering every range would require another variable
  edge table or precomputing range answers.

## Measured size of the opportunity

The isolated opt-in probe at `984c7bc` recorded exact candidate visits on
the established SH-27 corpora. Its evidence is
`SH27_ACCEPTANCE_FIRST_VISIT_PROFILE_EVIDENCE.md` on that separate branch;
raw corrected JSON is under ignored
`build-output/selfhost-sh27/sh27-acceptance-profile-runs-v2-20260924/` in
this worktree. Counters below were captured after acceptance and cover the
instrumented indexed helper paths, not every possible syntax lookup.

| Per build | Large functions | Control flow |
| --- | ---: | ---: |
| Syntax nodes | 183,833 | 40,341 |
| Indexed child candidate visits | 255,235 (1.39/node) | 44,867 (1.11/node) |
| Name candidate visits | 58,391 (0.32/node) | 13,009 (0.32/node) |
| Distinct uncached type first visits | 92,678 | 20,358 |
| Repeated uncached type visits | 0 | 0 |
| Sampled acceptance rule visits | 440,600 | 88,664 |

The 11-pair unprofiled baseline critical worker spent a median **157/141 ms**
in acceptance (large/control), including **94/125 ms** in expression rules,
and **62/32 ms** in IR lowering. These are broad, nested phase ceilings, not
times attributed to child/name scans. The measured candidate counts are
already near-linear in syntax size, while repeated uncached type visits are
zero. A parser/index-built table might make the child candidate counter fall
to zero, but only by writing the answer once per relevant node at parse/index
time, moving at least one traversal or adding retained links. It cannot
simultaneously make scope-dependent name candidate visits disappear without
eager name resolution or a new symbol-map architecture.

The current per-source `left_expression_cache`, `right_expression_cache`, and
`name_cache` already reserve three `usize` links per syntax slot: about
**4.41 MB** cumulative requested across the large corpus and **0.97 MB**
across control. A new pair of full-size child links would request another
**2.94/0.65 MB** cumulatively unless it replaces the existing two caches.
Retaining parse-time links across source records would increase simultaneous
live memory, material because guarded Stage 3 self-build working set is near
the strict 64 MiB limit and Stage 2 already exceeded it in the probe. Reusing
the existing cache storage avoids duplicate bytes but leaves the one-time
lookup effort essentially where it is.

## Decision

Do **not** spend a guarded build slot on a partial binary-expression link
patch or a new precomputed name cache. Neither meets the combined
acceptance-plus-lowering criterion, and neither has an attributable
millisecond budget beyond the broad nested 94/125 ms expression ceiling.
The larger typed semantic/acceptance plan remains a more credible candidate:
it can remove distinct first-visit rule work rather than relocate it.

Bounded next architectural alternatives from the unprofiled critical worker:

1. A shared typed acceptance/lowering plan can remove first-visit work; its
   entire acceptance-phase ceiling is **157/141 ms** (large/control), with
   assignment time **79/94 ms** nested inside that ceiling.
2. A per-source scratch arena could eliminate allocation overhead without
   changing semantic traversal; the entire unaccounted critical-worker
   phase gap caps that at **31/16 ms**. Cumulative requested bytes are not
   a live-memory target.
3. Source-chunk cost scheduling can reduce critical-worker imbalance by at
   most the observed slowest-minus-second-slowest median of **94/16 ms**;
   it does not reduce total acceptance work.

These ceilings overlap and are not promises or additive speedups. Each still
requires an isolated guarded candidate and paired large/control proof before
selection.

Revisit this sidecar only if a new profile isolates substantial **repeated**
uncached child/name traversal in IR lowering despite the existing caches, or
if parser and semantic ownership are redesigned together so direct links
replace existing arrays without an eager pass or higher strict-RAM peak.
