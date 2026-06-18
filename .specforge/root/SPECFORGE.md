# SpecForge

Spec-driven, TDD-first development. One shared understanding, one source of truth per spec. Work is **right-sized to three lanes** so simple changes are not over-processed.

## Start

- Read `.specforge/config.yaml`. If phase state is unclear, run `/sf-status`.
- Unsure which lane? Run `/sf "<request>"` — it classifies and routes for you.
- Use one phase per fresh agent session and stop at the next approval gate.
- Follow `.specforge/skills/<command>/SKILL.md` for phase behavior. Flow reference and rules: `.specforge/docs/FLOW.md`.

## Lanes

- **task** (`/sf-task`) — mechanical change, no new behavior. No plan, no tests; one independent review.
- **quick-spec** (`/sf-quickspec`) — small, well-understood feature. The spec is the design (no ALIGN/DESIGN), one approval, one fresh-eyes review.
- **full-plan** (`/sf-plan`) — complex or ambiguous work. ALIGN + DESIGN + per-spec test/impl review.

## Commands

```bash
/sf "..."             # smart router: classify a request and pick the lane
/sf-plan              # full lane: approve ALIGN.md, DESIGN.md, and SPECS
/sf-quickspec "..."   # quick lane: one self-contained SPEC, single review
/sf-test SPEC-ID      # create/switch feature branch and write red tests
/sf-review SPEC-ID    # inspect tests or implementation changes
/sf-ship SPEC-ID      # implement after red tests are approved
/sf-finalize SPEC-ID  # verify, merge, and delete the feature branch
/sf-loop              # autonomous build loop after reviewer PASS receipts
/sf-task "..."        # mechanical task with independent review
/sf-status            # read disk, queued NEXT.md, status, and requirement trace
```

`SPEC-ID` may resolve `.specforge/specs/SPEC-ID.md` or
`.specforge/specs/SPEC-ID-<slug>.md`. Branches use the stable ID, for example
`feature/SPEC-009` for `.specforge/specs/SPEC-009-frequency-record.md`.

## Approval Gates

- `/sf-test SPEC-ID` means Plan artifacts were approved.
- `/sf-ship SPEC-ID` means red tests were approved.
- `/sf-finalize SPEC-ID` means the final diff was approved.
- `/sf-loop` may replace red-test and final-diff human approval
  only with independent reviewer receipts that contain exact `VERDICT: PASS`.
- Never move through a manual gate unless the human explicitly requests the next command.

## Rules

1. Specs are the contract; implementation without a SPEC is rejected.
2. Tests come before implementation. A spec with no expected failing test is not ready to build.
3. Human approval is required for Plan and manual phase transitions; autonomous build-loop transitions require independent reviewer receipts with exact `VERDICT: PASS`.
4. Use one spec, one branch, and one merge.
5. Builders run `bash .specforge/scripts/sf-test.sh`; do not hardcode project test commands.
6. Tracking lives in `.specforge/specs/SPEC-*.md` checkboxes and stable `REQ-*` IDs; update only the current phase's fields.
7. Approved active iterations are protected; new requirements are queued in `.specforge/NEXT.md` until the current specs are done.
8. Implemented requirements are immutable; changed behavior gets a new `REQ-*` ID that supersedes the old one.

## Sources Of Truth

- Active plan artifacts: `.specforge/ALIGN.md`, `.specforge/DESIGN.md`, `.specforge/specs/SPEC-*.md`
- Next-iteration brief: `.specforge/NEXT.md`
- Completed iteration archives: `.specforge/iterations/ITER-*`
- Agent manuals: `.specforge/agents/*.md`
- Phase skills: `.specforge/skills/*/SKILL.md`
- Flow reference: `.specforge/docs/FLOW.md`
- Project config: `.specforge/config.yaml`

Active plan artifacts describe only the current iteration. Grep archived
iteration specs to inspect implemented or superseded history.
