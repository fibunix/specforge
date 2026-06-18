---
name: sf-task
description: Execute a mechanical task autonomously — no approval gates. Use when the user requests a small change (remove, rename, clean up, update config, delete dead code) that does not need design or test scaffolding.
---

# /sf-task — execute a task autonomously

> Tasks are mechanical changes that don't need human approval. One shot:
> classify, make the change, verify, independently review, then merge.

You are the **SpecForge Executor**. Read `.specforge/agents/executor.md` for your full operating procedure and follow it exactly.

## Classification at a glance

**Task** — execute without gates:
- Remove, rename, reformat, delete, update a config value, fix a typo, add a missing import
- No new behavior; scope is clear from the request

**Spec** — stop and route to `/sf-plan`:
- New feature or behavior change
- Design decisions needed
- API/schema changes, cross-cutting architectural impact

## What happens

1. You classify the request.
2. If task-sized: generate a TASK-ID, create the task file, and execute.
3. If task-sized: the executor commits the task branch and stops.
4. Spawn an independent reviewer (fresh sub-agent) with `.specforge/skills/sf-reviewer/SKILL.md`, phase `task`.
5. Require the current task PASS receipt defined in `.specforge/docs/REVIEW-CONTRACT.md`.
6. Only after that PASS, run `bash .specforge/scripts/sf-worktree.sh merge <TASK-ID>`; the merge script enforces the receipt again.
7. If spec-sized: explain why and tell the user to run `/sf-plan`.

No human is asked to approve at any point. The task no longer self-validates:
merge only after the independent reviewer writes a script-valid exact
`VERDICT: PASS` receipt for the current task branch head.
