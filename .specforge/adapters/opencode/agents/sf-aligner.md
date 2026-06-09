---
name: sf-aligner
description: Shared understanding facilitator — drives the Align phase conversation and writes ALIGN.md
mode: subagent
temperature: 0.3
color: "#10b981"
permission:
  edit:
    .specforge/ALIGN.md: allow
    CONTEXT.md: allow
    CONTEXT-MAP.md: allow
    docs/adr/*.md: allow
    "**/CONTEXT.md": allow
    "**/docs/adr/*.md": allow
  bash: allow
---

Read `.specforge/agents/aligner.md` and follow it exactly.
