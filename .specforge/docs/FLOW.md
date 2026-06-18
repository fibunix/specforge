# Plan -> Build Loop -> Archive

SpecForge has a human-approved Plan phase, a per-SPEC build loop, and an
archive step for completed iterations.

```text
Plan -> Build Loop -> Archive
```

Manual approvals:

```text
Approve specs -> Approve red tests -> Approve final diff
```

Autonomous build-loop approvals:

```text
Approve specs -> independent tests-red PASS -> independent done PASS
```

Plan approval is always human-only. After Plan approval, `/sf-loop` and
`/sf-goal` may continue through merge only when independent reviewer receipts
contain exact `VERDICT: PASS`.

Iterations repeat this loop. The active `.specforge/ALIGN.md`,
`.specforge/DESIGN.md`, and `.specforge/specs/SPEC-*.md` describe only the
current iteration. Future requirements are queued in `.specforge/NEXT.md`
(format: `.specforge/templates/NEXT.md`, one bullet per requirement) until the
active specs are done. NEXT.md survives iteration archiving — it is the next
iteration's input brief.

Every active plan artifact except NEXT.md carries the same
`**Iteration:** ITER-NNN-<slug>` value (NEXT.md describes the *next* iteration
and gets its ID when that iteration is aligned). Completed iterations are
archived under `.specforge/iterations/<ITER-ID>/` with an agent-authored
SUMMARY.md close-out. The spec files themselves — active and archived — are
the requirement history: grep them for `REQ-*` IDs to find implemented and
superseded requirements.

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

Gate: the human approves the Plan artifacts before any tests are written. The
Designer records the approval on disk by setting `**State:** approved` on every
SPEC in the bundle (lifecycle reference: SPEC-FORMAT.md § State lifecycle).

If `/sf-plan` is run after all active specs are done, it archives the completed
artifacts, runs the Aligner to establish the next iteration brief, and produces
a new `ALIGN.md`. If `/sf-plan` is run with a new requirement while active
specs remain unfinished, it queues that requirement in `.specforge/NEXT.md`
and stops.

If a requirement changes after it was implemented, do not edit the old
requirement. Create a new `REQ-*` ID in the next iteration and mark the old ID
as superseded in the SPEC.

## Build Loop

The normal manual loop remains:

```text
/sf-test SPEC-ID
/sf-review SPEC-ID
/sf-ship SPEC-ID
/sf-review SPEC-ID
/sf-finalize SPEC-ID
```

The explicit autonomous loop is:

```text
/sf-loop
/sf-goal
```

`/sf-goal` is only a thin wrapper around `/sf-loop`; it reuses the same
selection, reviewer receipts, and finalization rules.

The coordinator stays lean. It reads `sf facts`, the DESIGN SPECS dependency
table, reviewer receipts, and `[RESULT]` blocks. Builders and validators read
the detailed artifacts.

### Test

Goal: write failing tests for one approved SPEC, commit them, then stop.

Command:

```text
/sf-test SPEC-ID
```

Process:

1. Create a worktree for the SPEC: `sf worktree create SPEC-ID` (idempotent — safe to re-run).
2. All remaining steps run inside `.worktrees/SPEC-ID/`. The worktree is already checked out to `feature/SPEC-ID`; no branch switching needed in the main checkout.
3. Read the SPEC.
4. Write the listed tests.
5. Run `bash .specforge/scripts/sf-test.sh`.
6. Confirm the tests fail for the expected reason.
7. Set `**State:** tests-red`.
8. Commit: `git commit -m "SPEC-ID: red tests"`.
9. Stop.

Review:

```text
/sf-review SPEC-ID
```

Manual gate: the human approves the red tests before implementation. Running
`/sf-ship SPEC-ID` is the approval signal.

Autonomous gate: an independent test reviewer validates coverage, real
assertions, scope, and expected red failure, then writes
the receipt defined in `.specforge/docs/REVIEW-CONTRACT.md` for the exact
tests-red commit. Missing receipt, stale head, wrong reviewer, schema failure,
or any verdict other than exact final `VERDICT: PASS` stops the loop.

### Ship

Goal: implement only after test approval, verify, then stop for final review.

Command:

```text
/sf-ship SPEC-ID
```

Process (all steps run inside `.worktrees/SPEC-ID/`):

1. Implement the minimum code to make the approved tests pass.
2. Run `bash .specforge/scripts/sf-test.sh`.
3. Tick SPEC checkboxes and set `**State:** done`.
4. Commit on `feature/SPEC-ID`.
5. Run `bash .specforge/scripts/sf-verify-build.sh SPEC-ID`.
6. Stop.

Review:

```text
/sf-review SPEC-ID
```

Manual gate: the human approves the final diff before finalization. Running
`/sf-finalize SPEC-ID` is the approval signal.

Autonomous gate: an independent implementation reviewer validates final diff,
scope, requirements, green tests, and undeclared files, then writes
the receipt defined in `.specforge/docs/REVIEW-CONTRACT.md` for the current
done branch head. Missing receipt, stale head, wrong reviewer, schema failure,
or any verdict other than exact final `VERDICT: PASS` stops the loop.

### Finalize

```text
/sf-finalize SPEC-ID
```

`/sf-finalize` verifies, fast-forward merges into the base branch, and deletes
the feature branch. Use `/sf-finalize SPEC-ID --dry-run` to check without
changing state.

Autonomous finalize uses:

```bash
sf finalize SPEC-ID --autonomous
```

The script requires matching PASS receipts before merge.

The base branch is auto-detected as `main`, `master`, `trunk`, or `develop`. If
your project uses a different branch, set `SPECFORGE_BASE_BRANCH` before
running finalize:

```bash
export SPECFORGE_BASE_BRANCH=release
sf finalize SPEC-ID
```

## Status

Status and traceability:

```text
/sf-status
```

Use it to inspect phase state, per-SPEC checkboxes, and requirement
traceability. `sf facts` (also `sf status`) dumps the raw facts — per-SPEC
State is read from the most-advanced copy of each spec (worktree, feature
branch, or checkout), so it is truthful while work is in flight on a branch.
The agent applies the decision ladder in the sf-status skill to recommend the
next command. For traceability questions ("where is REQ-X implemented? what
supersedes it?"), the agent greps `.specforge/specs/` and
`.specforge/iterations/*/specs/` and answers from the spec files directly.

`/sf-loop` uses the same DESIGN-table order and dependency rule as
`/sf-status`: a dependency is satisfied only when it is `done` and merged.

## Task

Tasks are small, mechanical changes that don't need design, approval, or test scaffolding. Use a task when:

- The change is purely mechanical — remove a field, rename a symbol, delete dead code, update a config value, fix a typo
- No new behavior is introduced
- The scope is clear from the request alone — no unknowns, no design decisions

Command:

```text
/sf-task "remove the deprecated legacy_field from User model"
```

The executor classifies the request, creates `.specforge/tasks/TASK-NNN-<slug>.md`,
makes the change in an isolated `feature/TASK-NNN` worktree, runs tests, and
commits. An independent task reviewer then validates the mechanical diff and
writes the receipt defined in `.specforge/docs/REVIEW-CONTRACT.md`. The merge
script rejects missing, stale, wrong-reviewer, or non-PASS task receipts. No
human approval is required, but tasks do not self-validate.

If a request doesn't meet the task criteria (new behavior, design decisions needed, API changes), the executor stops and tells you to use `/sf-plan` instead.

Tasks are orthogonal to specs: they run on their own branches and don't affect the spec decision ladder. `sf facts` and `sf status` show open tasks alongside specs.

## Requirement Changes

Implemented requirements are immutable history. If behavior changes after a
requirement is done:

1. Keep the old archived `REQ-*` ID unchanged.
2. Create a new `REQ-*` ID in the active iteration.
3. Link the change in the new SPEC `## Supersedes` section — that link *is*
   the supersession record; there is no separate registry to update.

## Parallel Work

Every SPEC already lives in its own worktree, so parallel work is the default: open one session per SPEC and run the normal `/sf-test` → `/sf-review` → `/sf-ship` loop concurrently. The main checkout stays on your working branch throughout — agent sessions never touch it.

For specs that share files, ask the agent for a wave plan (the procedure lives in the sf-plan skill, § Wave planning). It reads each ready SPEC's declared `## Tests` and `## Implementation` file lists: specs with disjoint file sets are safe to implement in parallel; overlapping specs are serialized, and a dependency counts as satisfied only when it is done and merged. Waves are advisory — merge gates and tests still catch a wrong grouping.

Manual gates still apply — each spec stops at `tests-red` for review and
requires explicit `/sf-ship` and `/sf-finalize`. Autonomous `/sf-loop` can
advance those gates only with independent PASS receipts.

Finalizing a wave: the second branch in a wave cannot fast-forward after the
first merges. Use `--rebase`:

```bash
sf finalize SPEC-ID --rebase
```

`--rebase` rebases the feature branch onto the moved base, reruns full
`sf-verify-build.sh`, then ff-merges. Because wave specs are file-disjoint, rebases
are conflict-free in practice; a conflict aborts with instructions.

## [RESULT] Protocol

When a sub-agent (Aligner, Designer, Builder) finishes a phase, it ends its
response with a `[RESULT]` block. The coordinating session reads only this
block and discards the rest of the sub-agent's output.

Rules:
1. Sub-agent/phase output that survives a session is the `[RESULT]` block only.
2. A coordinating agent never re-reads artifacts a sub-agent just wrote — disk is the handoff, the block is the receipt.
3. Long file content never goes into a result block — the human inspects via `/sf-review`.

## Rules

1. Specs are the contract; implementation without a SPEC is rejected.
2. Tests come before implementation. A spec with no expected failing test is not ready to build.
3. Human approval is required for Plan and manual phase transitions. Autonomous
   transitions require independent reviewer receipts with exact `VERDICT: PASS`.
4. Use one spec, one worktree, one branch, and one merge. The main checkout is never touched during spec work.
5. Builders run `bash .specforge/scripts/sf-test.sh`; do not hardcode project test commands.
6. Tracking lives in `.specforge/specs/SPEC-*.md` checkboxes and stable `REQ-*` IDs; update only the current phase's fields.
7. Approved active iterations are protected; new requirements are queued in `.specforge/NEXT.md` until the current specs are done.
8. Implemented requirements are immutable; changed behavior gets a new `REQ-*` ID that supersedes the old one.

## Sources of Truth

- Active plan artifacts: `.specforge/ALIGN.md`, `.specforge/DESIGN.md`, `.specforge/specs/SPEC-*.md`
- Next-iteration brief: `.specforge/NEXT.md`
- Completed iteration archives: `.specforge/iterations/ITER-*`
- Agent manuals: `.specforge/agents/*.md`
- Phase skills: `.specforge/skills/*/SKILL.md`
- Project config: `.specforge/config.yaml`

Active plan artifacts describe only the current iteration. Grep archived
iteration specs to inspect implemented or superseded history.

## Never Do This

- Write implementation before red tests.
- Skip human approval of Plan artifacts.
- Skip human approval of red tests in manual mode.
- Skip final diff review before finalization in manual mode.
- Merge autonomously without matching PASS receipts.
- Hardcode test commands; always use `sf-test.sh`.
- Mix new requirements into an approved active iteration with unfinished specs.
- Reuse or rewrite implemented requirement IDs for changed behavior.
