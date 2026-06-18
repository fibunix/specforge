---
name: sf
description: Smart entry point. Give it a request in plain language and it picks the right lane — mechanical task, quick spec, or full plan — and dispatches. Use this when you are not sure which /sf-* command to run.
---

# /sf — smart router

> `/sf "<request>"` is the one entry point. It classifies the request and routes
> to the right lane so you do not have to choose. Explicit commands
> (`/sf-task`, `/sf-quickspec`, `/sf-plan`) remain available as overrides.

You hold minimal context. Do not inspect the codebase yourself — that read-heavy
judgment goes to a fresh sub-agent so your context stays thin.

## Step 1 — classify (fresh sub-agent)

Run `bash .specforge/scripts/sf-facts.sh` for current state, then spawn a fresh
**classifier** sub-agent with the request and the facts. Tell it to inspect the
request and the relevant code only as needed and return exactly one verdict —
`task`, `quick-spec`, or `full-plan` — with a one-line justification. Rubric:

- **task** — purely mechanical, no new behavior, scope obvious from the request
  (rename, delete dead code, update a config value, fix a typo, add an import).
- **quick-spec** — introduces or changes behavior, BUT one component, no
  architecturally-significant decision, no schema / public-API change, testable
  in a handful of cases, no cross-spec dependencies.
- **full-plan** — ambiguity, multiple viable designs, cross-cutting / API /
  schema impact, more than one spec — **or the classifier is unsure**.

Bias: **escalate up, never down.** When a request sits on a boundary, pick the
heavier lane. Unsure ⇒ `full-plan`.

## Step 2 — dispatch

- `task` → follow `.specforge/skills/sf-task/SKILL.md` for the request.
- `quick-spec` → follow `.specforge/skills/sf-quickspec/SKILL.md` for the request.
- `full-plan` → follow `.specforge/skills/sf-plan/SKILL.md`.

Report the chosen lane and the one-line justification, then proceed. If the user
disagrees, they can invoke the explicit command for the lane they want.

## Rules

- Never do the classification inline in your own context — always a fresh
  sub-agent. Carry only its verdict forward.
- Routing is a suggestion the lane can revisit: e.g. the quick-designer may still
  bounce a request up to `/sf-plan` once it looks closely.
