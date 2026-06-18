# SpecForge

A thin, agent-driven harness for spec-first software work. The human validates
only genuine **design decisions**; everything else is driven by subagents that
verify each other's work. The rule above all: **no agent grades its own homework.**

## What it is

- **Two lanes.** `direct` (mechanical, no new behavior — zero human gates) and
  `spec` (new/changed behavior — produces a SPEC, and a DESIGN only when the work
  crosses components / adds a data shape / has a live decision).
- **Fresh-eyes roles.** `coordinator` conducts; `aligner` → `designer` is the
  human-gated design phase; `test-author` → `implementer` → `verifier` is the
  build, with a different agent at each step. The test-author never writes code;
  the implementer never edits tests; the verifier authored neither.
- **State is observed, not stored.** No state field, no state-machine script.
  Lifecycle is derived from git + filesystem (work dir, `feature/<slug>` branch,
  the red-tests commit, a `Verified-by:` trailer, the move to `work/archive/`).
  `sf status` reports it; it enforces nothing.
- **Two human gates only.** Approve the plan (Gate 1) and approve the merge
  (Gate 2). The direct lane has none.
- **One guardrail.** `sf merge` refuses unless tests are green and HEAD carries a
  `Verified-by:` trailer. Everything reversible is unguarded.

## Install & update

The **same** curl one-liner installs and updates — it's idempotent. Run it from
your project root:

```sh
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash -s -- --ide all
```

Re-running it on an existing project re-fetches the latest framework and
re-projects it, preserving everything you own — `project.yaml`, `work/`,
`NEXT.md`, and your own text in `AGENTS.md`/`CLAUDE.md` outside the managed
block. It prints `Updating` instead of `Installing` when it detects an existing
install.

Or from a local clone:

```sh
bash install.sh --source /path/to/specforge --dir /your/project --ide all
# IDEs: claude-code, opencode, codex, pi, antigravity, all
```

`bin/sf update` re-projects canon from the already-installed framework (no
network); the curl line above is what pulls a newer framework. Override the
source with `SPECFORGE_GIT_URL` / `SPECFORGE_VERSION` env vars.

Then edit `project.yaml` (set `test_command`) and, in your editor, run `/sf
"<request>"` to route work or `/sf-loop` to drive autonomously.

## CLI (deterministic essentials only)

| Command | Purpose |
|---------|---------|
| `sf status` | Read-only facts about active work items |
| `sf worktree create <slug>` | Isolated worktree on `feature/<slug>` |
| `sf test [project]` | Run the configured test command(s) |
| `sf merge <slug>` | Guardrail-checked ff-merge + archive |
| `sf init` / `sf update` / `sf doctor` | Install / re-project canon / health check |

Everything requiring judgment lives in skills/agents, not the CLI.

## Layout

```
.specforge/
  canon/        author-once source: agents/ skills/ templates/ docs/ root/
  profiles/     one tiny file per IDE (data + emit hooks)
  lib/          shared bash (projector, frontmatter, git, work-state, ...)
  scripts/      sf-init/update/doctor/worktree/test/status
project.yaml    the only config (project-owned)
work/active/    one dir per in-flight item; archived to work/archive/<date>-<slug>/
NEXT.md         backlog of one-line briefs
```

### Multi-IDE without duplication

Each skill/agent is authored once in `canon/`. A single projector
(`lib/project.sh`) renders it into each IDE's layout using a per-IDE
`profiles/<ide>.sh` (an allowlist, so OpenCode's strict schema is never violated
and no `opencode.json`/model IDs are written). Generated files carry a
`SPECFORGE-GENERATED` marker so `sf update` overwrites them while preserving any
user-authored file. Adding a 6th IDE is one new profile.

The previous version is preserved under `archive-v1/` for reference.
