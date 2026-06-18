---
id: sf-build
summary: Drive the build for one item — test-author, implementer, verifier (fresh each)
side_effects: true
---

# /sf-build <slug> [tests|impl|task] — build phase

Drive a single work item's build, spawning a FRESH subagent per role so no agent
grades its own work. Requires the feature branch to exist (Gate 1 passed).

- `tests` → spawn `test-author`, then `verifier` (phase tests).
- `impl`  → spawn `implementer`, then `verifier` (phase impl).
- `task`  → spawn `implementer` (mechanical), then `verifier` (phase task).
- no arg  → run the full sequence for the lane (spec: tests then impl; direct: task).

On a verifier `changes_requested`, re-spawn a fresh author of the same phase with
the findings (max 2 attempts, then escalate). A passing `impl`/`task` verifier
appends the `Verified-by:` trailer — required for `sf merge`. After that, the merge
is gated by **human Gate 2**.
