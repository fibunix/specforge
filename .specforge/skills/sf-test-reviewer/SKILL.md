---
name: sf-test-reviewer
description: Internal independent reviewer for tests-red branches.
---

# sf-test-reviewer

Validate a `tests-red` SPEC branch before autonomous implementation.

Check:
- Every acceptance `REQ-*` has a corresponding test annotation.
- Tests contain real assertions and fail for the expected missing behavior.
- The branch contains no implementation drift.
- Changed files are declared in the SPEC test list, except allowed SpecForge notes.

Write `.specforge/reviews/<SPEC-ID>/tests-red-<commit>.md` with:
`spec_id`, `phase`, `base`, `head`, `reviewer`, `verdict`, commands run, concise
findings, and a final exact `VERDICT: PASS` or `VERDICT: FAIL`.
