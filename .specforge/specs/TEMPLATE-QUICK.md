# TEMPLATE-QUICK — copy to SPEC-{NNN}-{slug}.md for a quick-lane spec

A quick spec IS its own design: no ALIGN.md, no DESIGN.md. The Description below
carries the rationale a DESIGN.md would otherwise hold. Use this only for small,
well-understood, single-component changes. Anything ambiguous or cross-cutting
goes through `/sf-plan` instead.

**Traces to:** (quick-spec: <one-line request>)
**State:** draft
**Lane:** quick
**Iteration:** <active iteration ID, or `none` if no plan is active>

## Description

<2-4 paragraphs. What this feature does, who uses it, why it exists, and the
one or two design choices that matter — the rationale that would live in a
DESIGN.md. Keep it self-contained. No code.>

## Acceptance criteria

- [ ] REQ-<AREA>-001: <observable, testable outcome>
- [ ] REQ-<AREA>-002: <observable, testable outcome>

## Tests

- [ ] tests/<path>/<file>.test.<ext>  (covers REQ-<AREA>-001)
- [ ] tests/<path>/<file>.test.<ext>  (covers REQ-<AREA>-002)

## Implementation

- [ ] src/<path>/<file>.<ext>

## Supersedes

- <optional: REQ-OLD-001 -> REQ-NEW-001>
