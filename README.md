# SpecForge

SpecForge is a small, spec-driven workflow for AI-assisted development.

```text
Plan -> Test -> Ship
```

- Plan creates `ALIGN.md`, `DESIGN.md`, and approved SPEC files.
- Test writes failing tests first, then commits them for review.
- Ship implements only after the red tests are approved.
- New requirements wait in `NEXT.md` while active specs are unfinished.

SpecForge works with any stack. Your project commands live in
`.specforge/config.yaml`.

## Install

From your project directory:

```bash
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash
```

Pick an adapter when needed:

```bash
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash -s -- --ide codex
```

Supported values:

```text
opencode, claude-code, codex, pi, antigravity, all
```

## Configure

Edit `.specforge/config.yaml`:

```yaml
project_name: my-project
test_command: npm test
lint_command: npm run lint
build_command: npm run build
source_dir: src
```

For monorepos, define `projects:` in the same file.

## Use

Run these in your AI coding tool:

```text
/sf-plan              create and approve ALIGN.md, DESIGN.md, and specs
/sf-test SPEC-ID      write red tests for one spec, then commit for review
/sf-review SPEC-ID    review tests or implementation
/sf-ship SPEC-ID      implement after tests are approved
/sf-finalize SPEC-ID  verify, merge, and clean up
/sf-status            show current state, queued next work, and requirement trace
```

`/sf-status` reads each spec's State from its most-advanced copy (worktree,
feature branch, or checkout) and ends with a computed `Next:` line — it stays
truthful while work is in flight on feature branches.

Normal flow:

```text
/sf-plan
/sf-test SPEC-ID
/sf-review SPEC-ID
/sf-ship SPEC-ID
/sf-review SPEC-ID
/sf-finalize SPEC-ID
```

`SPEC-ID` resolves `.specforge/specs/SPEC-ID.md` or `.specforge/specs/SPEC-ID-<slug>.md`.
Branches use the stable ID: `feature/SPEC-009` for `SPEC-009-frequency-record.md`.

### Plan

`/sf-plan` routes to one state based on disk:

- **Active iteration unfinished** — queues new requirements in `NEXT.md` and stops.
- **Iteration complete** — archives it under its `ITER-NNN-<slug>` ID (with a SUMMARY.md close-out), keeps `NEXT.md` as the next brief, then runs the Aligner.
- **Need alignment** (no approved `ALIGN.md`) — runs the Aligner, seeded from `NEXT.md` when present.
- **ALIGN approved** — runs the Designer to produce `DESIGN.md` and SPEC files. On bundle approval the Designer sets `State: approved` on every SPEC.

If a session is already long when Plan routes to alignment or design, end it and re-run `/sf-plan` in a fresh session — disk state is preserved and the new session picks up exactly where you left off.

### Test

`/sf-test SPEC-ID` creates or switches to `feature/SPEC-ID`, writes failing tests for every unchecked item in the SPEC's `## Tests` section, confirms they are red, sets `State: tests-red`, and **commits the red tests**. It stops there.

Inspect the committed tests with `/sf-review SPEC-ID`. Approve them by running `/sf-ship SPEC-ID`.

### Ship

`/sf-ship SPEC-ID` implements the minimum code to make the committed red tests pass, ticks the SPEC checkboxes, commits on `feature/SPEC-ID`, and runs the verifier. It stops for final review.

Inspect the diff with `/sf-review SPEC-ID`. Finalize with `/sf-finalize SPEC-ID`.

### Parallel work

```bash
sf wave
```

`sf wave` computes which ready specs can be built concurrently (disjoint file sets). Open one session per worktree and run the normal flow in each. Use `sf finalize SPEC-ID --rebase` when the base branch has moved.

## Update

From your project directory:

```bash
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash -s -- --update
```

Or if you have `sf` available:

```bash
sf update --dry-run
sf update
```

## CLI

```bash
sf update --dry-run
sf update
sf doctor
sf status
sf trace
sf test
sf lint
sf wave
sf review SPEC-ID [--patch]
sf finalize SPEC-ID [--dry-run] [--rebase]
```

## Rules

1. Specs are the contract.
2. Tests come before implementation.
3. Humans approve every phase transition.
4. Use one spec, one branch, and one merge.
5. Builders run `.specforge/scripts/sf-test.sh`.
6. Approved active iterations are protected; future requirements wait in `NEXT.md`.

## Docs

- [Flow](.specforge/docs/FLOW.md)
- [Spec format](.specforge/docs/SPEC-FORMAT.md)
- [Adapters](.specforge/adapters/README.md)
