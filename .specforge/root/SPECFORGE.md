# SpecForge

Spec-driven, TDD-first development. One shared understanding, one source of truth per spec.

## Start

- Read `.specforge/config.yaml`. If phase state is unclear, run `/sf-status`.
- Use one phase per fresh agent session and stop at the next approval gate.
- Follow `.specforge/skills/<command>/SKILL.md` for phase behavior. Flow reference and rules: `.specforge/docs/FLOW.md`.

## Commands

```bash
/sf-plan              # approve ALIGN.md, DESIGN.md, and SPECS
/sf-test SPEC-ID      # create/switch feature branch and write red tests
/sf-review SPEC-ID    # inspect tests or implementation changes
/sf-ship SPEC-ID      # implement after red tests are approved
/sf-finalize SPEC-ID  # verify, merge, and delete the feature branch
/sf-status            # read disk, queued NEXT.md, status, and requirement trace
```

`SPEC-ID` resolves `.specforge/specs/SPEC-ID.md` or `.specforge/specs/SPEC-ID-<slug>.md`.

## Approval Gates

- `/sf-test SPEC-ID` means Plan artifacts were approved.
- `/sf-ship SPEC-ID` means red tests were approved.
- `/sf-finalize SPEC-ID` means the final diff was approved.
- Never move through a gate unless the human explicitly requests the next command.
