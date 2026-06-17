---
name: sf-loop
description: Advance the SpecForge pipeline, gating each commit with a critic sub-agent. Stops only at design gates (draft → approved) or when the critic finds real issues. Pair with /loop for continuous unattended advancement.
---

# /sf-loop — advance the pipeline

Each invocation moves the most-advanced eligible spec forward through as many
phases as the auto-review gate allows, stopping only at design gates or real
critic findings. Pair with Claude Code's `/loop` feature:

```
/loop /sf-loop
```

## Each iteration

1. Run `sf facts` and read the current state of all specs.

2. Find the most-advanced spec that can advance, in this priority order:
   - State `done` + feature branch still exists → **sf-finalize** (no gate needed)
   - State `tests-red` + tests committed on branch → **auto-review gate** at `tests-red`
   - State `approved` → **sf-test**, then **auto-review gate** at `tests-red`

   When multiple specs are at the same stage, prefer the one with the highest
   iteration number (most recent).

   If no spec can advance, check for open tasks:
   - Run `sf task list` and look for any `state=open` task.
   - If found, invoke `/sf-task TASK-ID` for the first open task. The executor
     runs to completion (classify → change → test → merge) with no gates.
   - If multiple open tasks exist, handle one per loop iteration.

3. After each auto-review **PASS**, immediately continue to the next phase
   (no stop, no human prompt):
   - auto-review `tests-red` PASS → **sf-ship** → auto-review gate at `done`
   - auto-review `done` PASS → **sf-finalize**

   One invocation can carry a spec from `approved` all the way to finalized
   if both auto-reviews pass.

4. If no spec can move forward AND no open tasks remain — every spec is
   finalized, still `draft`, or blocked on a failed auto-review — **stop the
   loop** and print:

   ```
   PIPELINE BLOCKED — waiting on human:
   - SPEC-NNN (<state>): <what is needed>
   ```

To invoke a phase, read `.specforge/skills/sf-{phase}/SKILL.md` and follow its
instructions for `<SPEC-ID>`.

## Auto-review gate

After sf-test commits tests and after sf-ship commits implementation, spawn a
critic sub-agent before proceeding:

1. Use the Agent tool to launch a sub-agent with the instructions in
   `.specforge/skills/sf-auto-review/SKILL.md`. Pass it the SPEC-ID and the
   current phase (`tests-red` or `done`). The sub-agent runs in a fresh context,
   reading the diff without accumulated session state.

2. Read the sub-agent's response for the `VERDICT:` line:
   - `VERDICT: PASS` → log: `Auto-review passed SPEC-NNN [phase] — continuing`
     and proceed to the next phase immediately.
   - `VERDICT: FAIL` → stop the loop and print:
     ```
     PIPELINE BLOCKED — auto-review failed:
     SPEC-NNN [phase]: <FINDINGS from sub-agent>
     Fix the issues and re-run /sf-loop, or run /sf-review SPEC-NNN for details.
     ```

## Hard rules

- `draft → approved` still requires human approval via `/sf-plan`. Never
  generate ALIGN.md or DESIGN.md automatically.
- If ALIGN.md or DESIGN.md is missing, stop and report — do not generate them.
- Run `sf lint` before advancing any spec. Fix lint errors first.
- Worktrees are the default: never switch the main checkout's branch.
