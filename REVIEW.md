# SpecForge Framework Review — 2026-06-10

Scope: full read of docs (`README`, `FLOW`, `SPEC-FORMAT`, `LEARNINGS-FORMAT`), all three
agent manuals, all skills, all scripts and libs, adapters, installer/updater, and the
test suite. All 9 tests pass on this machine. This document records confirmed bugs,
contract gaps (things the docs promise but no code delivers), and proposed improvements
to skills and phases, in priority order.

Overall verdict: the v2 shape is right. Three phases, three gates, disk as the only
state, builder.md as process canon, thin skills, bash-3.2 scripts — the discipline holds
together and the ENHANCEMENT round visibly tightened the lifecycle. The problems below
are mostly in the *mechanical enforcement* layer: two real bugs in the dependency
machinery, several places where a documented contract has no enforcement, and a couple
of duplication/drift risks in the agent manuals. No phase redesign is needed.

---

## P0 — Confirmed bugs

### B1. The DESIGN.md SPECS-table parser is dead — dependency machinery never runs

`sf_design_spec_order` and `sf_design_spec_deps` (`.specforge/scripts/lib/spec.sh:315-347`)
both start with:

```awk
/^\| *SPEC/ { header=1; next }
```

This pattern was evidently meant to match a header row, but the documented table header
(designer.md, templates/DESIGN.md, both tests) is `| ID | Title | Depends on |`. The
header never matches — instead **every data row** (`| SPEC-001 | … |`) matches and is
consumed by `next`. Verified empirically: with the documented format, both functions
return **nothing**.

Consequences:

- `sf status`'s "dependency-aware `Next:` line" (README:64, FLOW.md:140-144, CHANGELOG)
  is not dependency-aware. `sf-snapshot.sh:181-193` always sees an empty deps list, so
  the first *approved* spec in **file order** is suggested for `/sf-test` even when its
  dependency is unbuilt. Display ordering by the SPECS table (sf-snapshot.sh:77-103)
  also silently falls back to file order.
- `sf wave`'s `deps_satisfied` (`sf-wave.sh:79-94`) is vacuously true. Specs whose
  dependencies are not done are reported as parallel-ready; only file-overlap
  serialization still works.

No test covers this: `lifecycle-e2e.test.sh:106` and `wave.test.sh` write `Depends on`
columns but never assert dependency gating.

**Fix:** drop the header-flag approach; match data rows directly, e.g.
`/^\| *SPEC-[A-Z0-9]/ { split($0, cols, "|"); … }` in both functions. Add a unit test
that feeds the documented table and asserts order `SPEC-001 SPEC-002 SPEC-003` and
deps of `SPEC-002` = `SPEC-001`, plus a snapshot/wave test where an approved spec with
an unfinished dependency is *not* offered.

### B2. `sf wave` accepts a done-but-unmerged dependency, then builds from a base that lacks it

`deps_satisfied` (`sf-wave.sh:81-92`) treats a dependency as satisfied when its
*effective* state is `done` — which includes "done on its unmerged feature branch"
(that is exactly what `sf_spec_effective_state` is for). But the run instruction it
prints is `sf worktree create <id>`, and `sf-worktree.sh:35-36` creates the new branch
from the current HEAD (the base branch). The dependent spec's worktree therefore does
**not contain the dependency's implementation**, and its tests fail confusingly.

`sf-snapshot.sh` already has the correct, stricter semantics (`checkout_state_done`,
lines 155-162: dependency must be done *in the checkout*, i.e. merged). Align wave with
it: a dependency is satisfied iff its branch is an ancestor of the base branch or the
checkout copy is `done`. (After B1 is fixed this becomes load-bearing; today it is
masked by B1.)

### B3 (edge). Custom-path worktrees make state under-report

`sf_spec_effective_file` (`lib/spec.sh:278-304`) skips reading the feature-branch blob
whenever *any* worktree exists for the branch — but `sf_spec_display_file`
(`lib/spec.sh:195-216`) only looks in the default `.worktrees/<id>` locations. A
worktree created manually at a custom path is found by `sf_worktree_for_branch` (so the
branch blob is skipped) but not by `sf_spec_display_file` (so the worktree copy is never
read) → status falls back to the stale checkout copy. Fix: have
`sf_spec_effective_file` resolve the worktree path via `sf_worktree_for_branch` and read
the spec there, instead of hardcoding `.worktrees/`.

---

## P1 — Contract gaps (documented but unenforced)

### G1. `lint_command` and `build_command` are dead config

They appear in `config.yaml`, the `sf-init.sh` template, the README, and `sf doctor`
warns when they're *empty* (`sf-doctor.sh:84-85`) — but **nothing ever executes them**.
`sf-verify-build.sh:64-67` runs only the spec linter and `sf-test.sh`. So the Ship gate
("verify") never lints or builds the project, while the config implies it does.

Recommendation: run `build_command` then `lint_command` (when set) inside
`sf-verify-build.sh` after the test run, per-project in monorepos like `sf-test.sh`
does. If that's not wanted, delete the keys — a config field that doctor nags you to
fill but nothing reads is worse than no field.

### G2. "Abandon / re-plan the active iteration" has no mechanism

`sf-plan/SKILL.md:117-118` says new requirements never enter an active iteration
"unless the human explicitly asks to abandon or re-plan the active iteration" — but
there is no abandon path. `archive-reset` hard-requires approved ALIGN/DESIGN *and* all
specs done (`sf-iteration.sh:159-161`). An iteration that turns out to be wrong can only
be deleted by hand, losing the history the framework otherwise insists on.

Recommendation: `sf-iteration.sh archive-reset --abandon` — archives whatever exists
under the iteration's ID with `SUMMARY.md` marked `**Status:** abandoned` (and skips the
done-check), keeps NEXT.md, resets plan artifacts. Add a matching route to the sf-plan
skill: explicit human request → confirm → abandon-archive → run the Aligner.

### G3. Scope creep is prompt-enforced only — verify it mechanically

"Don't expand scope" and "no drive-by refactors" live only in builder.md prose. The SPEC
already declares the exact file lists (`## Tests`, `## Implementation`), and
finalize/verify know the branch and base — so this is cheaply checkable:
`git diff --name-only $(merge-base base branch)..branch`, minus declared paths, the spec
file itself, `LEARNINGS.md`, `CONTEXT.md`, and `docs/adr/`. Surface the remainder as a
**warning** in `sf-review.sh` ("files changed but not declared in the SPEC") and in
`sf-verify-build.sh`. This turns the framework's central promise — bounded work — into
something the human reviewer sees instead of has to hunt for. Keep it a warning, not an
error: minor spec edits mid-build are legal (SPEC-FORMAT.md § Editing a SPEC).

### G4. Requirement-ID reuse across iterations is not linted

"Implemented requirements are immutable; changed behavior gets a new `REQ-*` ID" is a
core rule (FLOW.md rule 8), and the Designer is told not to reuse IDs — but
`sf-lint-specs.sh:148-180` checks duplicates across **active** specs only. A Designer
that reuses `REQ-AUTH-001` from a finished iteration sails through lint, and the
registry silently merges the two histories into one row lineage. Fix: lint active REQ
IDs against archived spec files (`.specforge/iterations/*/specs/`) — any collision is an
error, no exceptions (supersession uses *new* IDs by definition).

### G5. `SPECFORGE_BASE_BRANCH` is undocumented

It is the only way to use a non-standard base branch, and it's discoverable solely via a
death message in `sf-finalize.sh:58`. One line in README ("Configure") and FLOW.md fixes
this.

---

## P2 — Smaller hardening and polish

1. **Lint: ticked file checkboxes should exist.** `- [x] tests/foo.test.ts` with no such
   file on the branch is a lie the linter could catch (run from the verify-build target
   checkout).
2. **Lint: DESIGN table ↔ spec files consistency** (worth doing once B1 makes the table
   load-bearing): every active SPEC appears in the SPECS table; every `Depends on`
   references a known spec; no cycles.
3. **`sf wave finalize` order** (`sf-wave.sh:99-124`): iterate in DESIGN-table order
   rather than file order, so dependents merge after dependencies once deps exist.
4. **Registry summary ignores `archived` rows** (`sf-registry.sh` summary counts only
   active/implemented/superseded). Unreachable today (archive requires all-done) but an
   abandoned-iteration archive (G2) would create exactly these rows — count them when
   G2 lands.
5. **`sf status --json`** — a machine-readable snapshot would let CI and other tooling
   consume phase state without scraping the table. Low effort given the data is already
   computed in one place.
6. **Finalize is local-only by design** (ff-merge, no push, no PR). Fine for the current
   workflow; consider an opt-in `sf finalize SPEC-ID --push` later. Do **not** rebuild
   v1's PR machinery.

---

## Skills and phases

### Phases: keep Plan → Test → Ship. Don't add any.

The v1 → v2 history (CHANGELOG: 6 phases/7 agents/35 scripts collapsed to 3/3/handful)
is the strongest argument in the repo: ceremony grew without quality. The three gates
map exactly to the three irreversible decisions (what to build, what "correct" means,
what merges). The two ideas I considered and recommend **against**:

- *A separate Retro/Close phase* — already covered by the LEARNINGS prompt in
  sf-finalize step 2 and the SUMMARY.md written by archive-reset.
- *Risk-tiered gates* (auto-advance test→ship for "trivial" specs) — dilutes the one
  invariant that makes the framework trustworthy. The human typing `/sf-ship` *is* the
  cheap path already.

### Skill-by-skill

- **sf-test/SKILL.md restates the builder process** (steps 3-7 duplicate builder.md
  steps 1-6). sf-ship was already slimmed to "gate semantics only; the manual is canon"
  — apply the same treatment to sf-test. Duplication is exactly where the last
  vocabulary drift came from.
- **aligner.md duplicates grill-with-docs almost verbatim** (challenge-the-glossary,
  sharpen-fuzzy-language, cross-reference-with-code, the 3-condition ADR test). Two
  copies of interviewing doctrine will drift. Make one canonical: keep the doctrine in
  `grill-with-docs/SKILL.md` (it's also independently useful) and have aligner.md
  reference it, keeping only the Align-specific parts (stop rule, ALIGN.md format,
  iteration ID, NEXT.md/REGISTRY handling) in the manual.
- **sf-review is the weakest skill relative to its job.** The human approves two gates
  through it, but it shows only counts and diffstat. Two cheap additions to
  `sf-review.sh`: (a) a per-REQ coverage table (REQ → covering test lines → ticked?),
  derivable from the spec alone; (b) the undeclared-changed-files warning from G3. That
  makes the review output answer the actual gate questions: "is every requirement
  tested?" and "did the builder stay inside the spec?"
- **New: `sf queue "<text>"` CLI helper.** Queueing a requirement currently requires an
  agent session running /sf-plan State 0 just to append a bullet to NEXT.md. A tiny
  `sf queue` subcommand (creates NEXT.md from the template if absent, appends one
  bullet, dates it) lets the human capture requirements the moment they think of them.
  The /sf-plan State-0 route stays as-is for in-session queueing.
- **QUICKSTART.md is a stub** (4 lines of pointers). Either delete it or make it earn
  its name. Recommendation: replace it with a *worked example* — one tiny iteration
  (ALIGN → DESIGN → one SPEC → red tests → ship → finalize) with real file contents.
  Agents imitate examples far more reliably than they follow rules; the repo currently
  contains no complete example of a good SPEC.

### Tests to add alongside

- DESIGN-table parsing unit test with the documented header (catches B1; would have
  caught it on day one).
- Dependency gating: approved spec with unfinished dep is not offered by `sf status`
  and is serialized by `sf wave`; done-but-unmerged dep does not count (B2).
- Scope warning: undeclared file in branch diff produces the verify/review warning (G3).
- REQ reuse across an archived iteration fails lint (G4).
- Abandon path: archive marked abandoned, NEXT.md survives, plan artifacts reset (G2).

---

## Suggested work order

| # | Item | Size |
|---|------|------|
| 1 | B1 parser fix + parsing/gating tests | S |
| 2 | B2 wave dep semantics (with B1's tests) | S |
| 3 | G1 wire build/lint commands into verify (or delete keys) | S |
| 4 | G3 undeclared-file warning in review + verify | M |
| 5 | G4 REQ-reuse lint vs archives | S |
| 6 | G2 abandon path + skill route | M |
| 7 | sf-review coverage table; slim sf-test skill; de-dupe aligner/grill | M |
| 8 | `sf queue`, QUICKSTART worked example, G5 doc line, B3, P2 polish | M |

Items 1-2 change behavior the docs already promise; they are bug fixes, not features.
Items 3-6 close the gap between what the framework *says* it enforces and what it
actually enforces — which, for a framework whose entire value is enforced discipline,
is the highest-leverage work available.
