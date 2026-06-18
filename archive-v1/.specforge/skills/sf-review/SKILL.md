---
name: sf-review
description: Review a SpecForge SPEC branch — show diff summary, test results, and pending changes. Use when the user wants to review a SPEC, inspect what changed, or check the state of a feature branch before shipping.
---

# /sf-review SPEC-ID - inspect one spec's changes

> Fresh session. Read-only. You gather the evidence with git and answer the
> two gate questions yourself — there is no review script.

`SPEC-ID` resolves `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`. The feature branch is
`feature/SPEC-ID`.

## What you do

1. **Resolve the spec file** — read the most-advanced copy:
   - a worktree for `feature/SPEC-ID` exists → read the spec there;
   - else the branch exists and you are not on it → `git show
     feature/SPEC-ID:.specforge/specs/<file>.md`;
   - else → the checkout copy.
   Report its `**State:**` and the AC/Tests/Implementation checkbox counts.

2. **Show what changed.** With `BASE=$(git merge-base <base-branch>
   feature/SPEC-ID)` (base branch from `.specforge/config.yaml`, default
   `main`):
   ```bash
   git log --oneline $BASE..feature/SPEC-ID
   git diff --stat $BASE..feature/SPEC-ID
   git diff --name-only $BASE..feature/SPEC-ID
   ```
   If the human asks for the patch, show `git diff $BASE..feature/SPEC-ID`.
   In a worktree or on the branch, also show pending (staged + unstaged)
   changes. If the branch is missing, say so — there is nothing to review
   beyond the spec file itself.

3. **Answer gate question 1 — is every REQ-\* covered by a real test?**
   For each `REQ-*` in the spec's Acceptance criteria, find the test lines
   that claim to cover it (`(covers REQ-…)`), then **read the test bodies in
   the diff** — do not trust the annotations or the checkboxes. A test that
   nominally covers a REQ but asserts nothing is not coverage; say so. Flag
   any REQ with no covering test.

4. **Answer gate question 2 — did the work stay inside the spec's declared
   files?** Compare `git diff --name-only` against the file paths declared in
   the spec's `## Tests` and `## Implementation` checklists. Standing
   exemptions: the spec file itself (`.specforge/specs/*`),
   `.specforge/LEARNINGS.md`, `.specforge/CONTEXT.md`, and `docs/adr/*`.
   For anything else undeclared, say *why* it looks in or out of scope —
   scope creep and a missing declaration read the same in a file list but
   not in a diff. Also flag the reverse lie: a ticked checkbox whose file
   does not exist on the branch.

5. **End with the next action**, by spec state:
   - `draft` or missing — approve the design bundle during `/sf-plan` (the
     Designer sets `State: approved`), then `/sf-test SPEC-ID`.
   - `approved` — run `/sf-test SPEC-ID` to write reviewable red tests.
   - `tests-red` — review the red tests; if they are right, `/sf-ship SPEC-ID`.
   - `implemented` — legacy state: a ship session stopped mid-handoff. Tick
     the SPEC checkboxes, set `State: done`, and commit.
   - `done` — review the final diff; if it is right, `/sf-finalize SPEC-ID`.

## Rules

- Do not edit files.
- Do not run finalization.
- Do not soften findings: an uncovered REQ, an empty test, or an undeclared
  file is reported even when everything else looks good.
