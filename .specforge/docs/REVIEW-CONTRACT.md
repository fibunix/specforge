# Review Receipt Contract

Independent reviewers write one receipt per reviewed commit under:

```text
.specforge/reviews/<WORK-ID>/<phase>-<commit>.md
```

`WORK-ID` is a `SPEC-*` or `TASK-*` ID. Supported phases:

| Phase | Reviewer | Reviewed commit |
|-------|----------|-----------------|
| `tests-red` | `sf-test-reviewer` | commit whose SPEC has `State: tests-red` |
| `done` | `sf-implementation-reviewer` | current completed SPEC branch head |
| `task` | `sf-task-reviewer` | current completed TASK branch head |

Receipts are machine-checked. Required fields:

```yaml
spec_id: <WORK-ID>
phase: tests-red | done | task
base: <base commit sha>
head: <reviewed commit sha>
reviewer: <expected reviewer name>
verdict: PASS | FAIL
commands run:
- <command>
findings: <concise findings>
VERDICT: PASS | FAIL
```

Rules:

- The filename commit and internal `head:` must match the reviewed commit.
- `base:` must name a commit in the current repository.
- `reviewer:` must match the expected reviewer for the phase.
- At least one command must be listed under `commands run:`.
- The receipt must contain exactly one `VERDICT:` line, and it must be the final
  line.
- Autonomous merge/finalize accepts only exact final `VERDICT: PASS`.
- Exact final `VERDICT: FAIL` blocks the autonomous gate.
