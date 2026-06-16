---
name: sf-loop
description: Advance the SpecForge pipeline one step, stopping at any human approval gate. Use when the user invokes /sf-loop to run the pipeline. Pair with /loop for continuous advancement.
disable-model-invocation: true
---

# /sf-loop — advance the pipeline one step

Each invocation of `/sf-loop` moves the most-advanced eligible spec forward by
exactly one phase, then stops. Pair with Claude Code's `/loop` feature to run
continuously until a gate is reached:

```
/loop /sf-loop
```

## Each iteration

1. Run `sf facts` and read the current state of all specs.

2. Find the most-advanced spec that can move forward **without human approval**,
   in this priority order:
   - State `done` + feature branch still exists → run `/sf-finalize <SPEC-ID>`
   - State `tests-red` + tests committed on branch → run `/sf-ship <SPEC-ID>`
   - State `approved` → run `/sf-test <SPEC-ID>` (creates the worktree
     automatically; all work happens in `.worktrees/<SPEC-ID>/`)

   When multiple specs are at the same stage, prefer the one with the highest
   iteration number (most recent).

3. Advance exactly **one spec one step**. The invoked phase command commits its
   result.

4. If no spec can move forward — every spec is finalized, still `draft`, or
   blocked on a gate — **stop the loop** and print:

   ```
   PIPELINE BLOCKED — waiting on human:
   - SPEC-NNN (<state>): <what is needed>
   ```

## Hard rules

- Never cross a gate without explicit human approval in this transcript:
  - `draft → approved`: Designer must approve via `/sf-plan`
  - after `/sf-test`: human must inspect the test diff (`/sf-review SPEC-ID`)
    before `/sf-ship`
  - after `/sf-ship`: human must inspect the implementation diff
    (`/sf-review SPEC-ID`) before `/sf-finalize`
- If ALIGN.md or DESIGN.md is missing, stop and report — do not generate them.
- Run `sf lint` before advancing any spec. Fix lint errors first.
- Worktrees are the default: never switch the main checkout's branch.
