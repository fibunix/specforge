---
id: sf-align
summary: Run the alignment phase for a work item (produces ALIGN.md)
side_effects: true
---

# /sf-align <slug> — alignment phase

Spawn the `aligner` agent for `<slug>` (or the active item). It writes
`work/active/<slug>/ALIGN.md` capturing only the load-bearing unknowns, asking
focused questions one at a time. This is the first half of Gate 1: present
ALIGN.md and get human approval before design.

Skip alignment when the request is already unambiguous — say so rather than
inventing uncertainty.
