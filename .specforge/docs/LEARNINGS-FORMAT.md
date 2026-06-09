# LEARNINGS Format

Learnings live in `LEARNINGS.md` at the project root. Each entry is a chronological append.

Create `LEARNINGS.md` lazily — only when you have something to write. Don't create it empty.

## Template

```md
## YYYY-MM-DD — SPEC-ID (or area if no SPEC)
**Finding**: One sentence summarising what was learned.
**Why it matters**: Why this saves time or prevents errors.
**Trigger**: What exposed it (e.g., "REQ-AUTH-003 test passed unexpectedly").
```

That's it. An entry can be three lines. The value is in recording *that* this happened and *why* it matters — not in filling out sections.

## When to write a LEARNING

All three must be true:

1. **It would surprise a future agent.** A reasonable agent reading the code would not know this.
2. **It is not derivable from existing docs.** Not in the SPEC, not in `CONTEXT.md`, not in `docs/adr/`, not obvious from `git log`.
3. **It cost time to discover OR would save time to know in advance.** If it was instant and trivial, skip it.

## What qualifies

- A test that passed when it should have failed — exposing that the feature already existed or was tested elsewhere.
- A system behavior that contradicted the SPEC — e.g., an API returning a different shape than documented.
- A hidden coupling discovered mid-implementation — e.g., changing X silently breaks Y.
- An edge case that required a significant rethink — not a minor bug fix.
- A constraint that was invisible until the code ran — e.g., a database column limit, a rate limit, a timezone issue.
- A repeating pattern of false assumptions — if the same wrong assumption came up twice, record it.

## What does NOT qualify

- Things derivable from the SPEC or acceptance criteria.
- Normal implementation steps — these belong in the SPEC checkboxes.
- Architectural decisions — those go in `docs/adr/`.
- Domain vocabulary — that goes in `CONTEXT.md`.
- Effort or time estimates — LEARNINGS.md is not a retrospective.
- Passing observations or minor style notes.

## Numbering and ordering

Entries are append-only, newest at the bottom. Do not re-order or delete entries. If a learning becomes stale, add a follow-up entry noting it rather than editing the original.
