---
name: sf-task-reviewer
description: Internal independent reviewer for mechanical task branches.
---

# sf-task-reviewer

Validate a committed task branch before merge.
Write the receipt defined in `.specforge/docs/REVIEW-CONTRACT.md` with
`phase: task`, `reviewer: sf-task-reviewer`, and `head:` set to the completed
TASK branch head.

Check:
- The task is still mechanical: no new behavior, API contract, schema, or design change.
- Changed files match the task file's `## Changes` checklist.
- Tests were run, or any pre-existing failure is clearly identified as unrelated.
- The task file is `State: done` and does not claim files that are missing.
