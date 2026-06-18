# SpecForge

This project uses **SpecForge** — a thin, agent-driven harness for spec-first work.
The rule above all: **no agent grades its own homework.** The agent that writes
tests never writes the implementation, and a separate agent verifies both.

## Two lanes
- **direct** — mechanical change, no new observable behavior (rename, dead-code
  delete, config/dep bump, typo). One implementer + one verifier. No spec, no
  human gate. Self-validates on green tests + verifier sign-off.
- **spec** — any new or changed behavior. Produces a `SPEC.md` (and a `DESIGN.md`
  only if the work crosses components, adds a data shape, or has a live decision).

Route by one question: *does this change observable behavior?* No → direct.
Yes → spec. When unsure, escalate up.

## Roles (subagents)
`coordinator` (conductor) · `aligner` → `designer` (the human-gated design phase)
· `test-author` → `implementer` → `verifier` (the build, with fresh eyes between).

## State is observed, not stored
There is no state field. State is derived from git + filesystem:
work dir in `work/active/<slug>/`, branch `feature/<slug>`, the red-tests commit,
a `Verified-by:` trailer on HEAD, and (when done) a move to `work/archive/`.
Run `sf status` for the facts.

## Two human gates only
- **G1 approve the plan** — after SPEC (+ optional DESIGN), before any branch.
- **G2 approve the merge** — after the verifier signs off, before `sf merge`.
The direct lane has zero gates.

## The one guardrail
`sf merge <slug>` refuses unless tests are green AND HEAD carries a `Verified-by:`
trailer. Everything reversible (planning/testing/implementing) is unguarded.

## CLI (deterministic essentials only)
`sf status` · `sf worktree create <slug>` · `sf test` · `sf merge <slug>` ·
`sf init` · `sf update` · `sf doctor`. Everything else is a skill/agent.

## Entry points (skills)
`/sf "<request>"` route & drive · `/sf-loop` autonomous coordinator ·
`/sf-align` · `/sf-design` · `/sf-build` · `/sf-status`.

Artifacts live in `work/active/<slug>/` (WORK.md, ALIGN.md?, DESIGN.md?, SPEC.md).
Config is `project.yaml`. Backlog is `NEXT.md`.
