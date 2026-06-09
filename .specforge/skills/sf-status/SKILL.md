---
name: sf-status
description: Show current SpecForge phase and per-SPEC status table. Use when the user asks about project status, current phase, which SPECs are in progress, what's done, or what to work on next.
---

# /sf-status — See where you are

> **Fresh session.** Quick check. Reads disk, prints a table, ends.

## What you do

1. Run:
   ```bash
   bash .specforge/scripts/sf-snapshot.sh
   ```
2. Show the output verbatim. It prints:
   - ALIGN.md/DESIGN.md status, active Iteration ID, NEXT.md queue state, and
     registry counts (active / implemented / superseded requirements)
   - one line per SPEC with its State and checkbox counts — State is read from
     the most-advanced copy (worktree, feature branch, or checkout), so it is
     truthful even when work is in flight on a branch
   - a computed `Next:` line with the exact next command
3. Briefly explain the `Next:` line in context. Do not re-derive the next
   action yourself — the script already computed it from disk.
4. When the human asks about requirement traceability, run:
   ```bash
   sf trace
   ```
   and show its output.

To inspect one spec's changes, run:

```bash
bash .specforge/scripts/sf-review.sh SPEC-ID
```

## Rules

- Read-only: no edits, no branch switching, no finalization.
- Do not summarize away warnings the scripts print.
