---
name: sf-status
description: Show current SpecForge phase and per-SPEC status table. Use when the user asks about project status, current phase, which SPECs are in progress, what's done, or what to work on next.
---

# /sf-status — See where you are

> **Fresh session.** Quick check. Reads disk, reasons, presents, ends.

Scripts enforce, agents interpret: `sf facts` gives you the raw state; *you*
derive what it means and what to do next.

## What you do

1. Run:
   ```bash
   bash .specforge/scripts/sf-facts.sh
   ```
   It prints ALIGN/DESIGN status, the active Iteration ID, the NEXT.md queue
   state, one line per SPEC — state, source, branch, and checkbox counts — and
   one line per TASK if any exist. State is read from the most-advanced copy of
   each spec (worktree, feature branch, or checkout), so it is truthful even
   when work is in flight on a branch.
2. Read `.specforge/DESIGN.md`'s SPECS table yourself for build order and the
   Depends-on column. (Skip if DESIGN.md is missing.)
3. Present a status table in DESIGN-table order (facts order for specs the
   table missed), then a `Next:` recommendation derived from the decision
   ladder below. If tasks appear in the facts output, list open ones after the
   SPEC table.
4. When the human asks about requirement traceability ("where is REQ-X
   implemented? what supersedes it?"), grep `.specforge/specs/` and
   `.specforge/iterations/*/specs/` for the `REQ-*` ID and answer from the
   spec files directly.

## Decision ladder

Apply the first rung that matches; that is the `Next:` line.

1. If the plan artifacts are not ready — ALIGN.md or DESIGN.md missing or not
   `approved`, or no SPEC files exist — recommend `/sf-plan`.
2. If any spec is `tests-red`, recommend `/sf-review SPEC-ID` then
   `/sf-ship SPEC-ID` (manual mode: red tests await human approval; autonomous
   mode: `/sf-loop` uses an independent PASS receipt).
3. If any spec is `done` and its feature branch still exists, recommend
   `/sf-review SPEC-ID` then `/sf-finalize SPEC-ID` (manual mode: implementation
   awaits final review; autonomous mode: `/sf-loop` requires an independent
   PASS receipt and runs finalize with `--autonomous`).
4. For the first `approved` spec (in DESIGN-table order) whose dependencies
   are all satisfied, recommend `/sf-test SPEC-ID`. A dependency is satisfied
   only when it is `done` **and merged** — done on an unmerged feature branch
   does not count, because the dependent spec's branch cannot see that work.
5. If any spec is still `draft`, recommend `/sf-plan` (the design bundle is
   not approved yet).
6. If every spec is `done` with no branches left, recommend `/sf-plan` to
   archive this iteration and start the next (NEXT.md is the queued brief if
   present).

**Loop mode**: When `/sf-loop` is active, independent
reviewer sub-agents handle `tests-red`, `done`, and task transitions by writing
PASS receipts in `.specforge/reviews/`. Missing receipts, stale heads, or any
verdict other than exact `VERDICT: PASS` stop the loop. `/sf-review SPEC-ID`
remains available at any time for manual inspection.

## Rules

- Read-only: no edits, no branch switching, no finalization.
- Do not summarize away warnings the scripts print.
- `implemented` is a legacy state: a ship session stopped mid-handoff. Say so
  and recommend ticking the SPEC checkboxes, setting `State: done`, and
  committing.
- Tasks are orthogonal to specs and the decision ladder. An open task does not
  block spec work; it runs on its own branch and merges independently via
  `/sf-task`.
