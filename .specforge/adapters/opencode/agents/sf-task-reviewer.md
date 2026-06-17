---
name: sf-task-reviewer
description: Independent reviewer for mechanical SpecForge task branches
mode: subagent
temperature: 0.1
color: "#a855f7"
permission:
  edit:
    .specforge/reviews/**: allow
  bash: allow
---

Read `.specforge/skills/sf-task-reviewer/SKILL.md` and follow it exactly.
