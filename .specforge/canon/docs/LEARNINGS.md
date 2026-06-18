# SpecForge learnings

Durable findings worth remembering across work items — the things that surprised
an agent, cost time to discover, or would save time next session. This is the
successor to v1's single `LEARNINGS.md`: now a small, grep-able store of one file
per learning, with an always-loaded index for cheap recall.

## Where it lives

```
.specforge/learnings/
  INDEX.md              one line per learning (area | file | finding) — loaded at start
  <short-slug>.md       one learning, with frontmatter
  ...
```

Project-owned: `sf update` never touches it. Seeded empty by `sf init`.

## Anatomy of one learning

`.specforge/learnings/<short-slug>.md` — `<short-slug>` is kebab-case and describes
the finding (`tz-offset-truncates`, `ff-merge-needs-rebase`), not the work item.

```md
---
area: testing            # one of: testing | git | build | architecture | tooling | domain | <yours>
date: 2026-06-18
tags: [time, sqlite]     # optional free-form keywords for grep
source: <slug>           # optional: the work item that surfaced it
---
**Finding:** One sentence — what was learned.
**Why it matters:** Why this saves time or prevents errors.
**Trigger:** What exposed it (e.g. "REQ-x test passed unexpectedly").
```

Three lines of body is plenty. The value is recording *that* it happened and *why*
it matters — not filling sections.

## The index

`INDEX.md` carries one line per learning so a reader can find the right file
without opening every entry. Newest at the bottom, append-only:

```
- testing | tz-offset-truncates.md | SQLite stores TZ-naive datetimes; UTC assertions silently pass
```

When you add a learning file, add its index line in the same commit. The line's
`area` and finding text are what `grep` matches against — keep the finding
self-describing.

## Recall — pulling the relevant ones into a task

1. **At the start of a loop/session**, read `INDEX.md` (cheap — one screen).
2. **Per work item**, `grep` the index by the SPEC's area and its key nouns
   (e.g. `grep -iE 'sqlite|time|testing' .specforge/learnings/INDEX.md`).
3. Open only the matching entry files and fold them into the item's
   `WORK.md` (or the worker's brief) so the builder sees them inline. Do not load
   the whole store.

If nothing matches, that's fine — proceed with no learnings.

## When to write one

All three must hold:

1. **It would surprise a future agent.** A reasonable agent reading the code would
   not know this.
2. **It is not derivable from existing docs** — not in the SPEC, DESIGN, project
   config, or obvious from `git log`.
3. **It cost time to discover OR would save time to know in advance.** If it was
   instant and trivial, skip it.

### Qualifies
- A test that passed when it should have failed (the feature already existed / was
  tested elsewhere).
- System behavior that contradicted the SPEC (an API returned a different shape).
- A hidden coupling found mid-implementation (changing X silently breaks Y).
- A constraint invisible until the code ran (a column limit, a rate limit, a TZ issue).
- A wrong assumption that has now come up twice.

### Does NOT qualify
- Anything derivable from the SPEC or acceptance criteria.
- Normal implementation steps — those are SPEC checkboxes.
- Architectural decisions — those belong in the DESIGN.md / an ADR.
- Effort or time estimates, passing observations, minor style notes.

## Who writes, and when

The agent that **discovers** the surprise writes the learning — a plain file
append, so it raises no "grades its own homework" concern. In practice:

- The **implementer** or **test-author** hits most surprises mid-build; either may
  add a file + index line before committing.
- The **verifier**, with fresh eyes on the whole diff, records anything the author
  missed.
- The **coordinator** ensures recall happened at the start and that any learning
  surfaced in a worker's `RESULT` made it into the store.

Append-only: don't reorder or rewrite past entries. If a learning goes stale, add a
new entry that supersedes it rather than editing the original.
