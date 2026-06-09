---
name: sf-ship
description: Implement one SpecForge SPEC after the red tests have been approved. Use when the user invokes /sf-ship with a SPEC ID.
disable-model-invocation: true
---

# /sf-ship SPEC-ID - implement after test approval

This is the Ship phase for one SPEC after the human has reviewed and approved
the red tests.

## What you do

1. Read `.specforge/agents/builder.md`.
2. Verify the SPEC resolves to `.specforge/specs/SPEC-{ID}.md` or `.specforge/specs/SPEC-{ID}-<slug>.md`.
3. Verify `Build state: tests-red` and that the human has approved the red tests.
4. Implement the minimum code for the approved tests.
5. Run `bash .specforge/scripts/sf-test.sh` and fix failures.
6. Tick the SPEC checkboxes, set `Build state: done`, commit, and verify.
7. Stop for final human review. Do not finalize.

Tell the human to run `/sf-review SPEC-ID` before `/sf-finalize SPEC-ID`.
