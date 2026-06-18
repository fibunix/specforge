---
id: sf-loop
summary: Autonomous coordinator — advance all active work items as far as review allows
side_effects: true
---

# /sf-loop — autonomous coordinator

Drive every active work item forward, pausing only at the two human gates and on
escalation. Act as the `coordinator`.

Each pass:
1. Run `sf status`. For each active item, determine its derived state.
2. Advance the most-ready item by spawning the right fresh subagent:
   - `approved`/`ready` → `test-author` (spec) or `implementer` (direct).
   - `tests-red` → `verifier` (tests); on approve → `implementer`.
   - `implementing` → `verifier` (impl).
   - `verified` → **[human Gate 2]**, then `sf merge <slug>`.
3. After a verifier `approved`, continue immediately — no human prompt.
4. On `changes_requested`, re-spawn a fresh author of the same phase with the
   findings. **Max 2 rework attempts per (slug, phase)**, then escalate.

Never move a plan past **Gate 1** (design approval) or merge past **Gate 2**
without a human. Never switch the base checkout's branch. Every phase transition
goes through a fresh `verifier`.

Stop when no item can advance. Report:

```
RESULT
  outcome: idle | needs_human
  reason: <design_decision | rework_limit_hit | ambiguity | external_blocker | nothing-eligible>
  items:
    - <slug> (<state>): <what it's waiting on>
```

On Claude Code, run this as one continuous driver via the Task tool (optionally
under `/loop`). On other editors, emit the single next-action directive and stop.
