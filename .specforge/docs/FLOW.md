# Plan -> Test -> Ship

SpecForge has three human-facing phases and three approval gates.

```text
Plan -> Test -> Ship
```

Approvals:

```text
Approve specs -> Approve red tests -> Approve final diff
```

No command advances through an approval gate automatically.

Iterations repeat this loop. The active `.specforge/ALIGN.md`,
`.specforge/DESIGN.md`, and `.specforge/specs/SPEC-*.md` describe only the
current iteration. Future requirements are queued in `.specforge/NEXT.md` until
the active specs are done.

Every active artifact carries `**Iteration:** ITER-...`. Completed iterations
are archived under `.specforge/iterations/`, and generated registry files
(`.specforge/REGISTRY.md`, `.specforge/registry.json`) summarize active,
implemented, and superseded requirements across current and archived specs.

Framework updates are separate from feature work. Use `sf update --dry-run`
or the curl installer with `--update --dry-run`; update only framework-owned
files and SpecForge-managed instruction blocks, never approved project specs or
plan artifacts.

## Plan

Goal: create the shared understanding, technical design, and approved SPEC
files.

Commands:

```text
/sf-plan
```

Outputs:

- `.specforge/ALIGN.md`
- `.specforge/DESIGN.md`
- `.specforge/specs/SPEC-*.md`

Gate: the human approves the Plan artifacts before any tests are written. Running `/sf-test SPEC-ID` is the approval signal — no separate approval step is needed.

If `/sf-plan` is run after all active specs are done, it frames the next
iteration, archives the completed artifacts under `.specforge/iterations/`, and
starts a fresh Align step. If `/sf-plan` is run with a new requirement while
active specs remain unfinished, it queues that requirement in `.specforge/NEXT.md`
and stops.

If a requirement changes after it was implemented, do not edit the old
requirement. Create a new `REQ-*` ID in the next iteration and mark the old ID
as superseded in the SPEC.

## Test

Goal: write failing tests for one approved SPEC, then stop.

Command:

```text
/sf-test SPEC-ID
```

`SPEC-ID` may resolve either `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`. Branches use the stable ID, for example
`feature/SPEC-009` for `.specforge/specs/SPEC-009-frequency-record.md`.

Process:

1. Create or switch to `feature/SPEC-ID` in the current checkout.
2. Read the SPEC.
3. Write the listed tests.
4. Run `bash .specforge/scripts/sf-test.sh`.
5. Confirm the tests fail for the expected reason.
6. Set `Build state: tests-red`.
7. Stop.

Review:

```text
/sf-review SPEC-ID
```

Review uses the same SPEC resolver and stable branch ID as Test.

Gate: the human approves the red tests before implementation. Running `/sf-ship SPEC-ID` after `/sf-review` is the approval signal.

## Ship

Goal: implement only after test approval, verify, then stop for final review.

Command:

```text
/sf-ship SPEC-ID
```

Process:

1. Implement the minimum code to make the approved tests pass.
2. Run `bash .specforge/scripts/sf-test.sh`.
3. Tick SPEC checkboxes and set `Build state: done`.
4. Commit on `feature/SPEC-ID`.
5. Run `bash .specforge/scripts/sf-verify-build.sh SPEC-ID`.
6. Stop.

Review:

```text
/sf-review SPEC-ID
```

Review and finalization use the same SPEC resolver and stable branch ID as
Test and Ship.

Gate: the human approves the final diff before finalization. Running `/sf-finalize SPEC-ID` after `/sf-review` is the approval signal.

Finalize:

```text
/sf-finalize SPEC-ID
```

`/sf-finalize` verifies, fast-forward merges into the base branch, and deletes
the feature branch. Use `/sf-finalize SPEC-ID --dry-run` to check without
changing state.

Status and traceability:

```text
/sf-status
```

Use it to inspect phase state, per-SPEC checkboxes, and requirement
traceability. Status reports the active iteration, queued `NEXT.md` work, active
SPEC progress, and registry counts for active, implemented, and superseded
requirements.

```bash
sf trace
```

`sf trace` reads active specs and archived iteration specs, refreshes
`.specforge/REGISTRY.md` and `.specforge/registry.json`, and prints a
requirement table. Use it before planning changed behavior so the framer,
aligner, and designer can see which requirements are already implemented.

## Requirement Changes

Implemented requirements are immutable history. If behavior changes after a
requirement is done:

1. Keep the old archived `REQ-*` ID unchanged.
2. Create a new `REQ-*` ID in the active iteration.
3. Link the change in the new SPEC `## Supersedes` section, for example:
   `REQ-OLD-001 -> REQ-NEW-001`.
4. Let `sf trace` mark the old requirement as `superseded` in the registry.

## Parallel Work

Sequential is the default. Parallel specs are allowed by opening multiple
sessions, but there is no automatic conflict detection. Finalize sequentially.

## Never Do This

- Write implementation before red tests.
- Skip human approval of Plan artifacts.
- Skip human approval of red tests.
- Skip final diff review before finalization.
- Hardcode test commands; always use `sf-test.sh`.
- Mix new requirements into an approved active iteration with unfinished specs.
- Reuse or rewrite implemented requirement IDs for changed behavior.
