---
name: sf-status
description: Show current SpecForge phase and per-SPEC status table. Use when the user asks about project status, current phase, which SPECs are in progress, what's done, or what to work on next.
---

# /sf-status — See where you are

> **Fresh session.** Quick check. Reads disk, prints a table, ends.

You are checking the current state of the project.

SPEC files may be named either `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`. Commands should use the stable SPEC ID
when known; branch names also use the stable ID, for example `feature/SPEC-009`
for `.specforge/specs/SPEC-009-frequency-record.md`.

## What you do

1. Run:
   ```bash
   bash .specforge/scripts/sf-snapshot.sh
   ```
2. Show the output. It prints phase status plus one line per SPEC with checkbox counts.
3. Also check `.specforge/ALIGN.md` and `.specforge/DESIGN.md` Status lines. Report:
   - Is ALIGN.md approved? (yes/no)
   - Is DESIGN.md approved? (yes/no)
   - Is NEXT.md present with queued next-iteration requirements? (yes/no)
   - What is the active Iteration ID?
   - What does the registry report for active, implemented, and superseded requirements?
   - How many SPECS exist? How many are fully checked?
4. When the human asks about requirement traceability, run the requirement trace report script and show its output.
5. After the summary, emit one **Next action** line based on the current state:
   - No ALIGN.md → `Next: /sf-plan`
   - ALIGN.md present but not approved → `Next: /sf-plan (ALIGN.md needs approval)`
   - ALIGN.md approved, no DESIGN.md → `Next: /sf-plan (continue to design)`
   - DESIGN.md approved, at least one SPEC `not-started` → `Next: /sf-test <first not-started SPEC in dependency order>`
   - Any SPEC `tests-red` → `Next: /sf-review <SPEC-ID> then /sf-ship <SPEC-ID>`
   - Any SPEC `implemented` → `Next: /sf-review <SPEC-ID> then /sf-finalize <SPEC-ID>`
   - All SPECs `done` and NEXT.md missing → `Next: all done — run /sf-plan to frame the next iteration`
   - All SPECs `done` and NEXT.md present → `Next: all done — run /sf-plan to confirm queued next iteration`

## Output format

```
ALIGN.md: <status>
DESIGN.md: <status>
NEXT.md: <missing|queued>
Iteration: <ITER-ID|none>
Registry: <N> active, <N> implemented, <N> superseded

SPEC      TESTS      IMPL       AC          BRANCH
----      -----      ----       --          ------
SPEC-001  3/3        3/3        5/5         feature/SPEC-001
SPEC-002  1/2        0/1        2/4         feature/SPEC-002
...

Summary: 1 done, 1 in progress, 0 not started
```

That's it. No phase gates, no machine state - just disk artifacts and checkboxes.

To inspect one spec's changes, run:

```bash
bash .specforge/scripts/sf-review.sh SPEC-ID
```
