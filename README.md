# SpecForge

SpecForge is a small, spec-driven workflow for AI-assisted development.

```text
Plan -> Test -> Ship
```

- Plan creates `ALIGN.md`, `DESIGN.md`, and approved SPEC files.
- Test writes failing tests first.
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

For monorepos, define `projects:` in the same file. Run tests with:

```bash
sf test
sf test app
```

## Use

Run these in your AI coding tool:

```text
/sf-plan              create and approve ALIGN.md, DESIGN.md, and specs
/sf-test SPEC-ID      write red tests for one spec
/sf-review SPEC-ID    review tests or implementation
/sf-ship SPEC-ID      implement after tests are approved
/sf-finalize SPEC-ID  verify, merge, and clean up
/sf-status            show current state, queued next work, and requirement trace
```

Normal flow:

```text
/sf-plan
/sf-test SPEC-ID
/sf-review SPEC-ID
/sf-ship SPEC-ID
/sf-review SPEC-ID
/sf-finalize SPEC-ID
```

`SPEC-ID` resolves `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`. Branches keep the stable ID, so
`.specforge/specs/SPEC-009-frequency-record.md` uses `feature/SPEC-009`.

## CLI

```bash
sf update --dry-run
sf doctor
sf status
sf trace
sf test
```

## Rules

1. Specs are the contract.
2. Tests come before implementation.
3. Humans approve every phase transition.
4. Use one spec, one branch, and one merge.
5. Builders run `.specforge/scripts/sf-test.sh`.
6. Approved active iterations are protected; future requirements wait in `NEXT.md`.

## Docs

- [Quickstart](.specforge/docs/QUICKSTART.md)
- [Flow](.specforge/docs/FLOW.md)
- [Spec format](.specforge/docs/SPEC-FORMAT.md)
- [Adapters](.specforge/adapters/README.md)
