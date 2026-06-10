# SpecForge Quickstart

A worked example — one tiny iteration from zero to merged.

See [FLOW.md](FLOW.md) for the full normative reference.

---

## Iteration walkthrough

### 1. Install and init

```bash
cd my-project
curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash
```

Edit `.specforge/config.yaml`:

```yaml
project_name: my-project
test_command: npm test
lint_command: npm run lint
build_command: npm run build
source_dir: src
```

### 2. Queue a requirement (optional — skip if starting from scratch)

```bash
sf queue "users can log in with email + password"
```

This creates or appends to `.specforge/NEXT.md`. The Aligner will read it as
the starting brief.

### 3. Plan the iteration

```text
/sf-plan
```

The agent runs as the **Aligner**: reads NEXT.md if present, asks focused
questions one at a time, and writes `.specforge/ALIGN.md`. You approve it.

Then it runs as the **Designer**: proposes DESIGN.md with a SPECS table and one
or more SPEC files. You approve the bundle. The Designer sets
`State: approved` on every SPEC.

Example `ALIGN.md` after approval:

```markdown
# My project — Shared understanding

**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** ITER-001-login

## Problem
Users cannot authenticate; every route requires manual token injection.

## Users
- **End user** — logs in, gets a session token

## Success criteria
- POST /auth/login returns a 200 with a JWT on valid credentials
- Invalid credentials return a 401

## Scope
### In
- Email + password login
### Out
- OAuth, magic links, 2FA

## Constraints
- Response time < 100ms at p95

## Glossary
- **Session token** — a short-lived JWT signed with the server's secret
```

Example SPEC file after approval:

```markdown
# SPEC-001: Login endpoint

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** approved
**Iteration:** ITER-001-login

## Description
POST /auth/login accepts email + password and returns a JWT.

## Acceptance criteria

- [ ] REQ-AUTH-001: valid credentials return 200 + JWT
- [ ] REQ-AUTH-002: invalid credentials return 401

## Tests

- [ ] tests/auth.test.ts  (covers REQ-AUTH-001, REQ-AUTH-002)

## Implementation

- [ ] src/routes/auth.ts
- [ ] src/services/auth.service.ts
```

### 4. Write red tests

```text
/sf-test SPEC-001
```

The builder creates `feature/SPEC-001`, writes failing tests for every unchecked
line in `## Tests`, confirms they are red, sets `State: tests-red`, and commits.

### 5. Review and approve the red tests

```bash
sf review SPEC-001
```

Output shows state, checklist counts, requirements coverage, commits, and
diffstat. If the tests are right:

```text
/sf-ship SPEC-001
```

Typing `/sf-ship` IS your approval of the committed tests.

### 6. Ship (implement)

The builder implements the minimum code to make the red tests green, ticks SPEC
checkboxes, sets `State: done`, and commits. It runs
`bash .specforge/scripts/sf-test.sh` to confirm all green.

### 7. Review and finalize

```bash
sf review SPEC-001
```

Review output now includes a requirements coverage table showing every REQ-*
ID and how many of its test lines are ticked. If any files were changed that
aren't declared in the SPEC, a warning appears.

```bash
sf finalize SPEC-001
```

This verifies, fast-forward merges `feature/SPEC-001` into `main`, deletes the
branch, and prints an updated status table.

### 8. Archive the iteration (when all specs are done)

After all specs in the iteration are `done` and finalized:

```text
/sf-plan
```

Plan detects the completed iteration, runs `archive-reset`, writes a SUMMARY.md,
archives the artifacts under `.specforge/iterations/ITER-001-login/`, and
prompts you to start the next iteration alignment with NEXT.md as the brief.

---

## Parallel builds (sf wave)

When an iteration has multiple independent specs:

```bash
sf wave
```

Shows which specs can build concurrently (no file overlap). For each:

```bash
sf worktree create SPEC-002   # isolated checkout in .worktrees/SPEC-002
# open a session in .worktrees/SPEC-002 and run /sf-test SPEC-002
```

After all specs are done and reviewed:

```bash
sf wave finalize   # merges all done specs in dependency order
```

---

## Abandoning an iteration

If the iteration turns out to be the wrong direction:

```text
/sf-plan   (then explicitly ask to abandon the active iteration)
```

Or from the CLI:

```bash
sf iteration abandon
```

This archives whatever exists under the iteration's ID with `Status: abandoned`,
keeps NEXT.md for the next alignment, and resets the plan artifacts.
