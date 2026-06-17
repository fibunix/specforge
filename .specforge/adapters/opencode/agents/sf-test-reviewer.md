---
name: sf-test-reviewer
description: Independent reviewer for tests-red SpecForge branches
mode: subagent
temperature: 0.1
color: "#0ea5e9"
permission:
  edit:
    .specforge/reviews/**: allow
  bash: allow
---

Read `.specforge/skills/sf-test-reviewer/SKILL.md` and follow it exactly.
