---
name: sf-ship
description: Implement one SpecForge SPEC after the red tests have been approved. Use when the user invokes /sf-ship with a SPEC ID.
disable-model-invocation: true
---

# /sf-ship SPEC-ID - implement after test approval

This is the Ship phase for one SPEC. Invoking `/sf-ship` IS the human's
approval of the committed red tests — no separate approval step exists.

## What you do

1. Read `.specforge/agents/builder.md` — it is your full operating procedure.
   The process steps live there (step 7 onward), not here.
2. Verify the SPEC resolves to `.specforge/specs/SPEC-{ID}.md` or
   `.specforge/specs/SPEC-{ID}-<slug>.md` and that `**State:**` is `tests-red`.
   - Any other state: stop and report it. Do not implement a spec whose red
     tests were never written and committed.
3. Follow the builder manual through implementation, verification, and the
   final commit. Stop for final human review. Do not finalize.

**Handoff:**
- Called from `/sf-loop`: the reviewer gate runs automatically after this
  phase — do not tell the human to review.
- Called directly by the human: tell the human to run `/sf-review SPEC-ID`
  before `/sf-finalize SPEC-ID`.
