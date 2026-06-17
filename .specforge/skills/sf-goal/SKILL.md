---
name: sf-goal
description: Run SpecForge in goal-style autonomous mode by delegating to the sf-loop workflow. Use when a user asks Codex or Claude to keep going toward the current approved SpecForge goal.
---

# /sf-goal — goal-style wrapper

`/sf-goal` is a thin public wrapper around `/sf-loop`. It does not define a
second workflow.

## What you do

1. Read `.specforge/skills/sf-loop/SKILL.md`.
2. Follow `/sf-loop` exactly, including DESIGN order, dependency gates,
   independent reviewer receipts, and fail-closed behavior.
3. When reporting progress, call the mode `sf-goal` only at the user interface
   boundary. Internally, use the same stages, receipts, and finalization rules
   as `/sf-loop`.

## Rules

- Never automate Plan approval. ALIGN, DESIGN, and SPEC approval remains human-only.
- Never merge without the same independent PASS receipts required by `/sf-loop`.
- Do not create a second status ladder or command sequence.
