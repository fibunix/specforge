---
id: sf-design
summary: Run the design phase for a work item (produces SPEC.md, maybe DESIGN.md)
side_effects: true
---

# /sf-design <slug> — design phase

Spawn the `designer` agent for `<slug>`. It writes `SPEC.md` (always) and a
`DESIGN.md` only when the work crosses components, adds a data shape, or has a live
decision. This is **Gate 1**: present the plan and get explicit human approval.

On approval, create the feature branch: `sf worktree create <slug>`. Do not create
branches before approval — branch existence is the approval record.
