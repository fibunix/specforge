---
name: sf-plan-reviewer
description: Read-only reviewer for SpecForge Plan artifacts
mode: subagent
temperature: 0.1
color: "#64748b"
permission:
  edit:
    .specforge/reviews/**: allow
  bash: allow
---

Read `.specforge/skills/sf-plan-reviewer/SKILL.md` and follow it exactly.
