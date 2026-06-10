# Changelog

All notable changes to SpecForge are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Removed — scripts enforce, agents interpret

The markdown-interpretation layer (~1,400 lines of awk-over-markdown, where
every confirmed bug so far lived) moved into skill prose; the enforcement
layer (test runner, lint, verify, finalize, archive mechanics) is unchanged.

- `sf wave` / `sf-wave.sh` — wave planning is now prose in the sf-plan skill
  (§ Wave planning), including the done-but-unmerged-dependency rule.
- `sf review` / `sf-review.sh` — the sf-review skill drives git directly and
  reads test bodies instead of counting `(covers)` annotations.
- `sf trace` / `sf-trace.sh` and `sf-registry.sh` with the generated
  `.specforge/REGISTRY.md` / `registry.json` — traceability is answered by
  grepping `.specforge/specs/` and `.specforge/iterations/*/specs/` directly.
- `sf-snapshot.sh` — replaced by `sf facts` (below); the five-rung `Next:`
  priority ladder moved verbatim into the sf-status skill.
- `lib/spec.sh` DESIGN-table parsers (`sf_design_spec_order`,
  `sf_design_spec_deps`) — the agent reads the SPECS table itself.
- `sf-verify-build.sh` undeclared-files warning — scope judgment belongs to
  the review skill; the deterministic ticked-file-exists backstop stays.

### Added

- `sf facts` (alias of `sf status`): a thin fact dump — plan-artifact status
  plus one line per SPEC (state, source, branch, checkbox counts), each read
  from the spec's most-advanced copy. Facts only; no `Next:` line.
- Agent-authored iteration close-outs: `archive-reset` now requires
  `.specforge/SUMMARY.md` (template: `.specforge/templates/SUMMARY.md`),
  written by the agent before archiving; `--abandon` writes a one-line stub
  when none exists.
- SPEC-FORMAT.md parsing contract: scripts read only `**State:**` and
  `**Iteration:**`; everything else in a spec is for humans and agents.
- Vocabulary test now pins the decision-ladder and wave-planning prose in the
  skills (the prose equivalent of a smoke test).

### Fixed

- `sf wave` no longer crashes on macOS default bash (3.2): rewritten without associative arrays.
- `sf wave finalize` can now actually finalize: done specs are selected independently of the "ready" filter (the old filters were mutually exclusive).
- `sf-finalize.sh --rebase` from a parallel checkout no longer calls an undefined function; it rebases inside the worktree, reruns tests, ff-merges, and cleans up.
- `archive-reset` no longer deletes `NEXT.md`: the queued next-iteration brief survives the handoff to the Aligner.
- Archive directories are now named after the completed iteration's own ID (read from ALIGN.md) instead of the archiving timestamp.
- A queued `NEXT.md` no longer poisons the iteration-consistency lint (and with it `sf verify`/`sf finalize`): `NEXT.md` is excluded from active-iteration resolution and carries no Iteration field.
- `sf status` is truthful while work is in flight: per-SPEC State is read from the most-advanced copy (worktree, feature branch blob, or checkout).

### Added

- `State: approved` now has an owner: the Designer sets it on every SPEC when the human approves the design bundle; builders hard-stop on `draft`.
- `sf status` ends with a computed `Next:` line (dependency-aware) naming the exact next command; the sf-status skill is now a thin wrapper.
- `.specforge/templates/NEXT.md` and a documented NEXT.md contract (one bullet per queued requirement, no Iteration field).
- Sequential, named iteration IDs: `ITER-NNN-<slug>`, generated via `sf-iteration.sh next-id <slug>`.
- Iteration close-out record: `archive-reset` writes `iterations/<ID>/SUMMARY.md` (specs shipped, requirements, supersedes).
- `sf doctor` reports specs whose feature branch is ahead of the checkout's spec state.
- Behavior tests: full lifecycle end-to-end, `sf wave`/`wave finalize`, NEXT.md contract, and a legacy-vocabulary guard.

### Changed

- SPEC lifecycle is now four states: `draft -> approved -> tests-red -> done`. `implemented` is read as legacy (lint warns); SPEC-FORMAT.md § State lifecycle is the single normative reference.
- Legacy-vocabulary sweep: `sf-ship` skill, designer/builder manuals, codex builder adapter, registry and iteration scripts all use the single `**State:**` field (legacy `Status`/`Build state` still parsed via `sf_spec_state`).
- `sf-ship` skill slimmed to gate semantics only; the Builder manual is the single process canon.

- Stable `REQ-*` requirement IDs in SPEC acceptance criteria.
- `sf-trace.sh` and `sf trace` / `sf requirements` for generated requirement trace reports.
- `sf-lint-specs.sh` and `sf lint` for lightweight SPEC validation.
- `/sf-trace` slash command.
- `Build state` metadata for SPEC files.
- `.specforge/templates/ALIGN.md` and `.specforge/templates/DESIGN.md` reference templates.
- `sf-worktree.sh merge --dry-run` and explicit `--auto-commit` mode.

### Changed

- `sf-snapshot.sh` now reports ALIGN/DESIGN status before per-SPEC checkbox counts.
- `sf-worktree.sh merge` now requires committed worktree changes by default instead of auto-committing implicitly.
- Live `ALIGN.md` and `DESIGN.md` drafts were removed from the framework source tree to avoid confusing templates with project artifacts.

---

## [2.0.0] — 2026-06-05

**Full rewrite.** The 1.x line accumulated too much ceremony (6 phases, 7 agents, 10 commands, 35 bash scripts, 48 docs, 9 IDE adapters) without enough quality gain. v2 is the same spec-driven, TDD-first discipline, with most of the machinery stripped away.

### Changed

- **4 phases instead of 6:** Align → Design → Test → Build. Discovery + Specification + Architecture collapsed into Align + Design. Validation folded into Build (self-verify by running tests + human review at merge).
- **3 agents instead of 7:** aligner, designer, builder. Orchestrator/planner/architect/tester/coder/reviewer/validator all gone or folded.
- **4 commands instead of 10:** `/sf-align`, `/sf-design`, `/sf-build`, `/sf-status`.
- **4 scripts instead of 35:** `sf-init.sh`, `sf-test.sh`, `sf-worktree.sh`, `sf-snapshot.sh`.
- **3 docs instead of 9:** QUICKSTART, FLOW, SPEC-FORMAT. INDEX, EXAMPLE, TROUBLESHOOTING, ADAPTERS, ADAPTER-SYSTEM, ID-CONVENTIONS, MONOREPO, SPEC-ANNOTATIONS, UPGRADING all dropped.
- **5 IDE adapters instead of 9:** claude-code, opencode, codex, pi, antigravity. Each is a 3-line symlink wrapper around the single `AGENTS.md` rules file. Cursor, Windsurf, VS Code Copilot, Gemini-Jules dropped.
- **22 framework files instead of 94.**
- **Phase-based sessions.** Each phase runs in its own fresh session. The primary `sf` agent reads disk artifacts on startup to resume. Sub-agents are spawned with minimal prompts and read their own operating manuals from disk. The primary carries only a resume block + `[RESULT]` blocks. Context stays small.
- **Per-spec checkboxes are the only tracking.** No `state.json`, no `traceability.json`, no `config.yaml` beyond 5 fields (name, test/lint/build commands, source dir). The SPEC's checkbox state IS the state.
- **Basic worktrees, no safety machinery.** `sf-worktree.sh` does `create SPEC-ID` and `merge SPEC-ID` (auto-commit + fast-merge). No conflict detection, no file-ownership check, no batch enforcement. Be sensible.

### Removed

- Monorepo / workspace support (`.specforge/workspaces:`, `/sf-workspace`, per-workspace config).
- CI integration (`ci-gate-check.sh`, GitHub Actions template, `SF_CI_MODE`).
- Spec linting (`sf-spec-lint.sh`, `sf-req-lint.sh`).
- Dependency graph verification.
- Phase-gate scripts (`check-phase-gates.sh`, `advance-phase.sh`, `rollback-phase.sh`).
- Three-layer worktree safety (plan, runtime check, file-ownership).
- Separate PR review reports and automated merge.
- Templates directory (all templates inlined into the docs/templates that remain).
- `CLAUDE.md`, `GEMINI.md` — replaced by single `AGENTS.md`.

### Kept

- Specs as the contract.
- TDD discipline (tests before code, every time).
- Human approval at every phase transition.
- `sf-test.sh` as the only way to run tests (no hardcoded `npm test` / `pytest` / etc.).
- Tech-stack agnosticism.

---

## [1.1.0] — 2026-05-30

### Added

**Harness reliability**
- `rollback-phase.sh` — roll back to an earlier phase, resetting gate flags without deleting artifacts
- `/sf-rollback` command (`sf-rollback.command.md`) — orchestrated rollback with gate status display
- `sf-recover.sh` — health check (`--check`), worktree reconciliation (`--clean-worktree`), batch resume (`--resume-batch`)
- `rebuild-traceability.sh` — rebuild `traceability.json` from scratch; `--dry-run` flag shows delta
- `ci-gate-check.sh` — non-interactive CI/CD wrapper; auto-detects GitHub Actions, GitLab CI, CircleCI; respects `NO_COLOR`/`SF_CI_MODE`
- GitHub Actions template at `templates/ci/github-actions-specforge-check.yml`
- Optional CI template prompt in `sf-install.sh`

**Batch sequencing enforcement**
- `sf-worktree-create.sh` now enforces that earlier batches are merged before creating worktrees in a later batch; uses `--force-batch` flag to override
- `sf-worktree-create.sh` now updates `state.json["active_worktrees"]` on creation (previously only removed at merge)
- `merge-pr.sh` now records `batch` field in `merged_specs` entries

**Approval logging**
- `advance-phase.sh` now captures optional approval notes and gate check output
- Gate summary (first 2000 chars) stored in `state["gates"][phase]["gate_summary"]`
- Approval events appended to `.specforge/logs/approvals.log`
- `sf-install.sh` creates `.specforge/logs/` directory on first install

**Spec quality**
- `sf-spec-lint.sh` — lints spec files for TC-ID format, Traces-to, Status, GIVEN/WHEN/THEN; errors block gate for Approved specs; warnings for Draft specs
- `check-phase-gates.sh` specification gate now calls `sf-spec-lint.sh`
- `sf-spec.command.md` — added lint step before gate check

**Dependency visualization**
- `sf-dep-graph.sh` — generates Mermaid or DOT dependency graph from actual spec `Depends on:` fields
- `verify-dependency-graph.sh` — now prints regeneration hint after acyclicity check

**Adapter system**
- `adapters/shared/flat-workflow.canonical.md` — single shared template for all rules-based IDEs
- Cursor, Windsurf, VS Code Copilot adapters now use the shared template (no more divergence)
- `vscode-copilot/adapt.sh` — new adapter for VS Code GitHub Copilot (`.github/copilot-instructions.md`)
- `sf-adapt.sh --validate` mode — check staleness without regenerating; `--format=json` for CI
- `sf-adapt-check.sh` — standalone staleness checker
- All generated files now include `Source-SHA256` checksum in GENERATED header
- `claude-code/adapt.sh` — now generates `.claude/skills/specforge/SKILL.md` and `.claude/skills/worktrees/SKILL.md` into target projects
- `claude-code/adapt.sh` — agent descriptions now extracted from canonical agent file bodies (hardcoded fallback preserved)
- `sf-adapt.sh` — warns when both `pi` and `gemini-jules` are in `ide_adapters` (mutual exclusivity)

**Code quality**
- `find-orphan-code.sh` — supports `@spec-exempt` marker for bootstrap/barrel files
- `check-phase-gates.sh` — respects `NO_COLOR=1` and `SF_CI_MODE=1`

**Documentation (new files)**
- `.specforge/docs/QUICKSTART.md` — first-time user guide
- `.specforge/docs/TROUBLESHOOTING.md` — 10 common failure modes
- `.specforge/docs/ADAPTER-SYSTEM.md` — IDE adapter generation pipeline
- `.specforge/docs/SPEC-ANNOTATIONS.md` — `@spec` format by language
- `.specforge/docs/UPGRADING.md` — safe upgrade procedure
- `CHANGELOG.md` — this file

---

## [1.0.0] — 2026-05-01

Initial release of SpecForge.

### Included

- 6-phase workflow: Discovery → Specification → Architecture → Test Scaffolding → Implementation → Validation
- 7 specialist agents: orchestrator, planner, architect, tester, coder, reviewer, validator
- 14 bash scripts for phase gates, worktree safety, and traceability
- 6 IDE adapters: claude-code, opencode, cursor, windsurf, pi, gemini-jules
- 7 test framework templates: jest, vitest, pytest, xctest, junit, flutter_test, jest-ns
- Three-layer worktree safety system (plan, runtime, physical)
- Full traceability chain: REQ → SPEC → TEST → CODE → PR
