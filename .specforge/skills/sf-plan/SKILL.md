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

### State 0 — Approved plan with unfinished SPECS

If ALIGN.md, DESIGN.md, and one or more SPECS are approved, and at least one
active SPEC is not done, the current iteration is still active. Do not revise
approved plan artifacts.

- If the human brought a new requirement, act as the **SpecForge Framer**:
  write or update `.specforge/NEXT.md` with the future requirement, why it
  matters, known non-goals, and any timing/priority notes. Then stop and tell
  the human which active SPEC remains next.
- If there is no new requirement, report the next active SPEC action from
  `sf-snapshot.sh`.

Stop. Do not align or design a new requirement into the active iteration.

### State 1 — Approved plan with all SPECS done

If ALIGN.md, DESIGN.md, and one or more SPECS are approved, and every active
SPEC is done, the current iteration is complete.

You are now the **SpecForge Framer**. Your job is to choose the next iteration
focus, not to design it.

1. Read the completed ALIGN.md, DESIGN.md, SPECS, and `.specforge/NEXT.md` if it
   exists.
2. Ask focused questions until the next iteration has:
   - target outcome
   - affected users/systems
   - priority/rationale
   - constraints
   - explicit non-goals
   - any queued requirements or follow-ups to include
3. Write `.specforge/NEXT.md` as a short brief with those sections:
   ```markdown
   # Next iteration

   **Status:** draft
   **Iteration:** ITER-YYYYMMDD-HHMMSS

   ## Focus
   <target outcome>

   ## Rationale
   <why this is next>

   ## Users / systems
   - <affected user or system>

   ## Constraints
   - <known constraint>

   ## Non-goals
   - <explicitly out>

   ## Queued requirements
   - <requirement or follow-up>
   ```
4. When the human confirms the brief, run:
   ```bash
   bash .specforge/scripts/sf-iteration.sh archive-reset
   ```
5. Tell the human:

> Next iteration framed and previous iteration archived. End this session and
> run `/sf-plan` in a new session to create ALIGN.md from NEXT.md.

Stop. Do not continue to alignment in this session.

### State 2 — Alignment (ALIGN.md missing or not approved)

You are now the **SpecForge Aligner**. Read `.specforge/agents/aligner.md` for
your full operating procedure and follow it.

When the human approves ALIGN.md, set `**Status:** approved`, then tell them:

> ALIGN.md approved. End this session and run `/sf-plan` in a new session to
> continue with design.

Stop. Do not continue to design in this session.

### State 3 — Design (ALIGN.md approved, DESIGN.md/SPECS missing or not approved)

You are now the **SpecForge Designer**. Read `.specforge/agents/designer.md`
for your full operating procedure and follow it.

When the human approves the design bundle, set `**Status:** approved` on
DESIGN.md, then tell them:

> Design approved. End this session. Open a new session per SPEC and run
> `/sf-test SPEC-ID` in dependency order.

Use the stable SPEC ID in phase commands. A slugged file such as
`.specforge/specs/SPEC-009-frequency-record.md` is invoked as `SPEC-009`, and
its feature branch is `feature/SPEC-009`.

Stop.

### State 4 — Plan complete (ALIGN.md and DESIGN.md both approved)

Tell the human:

> Plan is complete. Run `/sf-test SPEC-ID` for each SPEC in dependency order
> (see DESIGN.md SPECS table).

If a SPEC file is slugged, use its stable ID in commands: `SPEC-009` for
`.specforge/specs/SPEC-009-frequency-record.md`.

## Rule

Do not write tests or implementation during Plan. Human approval of each phase
artifact is the gate before the next phase.

Never mix new requirements into an approved active iteration with unfinished
SPECS. Queue them in NEXT.md for the next iteration unless the human explicitly
asks to abandon or re-plan the active iteration.

Active ALIGN.md, DESIGN.md, NEXT.md, and SPEC files must share the same
`**Iteration:** ITER-...` value. Use `.specforge/REGISTRY.md` to identify
implemented requirements; changed implemented requirements must be new `REQ-*`
IDs that supersede old IDs.
