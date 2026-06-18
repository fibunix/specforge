# Loop Runners

`/sf-loop` is a single pass: it advances eligible specs/tasks as far as
independent reviewer PASS receipts allow, then either finalizes everything or
prints `PIPELINE BLOCKED`. "Looping" means **re-invoking `/sf-loop` until it
prints `PIPELINE BLOCKED`** (or there is nothing left to do).

`PIPELINE BLOCKED` is the universal terminate signal — every runner stops the
loop when it sees that line, because it means the next move needs a human
(plan approval, or fixing a failed review).

The loop itself is identical everywhere; only the re-invocation mechanism
differs per tool.

| Tool | Loop invocation | Notes |
|------|-----------------|-------|
| **Claude Code** | `/loop /sf-loop` | Native recurring-prompt feature drives `/sf-loop` until it stops. |
| **Codex** | Re-invoke the `sf-loop`-following primary until `PIPELINE BLOCKED` | Use a Codex automation/loop that repeats the `/sf-loop` instruction; one spec advances per pass. |
| **OpenCode** | Re-invoke `/sf-loop` until `PIPELINE BLOCKED` | The `sf` primary agent follows `.specforge/skills/sf-loop/SKILL.md` each pass. |
| **Pi** | `/skill:sf-loop` repeated; re-invoke if the runtime supports repeat invocation, otherwise single-pass + manual re-invoke | |

## Safety

- The loop never approves a plan or a spec — `draft → approved` is always human.
- Each phase transition is gated by a fresh-eyes `sf-reviewer` PASS receipt
  (see `REVIEW-CONTRACT.md`). A failed or missing receipt fails closed and the
  loop stops.
- Worktrees isolate every spec/task; the main checkout's branch never changes.

So an unattended loop can only ever advance work that independent review has
already cleared. The worst case is wasted passes that all print
`PIPELINE BLOCKED`.
