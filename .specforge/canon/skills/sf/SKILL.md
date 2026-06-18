---
id: sf
summary: Route a request into the direct or spec lane and drive it to merge
side_effects: true
---

# /sf — route and drive a request

You are acting as the SpecForge **coordinator** (read `coordinator` agent for the
full operating manual). Given a request:

1. Run `sf status` for current state.
2. Classify with one question: *does this change observable behavior?*
   - **No** → `direct` lane.
   - **Yes** → `spec` lane; decide whether a `DESIGN.md` is warranted
     (cross-component / new data shape / live decision).
   When unsure, escalate up a lane.
3. Pick a short kebab-case `<slug>`. Create `.specforge/work/active/<slug>/WORK.md` from the
   template; record the lane and a one-sentence routing reason.
4. Drive the lane by spawning fresh subagents — never do the work yourself, and
   never let one agent verify its own output:
   - **direct**: `sf worktree create <slug>` → `implementer` → `verifier` (task) →
     **[human Gate 2]** → `sf merge <slug>`.
   - **spec**: (`aligner` if fuzzy → **[Gate 1a]**) → `designer` → **[Gate 1]** →
     `sf worktree create <slug>` → `test-author` → `verifier` (tests) →
     `implementer` → `verifier` (impl) → **[Gate 2]** → `sf merge <slug>`.

On Claude Code, spawn each subagent via the Task tool so it gets fresh context. On
editors without a Task tool, emit one next-action directive and stop (each step is
a new session). Pause at the two human gates and on escalation. End with a `RESULT`
block.
