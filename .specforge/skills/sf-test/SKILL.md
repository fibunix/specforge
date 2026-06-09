---
name: sf-test
description: Write red tests for one approved SpecForge SPEC. Use when the user invokes /sf-test with a SPEC ID.
disable-model-invocation: true
---

# /sf-test SPEC-ID - write red tests for review

This is the Test phase for one SPEC.

## What you do

1. Read `.specforge/agents/builder.md`.
2. Verify the SPEC resolves to `.specforge/specs/SPEC-{ID}.md` or `.specforge/specs/SPEC-{ID}-<slug>.md`, and that `**State:**` is `approved`.
   - `draft` means the design bundle was never approved — stop and point the human at `/sf-plan`.
   - `tests-red` means a previous session already committed red tests — report that and stop; the next action is `/sf-review SPEC-ID` then `/sf-ship SPEC-ID`.
3. Create or switch to branch `feature/SPEC-ID` in the current checkout.
4. Write failing tests for every unchecked line in the SPEC's `## Tests` section.
5. Run `bash .specforge/scripts/sf-test.sh` and confirm the tests fail for the expected reason.
6. Set `**State:** tests-red`.
7. Commit the red tests: `git add -A && git commit -m "SPEC-ID: red tests"`. Do not write implementation.

Tell the human to run `/sf-review SPEC-ID` to inspect the committed tests.
