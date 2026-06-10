# How to write a SPEC

A SPEC is the contract for one feature. The builder reads it, follows it literally, ticks the boxes. If a SPEC is ambiguous, the build is wrong.

## File location

Prefer `.specforge/specs/SPEC-{NNN}-{slug}.md`, for example
`.specforge/specs/SPEC-009-frequency-record.md`. One file per feature.

Commands use the stable SPEC ID (`SPEC-009`) and resolve either
`.specforge/specs/SPEC-009.md` or `.specforge/specs/SPEC-009-<slug>.md`.
Branch names also use the stable ID: `feature/SPEC-009`.

## Template

```markdown
# SPEC-{NNN}: <Title>

**Traces to:** .specforge/ALIGN.md § "<section>" | .specforge/DESIGN.md § "<section>"
**State:** draft | approved | tests-red | done
**Iteration:** ITER-NNN-<slug>

## Description

<1-3 paragraphs. What this feature does, who uses it, why it exists. No code.>

## Acceptance criteria

- [ ] REQ-<AREA>-001: <observable, testable outcome>
- [ ] REQ-<AREA>-002: <observable, testable outcome>
- [ ] REQ-<AREA>-003: <observable, testable outcome>

## Tests

- [ ] tests/<path>/<file>.test.<ext>  (covers REQ-<AREA>-001, REQ-<AREA>-002)
- [ ] tests/<path>/<file>.test.<ext>  (covers REQ-<AREA>-003)

## Implementation

- [ ] src/<path>/<file>.<ext>
- [ ] src/<path>/<file>.<ext>

## Supersedes

- <optional: REQ-OLD-001 -> REQ-NEW-001>

## Design notes

<1-3 lines. Link to the relevant section of DESIGN.md. Note any non-obvious decisions.>
```

## Rules for good SPECS

- **One feature per SPEC.** If your spec has two distinct features, split it.
- **Max 8 ACs.** More than that = split. Builders lose focus, tests get bloated.
- **ACs are observable.** "User can register" is observable. "Code is well-organized" is not.
- **ACs are testable.** Every AC must map to at least one test. If you can't write a test for it, it's not an AC.
- **ACs are independent.** If `REQ-AUTH-003` only makes sense after `REQ-AUTH-001` is built, merge them.
- **Requirement IDs are stable.** Use IDs like `REQ-AUTH-001`, not local-only labels like `AC-1`. Tests reference these IDs in their `(covers ...)` clause.
- **Implemented requirements are immutable.** If behavior changes after a
  requirement is done, create a new `REQ-*` ID and link the old one in
  `## Supersedes`.
- **Iteration IDs are required.** Every active SPEC must include
  `**Iteration:** ITER-...` so active work can be separated from archives.
  IDs are sequential and named: `ITER-NNN-<slug>` (the Aligner assigns them
  via `sf-iteration.sh next-id <slug>`).
- **Test files are listed in the SPEC.** The builder creates exactly these files. If a new test is needed mid-build, the human updates the SPEC.
- **Implementation files are listed in the SPEC.** Same logic — keeps the work bounded.
- **No code in the SPEC.** The SPEC describes *what*; the builder writes *how*.

## Good vs. bad ACs

| Bad | Good |
|-----|------|
| "User can register" | "REQ-AUTH-001: Submitting valid email + password creates a new account and returns a 201" |
| "Login is fast" | "REQ-AUTH-002: Login completes in under 200ms at p95 on the dev machine" |
| "Code is clean" | (not an AC — throw it out) |
| "Handles edge cases" | "REQ-AUTH-003: Submitting an empty email shows the error 'Email is required' inline" |

## State lifecycle

This section is the normative statement of the lifecycle. Other docs link
here; if another file disagrees, this one wins.

```
draft -> approved -> tests-red -> done
```

Each transition has exactly one owner:

- `draft` — the Designer is working on it.
- `draft -> approved` — the **Designer** sets this when the human approves the
  design bundle. It records the Plan gate on disk; builders and wave planning
  trust it.
- `approved -> tests-red` — the **Builder** sets this during `/sf-test`, after
  tests are written, confirmed failing for the expected reason, and committed.
  `tests-red` is a human review gate; the builder does not implement until the
  tests are approved (running `/sf-ship` is the approval signal).
- `tests-red -> done` — the **Builder** sets this during `/sf-ship`, after the
  tests pass and every acceptance-criteria, Tests, and Implementation checkbox
  is ticked.

The state field does not replace the checkboxes.

Legacy fields are read but should be migrated; `sf lint` warns on each:

- Separate `**Status:**` / `**Build state:**` fields → replace both with a
  single `**State:**` field using the equivalent value.
- `**State:** implemented` (an old intermediate between tests-red and done) →
  it meant "tests pass but checkboxes/commit incomplete"; finish the handoff
  and set `done`.

## Ticking checkboxes

The builder ticks boxes as it works. Format:
- `- [x]` = done, passing test
- `- [ ]` = pending, or skipped (with human approval)

A SPEC is "done" when every acceptance-criteria box is ticked AND every Tests and Implementation box is ticked. `bash .specforge/scripts/sf-facts.sh` reads these.

## Parsing contract

Scripts read only `**State:**` and `**Iteration:**`; everything else in a spec
is for humans and agents. (Checkbox counts are tallied for display and the
done-gate, and `sf lint` checks the contract shape — but no script makes a
decision from any other field.) Evolving the format costs a sentence in this
doc, not an awk rewrite.

## Requirement traceability

Traceability questions are retrieval questions; ask the agent, or grep the
spec files yourself:

```bash
grep -rn "REQ-AUTH-002" .specforge/specs/ .specforge/iterations/*/specs/
```

Requirement status is derived from where the ID lives:

- **active** — in a current `.specforge/specs/` file that is not done.
- **implemented** — in a done spec (active or archived); part of product
  history.
- **superseded** — listed on the left side of a `## Supersedes` entry in a
  later spec.

## SPEC linting

```bash
sf lint
```

The linter checks for required metadata, stable requirement IDs, test coverage mappings, the 8-AC limit, implementation checked before tests, and cross-spec file overlap.

Before handing off a completed build, run:

```bash
sf verify SPEC-ID
```

After reviewing the final implementation diff, finalize the spec:

```bash
sf finalize SPEC-ID
```

## Editing a SPEC after approval

Minor edits (typo, clearer wording): just edit and commit on the feature branch. Tell the human in the hand-off.

Material edits (new AC, changed behavior, removed scope): STOP. Re-run `/sf-plan`, re-approve. Don't silently expand the spec mid-build.

Material edits to already implemented requirements are not made in place. Start
a new iteration, create a new `REQ-*` ID, and link the old ID in
`## Supersedes`.
