# OpenC 1.0.0-rc.7 maintainer release review

Date: 2026-07-21
Review class: `INTERNAL_MAINTAINER_REVIEW`
Release scope: Windows x86-64 Hosted

## Result

No open P0 or P1 finding is known in the declared release scope. The required
owner-maintained release gates pass. This is not an independent third-party
review and does not claim verification of experimental targets.

## Reviewed evidence

- authority ordering, 466-rule index, 174-production grammar, schemas, and
  structure validator;
- debug and release builds for all 9 canonical D targets;
- all 8 D test commands and 4 Python bootstrap tests;
- all 268 conformance fixtures, including 35 runtime fixtures;
- all 4 maintained programs;
- source completeness, deterministic manifest generation, clean archive
  extraction, and repeat archive hashing;
- 0BSD/CC0 licensing scope, contribution terms, governance, security, errata,
  support, release authorization, and publication separation;
- explicit Windows-only 1.0 implementation scope.

## Nonblocking follow-up

- author dedicated fixtures for the remaining 135 active Core rules;
- complete dedicated positive/rejection evidence pairs for all grammar productions;
- obtain external grammar, semantic, security, and usability reviews;
- verify Linux, freestanding, Native, and standalone C providers if a later
  release adds them as supported targets.

These items constrain future evidence and platform claims but do not contradict
the declared Windows x86-64 Hosted candidate.
