---
name: sf-loop
description: Advance the SpecForge build loop autonomously after human-approved Plan artifacts, gating each transition with an independent reviewer receipt.
---

# /sf-loop — autonomous build loop

Each invocation moves eligible approved specs through the build loop as far as
independent reviewer PASS receipts allow. Plan approval remains human-only.
Pair with Claude Code's `/loop` feature:

```
/loop /sf-loop
```

## Each iteration

1. Run `sf facts`, then read `.specforge/DESIGN.md`'s SPECS table for build
   order and Depends-on rules. Use the same dependency rule as `/sf-status`: a
   dependency is satisfied only when it is `done` and merged into the base
   branch. Never start a dependent spec just because its branch is done.

2. Find the first eligible spec in DESIGN-table order, with this stage priority:
   - State `done` + feature branch still exists → **implementation-review gate**
     at `done`, then **sf-finalize --autonomous**
   - State `tests-red` + tests committed on branch → **test-review gate** at
     `tests-red`, then **sf-ship**
   - State `approved` with dependencies satisfied → **sf-test**, then
     **test-review gate** at `tests-red`

   If no spec can advance, check for open tasks:
   - Run `sf task list` and look for any `state=open` task.
   - If found, invoke `/sf-task TASK-ID` for the first open task. The executor
     commits task work, the independent task reviewer gates it, and only then
     the coordinator merges it.
   - If multiple open tasks exist, handle one per loop iteration.

3. After each independent reviewer **PASS**, immediately continue to the next phase
   (no stop, no human prompt):
   - test-review `tests-red` PASS → **sf-ship** → implementation-review gate at `done`
   - implementation-review `done` PASS → **sf-finalize --autonomous**

   One invocation can carry a spec from `approved` all the way to finalized
   if both independent reviewers pass and write receipts.

4. If no spec can move forward AND no open tasks remain — every spec is
   finalized, still `draft`, or blocked on a failed reviewer — **stop the
   loop** and print:

   ```
   PIPELINE BLOCKED — waiting on human:
   - SPEC-NNN (<state>): <what is needed>
   ```

To invoke a phase, read `.specforge/skills/sf-{phase}/SKILL.md` and follow its
instructions for `<SPEC-ID>`.

## Reviewer Gates

After sf-test commits tests and after sf-ship commits implementation, spawn an
independent reviewer sub-agent before proceeding:

1. For `tests-red`, launch a fresh sub-agent using
   `.specforge/skills/sf-test-reviewer/SKILL.md`.
2. For `done`, launch a fresh sub-agent using
   `.specforge/skills/sf-implementation-reviewer/SKILL.md`.
3. For tasks, launch a fresh sub-agent using
   `.specforge/skills/sf-task-reviewer/SKILL.md`.

Each reviewer must write the receipt defined in
`.specforge/docs/REVIEW-CONTRACT.md`. The scripts validate the exact phase,
reviewer name, base commit, reviewed head, command evidence, and final
`VERDICT:` line.

Read only the script-validated receipt and final `VERDICT:` line:
- `VERDICT: PASS` → log: `Review passed SPEC-NNN [phase] — continuing` and
  proceed immediately.
- Anything else — reviewer cannot run, cannot write a receipt, receipt `head`
  does not match the current commit, or the exact line `VERDICT: PASS` is
  missing — fail closed. Stop the loop and print:
     ```
     PIPELINE BLOCKED — independent review failed:
     SPEC-NNN [phase]: <FINDINGS from sub-agent>
     Fix the issues and re-run /sf-loop, or run /sf-review SPEC-NNN for details.
     ```

## Hard rules

- `draft → approved` still requires human approval via `/sf-plan`. Never
  generate ALIGN.md or DESIGN.md automatically.
- If ALIGN.md or DESIGN.md is missing, stop and report — do not generate them.
- Run `sf lint` before advancing any spec. Fix lint errors first.
- Worktrees are the default: never switch the main checkout's branch.
- `/sf-goal` uses this exact workflow; do not maintain a second autonomous path.
