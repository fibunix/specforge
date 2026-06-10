---
name: sf-plan
description: Run the SpecForge Plan phase — alignment session, design, and SPEC file generation. Use when the user wants to plan a feature, start a new SpecForge workflow, or asks to create the shared understanding and design docs.
---

# /sf-plan - plan the work

Plan produces the approved understanding, design, and SPEC files before any
tests or implementation. Each invocation routes to exactly one state so fresh
sessions can resume from disk without guessing.

## What you do

1. Check current state:
   ```bash
   bash .specforge/scripts/sf-snapshot.sh
   ```

2. **Route to exactly one state based on disk state:**

### State 0 — Active iteration with unfinished specs

If one or more active SPECs are not yet `done`, the current iteration is still
active. Do not revise approved plan artifacts.

- If the human brought a new requirement, queue it in `.specforge/NEXT.md`
  using the format in `.specforge/templates/NEXT.md` — one bullet per
  requirement (what + why + priority). Append to the existing file rather than
  overwriting earlier queued bullets. NEXT.md carries no `**Iteration:**`
  field. Then stop and tell the human which active SPEC remains next.
- If there is no new requirement, report the next active SPEC action from
  `sf-snapshot.sh` (it prints a `Next:` line).

**If the human explicitly asks to abandon or re-plan the active iteration:**

1. Confirm: "This will archive the current iteration as abandoned and reset
   the plan artifacts. Any unfinished SPECs will be preserved in the archive
   but removed from the active workspace. NEXT.md is kept. Proceed?"
2. On confirmation, run:
   ```bash
   bash .specforge/scripts/sf-iteration.sh archive-reset --abandon
   ```
3. Continue to State 1b — the human wants to start a new alignment session.

Stop. Do not align or design a new requirement into the active iteration unless
the human explicitly requested the abandon path above.

### State 1a — Iteration complete, archive first

If all active specs are `done` (per the snapshot):

1. Run:
   ```bash
   bash .specforge/scripts/sf-iteration.sh archive-reset
   ```
   This archives the completed artifacts under the completed iteration's own
   ID, writes a SUMMARY.md close-out, keeps `.specforge/NEXT.md` in place as
   the next iteration's brief, and resets ALIGN.md/DESIGN.md/SPECs.
2. Continue to State 1b.

### State 1b — Need alignment

If ALIGN.md is missing or not yet approved:

You are now the **SpecForge Aligner**. Read `.specforge/agents/aligner.md` for
your full operating procedure and follow it.

The Aligner reads `.specforge/NEXT.md` as the starting brief if it exists. It
will reflect the brief back and ask only for missing load-bearing details. If
there is no NEXT.md, it will ask open-ended questions to establish the focus,
users, success criteria, scope, constraints, and non-goals. It assigns the new
iteration's ID (`sf-iteration.sh next-id <slug>`).

**When the human says ALIGN.md is approved, you edit the file:** set
`**Status:** approved` on ALIGN.md. The human approves; you write the field.
Once the new ALIGN.md is approved, delete the queued bullets it consumed from
NEXT.md (or the whole file if nothing remains queued).

If this session has already been long (multi-turn alignment discussion), tell
the human:

> ALIGN.md approved. If this conversation is already long, end it and run
> `/sf-plan` in a new session to continue with design — disk has everything.
> Otherwise, continue directly.

Stop at alignment. Do not continue to design unless the human explicitly
continues in the same session.

### State 2 — ALIGN approved, design needed

If ALIGN.md is `approved` and DESIGN.md or SPECs are missing or not approved:

You are now the **SpecForge Designer**. Read `.specforge/agents/designer.md`
for your full operating procedure and follow it.

**When the human approves the design bundle, you record it on disk:**

1. Set `**Status:** approved` on DESIGN.md.
2. Set `**State:** approved` on every SPEC file in the bundle.

This is the only place specs move from `draft` to `approved` — builders and
`sf wave` trust these fields. Then tell the human:

> Design approved. Open a new session per SPEC and run `/sf-test SPEC-ID` in
> dependency order.

Use the stable SPEC ID in phase commands. A slugged file such as
`.specforge/specs/SPEC-009-frequency-record.md` is invoked as `SPEC-009`, and
its feature branch is `feature/SPEC-009`.

Stop.

### State 3 — Plan complete

If ALIGN.md and DESIGN.md are both `approved` and at least one SPEC exists:

Tell the human:

> Plan is complete. Run `/sf-test SPEC-ID` for each SPEC in dependency order
> (see DESIGN.md SPECS table), or `sf wave` to see which specs can run in
> parallel.

## Rule

Do not write tests or implementation during Plan. Human approval of each phase
artifact is the gate before the next phase.

Never mix new requirements into an approved active iteration with unfinished
SPECs. Queue them in NEXT.md for the next iteration unless the human explicitly
asks to abandon or re-plan the active iteration.

Active ALIGN.md, DESIGN.md, and SPEC files must share the same
`**Iteration:** ITER-...` value; `sf lint` errors if they diverge. NEXT.md is
the exception — it describes the next iteration and carries no Iteration field.
Use `.specforge/REGISTRY.md` to identify implemented requirements; changed
implemented requirements must be new `REQ-*` IDs that supersede old IDs.
