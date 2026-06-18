---
name: sf-test
description: Write red tests for one approved SpecForge SPEC. Use when the user invokes /sf-test with a SPEC ID.
disable-model-invocation: true
---

# /sf-test SPEC-ID - write red tests for review

This is the Test phase for one SPEC. Invoking `/sf-test` with an approved SPEC
is the human's instruction to write reviewable red tests.

## What you do

1. Read `.specforge/agents/builder.md` — it is your full operating procedure.
   The test-writing process steps live there, not here.
2. Verify the SPEC resolves to `.specforge/specs/SPEC-{ID}.md` or
   `.specforge/specs/SPEC-{ID}-<slug>.md` and that `**State:**` is `approved`.
   - `draft`: design bundle never approved — stop, point the human at `/sf-plan`.
   - `tests-red`: a prior session already committed red tests — stop and report
     it; the next action is `/sf-review SPEC-ID` then `/sf-ship SPEC-ID`.
3. Follow the builder manual through test creation, test run confirmation,
   `State: tests-red`, and the red-tests commit. Stop there. Do not implement.

**Handoff:**
- Called from `/sf-loop`: the reviewer gate runs automatically after this
  phase — do not tell the human to review.
- Called directly by the human: tell the human to run `/sf-review SPEC-ID`
  to inspect the committed tests.
