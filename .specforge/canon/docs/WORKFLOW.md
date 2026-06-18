# SpecForge workflow reference

This is the long-form reference. The short contract lives in your project's
`AGENTS.md`/`CLAUDE.md` managed block. Editors without programmatic subagents
(Codex, Pi, Antigravity) read this file for the full procedure.

## The core principle

Fresh-eyes verification. Three guarantees, enforced by *sequencing through git*,
not by a script:

1. The **test-author** commits failing tests before any implementation exists.
2. The **implementer** is a separate agent that treats those committed tests as a
   fixed contract — it never edits tests, and never saw the test-author's reasoning.
3. The **verifier** is a third agent that reviews a diff it did not author and is
   blind to the author's reasoning. On approval it appends a `Verified-by:` trailer.

## Lanes

**direct** (mechanical, no new behavior): create a worktree, make the change, run
tests, have a verifier check it's mechanical and green, sign off, merge. No SPEC,
no human gate.

**spec** (new/changed behavior):
1. *(optional)* **align** — when the request is fuzzy, the aligner writes
   `work/active/<slug>/ALIGN.md` (problem, success criteria, out-of-scope, open
   questions). Human approves.
2. **design** — the designer writes `SPEC.md` (always) and `DESIGN.md` (only when
   the work crosses components, adds a data shape, or has a live decision).
   **Human approves the plan — Gate 1.** Approval = `sf worktree create <slug>`.
3. **tests (red)** — test-author writes failing tests, commits `<slug>: red tests`.
4. **implement** — implementer makes them green, commits.
5. **verify** — verifier reviews tests-then-impl, appends `Verified-by:` on pass.
6. **merge** — **Human approves — Gate 2** — then `sf merge <slug>` (guardrail:
   green tests + trailer), which archives the item to `work/archive/<date>-<slug>/`.

## State (derived, never stored)

| State | Observed by |
|-------|-------------|
| planning | `work/active/<slug>/` exists, no `feature/<slug>` branch |
| ready | branch created (= Gate 1 approval) |
| tests-red | HEAD commit subject contains "red tests"; tests fail |
| implementing | commits past red tests; no trailer yet |
| verified | HEAD has a `Verified-by:` trailer |
| done | moved to `work/archive/` |

`sf status` prints all of this. It enforces nothing.

## Verification phases (what the verifier checks)

- **tests** — every acceptance criterion has a real test; assertions are genuine;
  tests fail for the *expected missing behavior*; the diff is tests-only.
- **impl** — all tests green; criteria actually satisfied (not gamed); diff stays
  within declared files; tests were not modified to pass.
- **task** (direct lane) — change is still mechanical; diff matches the request;
  tests stay green.

On a fail, a *fresh* agent of the same phase reworks with the findings. Bounded to
**2 rework attempts per (item, phase)**, then escalate to a human.

## Escalation

There is no magic stop-string. The loop ends when no item can advance (idle), or
escalates as data (`needs_human` + reason: design decision / rework limit /
ambiguity / external blocker). Always escalate immediately on: a design ambiguity
surfaced mid-build, an author that declares itself blocked, or a verifier-flagged
scope/contract change that wasn't in the approved design.

## Editors without programmatic subagents

On Claude Code the coordinator spawns subagents via the Task tool. On Codex,
OpenCode, Pi, and Antigravity, "fresh context" is achieved by **session
boundaries**: run one role per session (e.g. invoke the test-author agent, then in
a new session invoke the implementer, then the verifier). The role files and the
fresh-eyes guarantee are identical; only auto-parallelism and zero-touch looping
are lost.
