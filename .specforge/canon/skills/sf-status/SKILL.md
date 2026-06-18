---
id: sf-status
summary: Show derived state of active work items and recommend the next action
side_effects: false
---

# /sf-status — facts + next action

Run `sf status` and interpret it. For each active item, state the derived
lifecycle state (planning / ready / tests-red / implementing / verified / done) and
the single next action — the gate it's waiting on, the worker to spawn, or the
escalation needed. Read-only; recommend, don't act.
