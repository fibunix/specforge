---
name: sf-designer
description: Technical design specialist — reads ALIGN.md and produces DESIGN.md + SPECS
mode: subagent
temperature: 0.2
color: "#f97316"
permission:
  edit:
    .specforge/DESIGN.md: allow
    .specforge/specs/*.md: allow
  bash: deny
---

Read `.specforge/agents/designer.md` and follow it exactly.
