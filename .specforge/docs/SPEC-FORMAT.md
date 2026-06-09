# How to write a SPEC

A SPEC is the contract for one feature. The builder reads it, follows it literally, ticks the boxes. If a SPEC is ambiguous, the build is wrong.

## File location

Prefer `.specforge/specs/SPEC-{NNN}-{slug}.md`, for example
`.specforge/specs/SPEC-009-frequency-record.md`. One file per feature.

Commands use the stable SPEC ID (`SPEC-009`) and resolve either
`.specforge/specs/SPEC-009.md` or `.specforge/specs/SPEC-009-<slug>.md`.
Branch names also use the stable ID: `feature/SPEC-009`, not the filename slug.

## Template

```markdown
# SPEC-{NNN}: <Title>

**Traces to:** .specforge/ALIGN.md § "<section>" | .specforge/DESIGN.md § "<section>"
**Status:** draft | approved
**Iteration:** ITER-YYYYMMDD-HHMMSS
**Build state:** not-started | tests-red | implemented | done
**Branch:** feature/SPEC-{NNN}

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

## Status flow

```
draft -> approved -> tests-red -> done
```

- `draft` — designer is working on it
- `approved` — human has signed off; Test can start
- `tests-red` lives in `Build state`, not `Status`
- Ship updates checkboxes after implementation passes
- when all checkboxes are ticked, the spec is effectively done

## Build state

`Build state` is a small human-readable sub-state for the Test and Ship cycle:

- `not-started` — no tests or implementation have started
- `tests-red` — tests were written and confirmed failing; human test review is required before implementation
- `implemented` — implementation exists and tests are passing, but handoff is not complete
- `done` — all acceptance criteria, tests, and implementation checkboxes are ticked

The builder updates this field as it works. `tests-red` is a human review gate; the builder does not implement until the tests are approved. The field does not replace the checkboxes.

## Ticking checkboxes

The builder ticks boxes as it works. Format:
- `- [x]` = done, passing test
- `- [ ]` = pending, or skipped (with human approval)

A SPEC is "done" when every acceptance-criteria box is ticked AND every Tests and Implementation box is ticked. `bash .specforge/scripts/sf-snapshot.sh` reads these.

## Requirement traceability

Run this to see which requirements were implemented:

```bash
bash .specforge/scripts/sf-trace.sh
```

or:

```bash
sf trace
```

The trace report is generated from active SPEC files and archived iteration
SPEC files. It also refreshes `.specforge/REGISTRY.md` and
`.specforge/registry.json`, which are generated indexes for human and script
consumption.

Registry status meanings:

- `active` — requirement is in the current active iteration and is not done.
- `implemented` — requirement is done and remains part of product history.
- `superseded` — requirement was implemented, but a later requirement replaces
  or changes its behavior.

The registry is generated state. Do not edit it directly; edit SPECS and rerun
`sf trace`.

## SPEC linting

Run this before approving design or handing off a build:

```bash
bash .specforge/scripts/sf-lint-specs.sh
```

or:

```bash
sf lint
```

The linter checks for required metadata, stable requirement IDs, test coverage mappings, the 8-AC limit, and implementation checked before tests.

Before handing off a completed build, run:

```bash
bash .specforge/scripts/sf-verify-build.sh SPEC-ID
```

The verifier resolves `SPEC-ID` to either `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`, then checks the approved SPEC, branch
metadata, completed checkboxes, SPEC lint, and the configured test command(s).

To inspect red tests or the final implementation diff, run:

```bash
bash .specforge/scripts/sf-review.sh SPEC-ID
```

or:

```bash
sf review SPEC-ID
sf review SPEC-ID --patch
```

Review accepts the same stable `SPEC-ID` resolver forms as verification.

After reviewing the final implementation diff, finalize the spec:

```bash
bash .specforge/scripts/sf-finalize.sh SPEC-ID
```

The finalizer reruns verification, fast-forward merges the feature branch into the base branch, and deletes the feature branch.

## Editing a SPEC after approval

Minor edits (typo, clearer wording): just edit and commit on the feature branch. Tell the human in the hand-off.

Material edits (new AC, changed behavior, removed scope): STOP. Re-run `/sf-plan`, re-approve. Don't silently expand the spec mid-build.

Material edits to already implemented requirements are not made in place. Start
a new iteration, create a new `REQ-*` ID, and link the old ID in
`## Supersedes`.
