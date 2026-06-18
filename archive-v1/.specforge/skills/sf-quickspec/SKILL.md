---
name: sf-quickspec
description: Lightweight lane for a small, well-understood feature — the spec is the design (no ALIGN grill, no DESIGN.md), one human approval, one fresh-eyes review. Use for behavior changes too small for /sf-plan but too real for /sf-task.
---

# /sf-quickspec — the quick lane

> Between the lanes: `/sf-task` is for mechanical changes with no new behavior;
> `/sf-plan` is for complex or ambiguous work. `/sf-quickspec` is for a small,
> well-understood feature — real behavior, but one component, no
> architecturally-significant decision, no schema/public-API change, testable in
> a handful of cases.

You hold minimal context. Sub-agents do the work. The spec is the design — there
is no ALIGN grill and no DESIGN.md.

## Flow

1. **Design the spec.** Spawn the **quick-designer** (fresh sub-agent) with the
   request. It reads `.specforge/agents/quick-designer.md`, writes ONE
   self-contained SPEC (`**Lane:** quick`) from
   `.specforge/specs/TEMPLATE-QUICK.md`, and presents it. If it reports the
   change is bigger than a quick spec, route the user to `/sf-plan` and stop.
2. **Human approves the spec.** This single approval replaces the full lane's
   ALIGN + DESIGN gates. The quick-designer sets `**State:** approved` on
   approval — the one human gate in this lane.
3. **Build test-first.** Spawn the **builder** with `/sf-test SPEC-ID`
   (red tests), then `/sf-ship SPEC-ID` (implementation). The builder is
   lane-agnostic; it goes red → green like any spec.
4. **One fresh-eyes review.** Spawn the **sf-reviewer** (fresh sub-agent) at
   phase `done`. For a quick-spec it reviews the historical red-tests commit AND
   the implementation in one pass, writing both the `tests-red` and `done`
   receipts (`reviewer: sf-reviewer`). This is the single independent
   verification for the quick lane — there is no separate test-review gate.
5. **Finalize.** On PASS, run
   `bash .specforge/scripts/sf-finalize.sh SPEC-ID --autonomous`. The script
   re-validates both receipts before the fast-forward merge.

`/sf-loop` can also drive an approved quick spec end-to-end (it applies the same
single-gate rule). Manual or looped, the enforcement spine is unchanged: red
history is preserved, scope is enforced, and the merge gate requires PASS
receipts.

## Rules

- One spec only. If the request grows past one component or one design choice,
  stop and route to `/sf-plan` — never silently expand a quick spec.
- The quick lane drops the ALIGN grill, the DESIGN.md, and the separate
  test-review gate. It does NOT drop test-first, fresh-eyes review, or the
  receipt-gated merge.
