---
name: sf-finalize
description: Finalize one completed SpecForge SPEC by verifying, fast-forward merging, and deleting its feature branch.
disable-model-invocation: true
---

# /sf-finalize SPEC-ID — verify, merge, and clean up one spec

You are finalizing one completed spec after either:
- manual mode: the human reviewed the final implementation diff with `/sf-review SPEC-ID`;
- autonomous mode: an independent implementation reviewer wrote current PASS receipts.

## What you do

1. Verify the SPEC-ID argument was provided.
   - `SPEC-ID` may resolve `.specforge/specs/SPEC-ID.md` or `.specforge/specs/SPEC-ID-<slug>.md`.
   - The feature branch uses the stable SPEC ID, for example `feature/SPEC-009` for `.specforge/specs/SPEC-009-frequency-record.md`.
2. Ask the human: "Did you encounter anything during SPEC-ID worth capturing in LEARNINGS.md before we close?" If yes, append the entry now using `.specforge/docs/LEARNINGS-FORMAT.md`. If no or no response, skip — this is never a blocker.
3. Run `bash .specforge/scripts/sf-finalize.sh SPEC-ID`. If called by
   `/sf-loop` or `/sf-goal`, run `bash .specforge/scripts/sf-finalize.sh SPEC-ID --autonomous`.
4. If it fails, report the exact error and do not try to force a merge.
5. If it succeeds, report that the spec was merged and the feature branch was deleted.

## Dry run

If the human passes `--dry-run`, run:

```bash
bash .specforge/scripts/sf-finalize.sh SPEC-ID --dry-run
```

Report that no merge was performed.

## Autonomous

If called from `/sf-loop` or `/sf-goal`, do not ask the human for final-diff
approval. The script enforces current PASS receipts:

```bash
bash .specforge/scripts/sf-finalize.sh SPEC-ID --autonomous
```

If the receipt is missing, stale, or lacks exact `VERDICT: PASS`, stop and
report the script error.

## Rules

- Do not finalize a spec with pending changes in the worktree.
- Do not bypass `sf-verify-build.sh`.
- Do not use non-fast-forward merge.
- Do not merge multiple specs in one invocation.
