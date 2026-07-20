# Definition of Ready to Implement OpenC Core 1.0

OpenC is ready to enter implementation when all of the following authored inputs exist and agree:

- one authoritative normative standard and EBNF;
- one active rule index and diagnostic catalog;
- ratified language-design decisions;
- no known internal P0 defect left unaddressed;
- explicit algorithms for names, types, constants, overloads, flow, outputs, ownership, borrows, pointers, cleanup, and lowering;
- exact source-span and diagnostic contracts;
- exact module-interface and target-record contracts;
- rule-by-rule and production-by-production implementation matrices;
- implementation gates I0–I5;
- conformance fixture formats and adapter protocol;
- tool CLI, formatter, language-server, explain, and context-reporting contracts;
- deterministic local validation, packaging, checksum, and archive-verification tools;
- an honest list of gates that still require independent people and suitable build environments.

IR1 satisfies this authored-input definition. Independent review and implementation remain expected to discover corrections; such findings update the candidate through the maintenance process rather than being silently resolved by a compiler.
