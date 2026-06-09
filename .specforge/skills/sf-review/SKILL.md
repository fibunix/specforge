---
name: sf-review
description: Review a SpecForge SPEC branch — show diff summary, test results, and pending changes. Use when the user wants to review a SPEC, inspect what changed, or check the state of a feature branch before shipping.
---

# /sf-review SPEC-ID - inspect one spec's changes

> Fresh session. Read-only. Shows the human what changed and what to review.

## What you do

1. Verify the SPEC-ID argument was provided.
   - `SPEC-ID` may resolve `.specforge/specs/SPEC-ID.md` or `.specforge/specs/SPEC-ID-<slug>.md`.
2. Run:
   ```bash
   bash .specforge/scripts/sf-review.sh SPEC-ID
   ```
3. If the human passed `--patch`, run:
   ```bash
   bash .specforge/scripts/sf-review.sh SPEC-ID --patch
   ```
4. Show the output and call out the next action printed by the script.

## Rules

- Do not edit files.
- Do not run finalization.
- Do not summarize away warnings or missing branch errors.
