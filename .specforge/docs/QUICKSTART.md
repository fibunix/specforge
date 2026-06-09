# SpecForge Quickstart

Get to a reviewable SPEC with the simple flow:

```text
Plan -> Test -> Ship
```

## 1. Install

```bash
cp -r /path/to/specforge/.specforge .
bash .specforge/scripts/sf-init.sh
$EDITOR .specforge/config.yaml
bash .specforge/scripts/sf-doctor.sh
```

Single-project repos can keep `test_command`, `lint_command`, `build_command`,
and `source_dir`. Multi-project repos can use `projects:`; `sf test` runs all
projects, and `sf test <project-id>` runs one.

To update an existing install later without overwriting project specs or user
instruction text:

```bash
sf update --dry-run
sf update

# or through curl:
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash -s -- --update --dry-run
```

## 2. Plan

Run:

```text
/sf-plan
```

The agent writes and gets approval for `.specforge/ALIGN.md`, then writes and
gets approval for `.specforge/DESIGN.md` plus the SPEC files.

Do not start tests until the Plan artifacts are approved.

If you think of new requirements while an approved plan still has unfinished
specs, run `/sf-plan` and the agent will queue them in `.specforge/NEXT.md`
instead of changing the active plan. After every active spec is done, run
`/sf-plan` again to frame the next iteration and archive the completed one.

Active plan files show only what you are working now. Completed requirements
remain visible through `sf trace` and generated `.specforge/REGISTRY.md`.
Changed implemented behavior should become a new `REQ-*` ID that supersedes the
old one.

## 3. Test One Spec

Pick a SPEC from the design output and run:

```text
/sf-test SPEC-001
```

The builder creates or switches to `feature/SPEC-001`, writes failing tests,
sets `Build state: tests-red`, and stops.

SPEC files may also be slugged, for example
`.specforge/specs/SPEC-001-frequency-record.md`. You still run commands with
the stable ID (`SPEC-001`), and the branch remains `feature/SPEC-001`.

Inspect the test changes:

```text
/sf-review SPEC-001
```

Approve the tests only if they prove the SPEC requirements.

## 4. Ship One Spec

After approving the red tests, run:

```text
/sf-ship SPEC-001
```

The builder implements the minimum code, runs `sf-test.sh`, ticks the SPEC
checkboxes, commits on `feature/SPEC-001`, verifies, and stops.

Inspect the final implementation:

```text
/sf-review SPEC-001
```

Finalize only after the final diff is right:

```text
/sf-finalize SPEC-001
```

Use `/sf-finalize SPEC-001 --dry-run` to verify without merging.

## Status

```text
/sf-status
```

`/sf-status` shows the active iteration, active SPEC progress, queued
`NEXT.md`, and registry counts. Use `sf trace` when you need the full
requirement table across active and archived iterations.

Use the CLI for scriptable checks:

```bash
sf status
sf trace
sf lint
sf review SPEC-001
sf review SPEC-001 --patch
```
