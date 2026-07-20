# Authoritative Inputs for Implementation

Implementation work uses this order of authority:

1. `candidate/standard/OpenC_Core_Candidate_2.md`
2. `candidate/grammar/OpenC_Core_Grammar_CC2.ebnf` for source structure
3. `candidate/metadata/OpenC_Core_Rule_Index_IR1.json`
4. `candidate/metadata/OpenC_Core_Diagnostic_Catalog_IR1.json`
5. `candidate/security/OpenC_Core_Security_Model_CC2.md`
6. IR1 implementer algorithms and exchange schemas
7. conformance obligations and fixture outcomes
8. rationale and historical audit material

A contradiction between items 1–5 is a specification defect. An implementation records the finding and stops relying on guessed behavior. IR1 algorithm documents are informative implementation contracts: they may be implemented differently internally only when the observable normative result is identical.
