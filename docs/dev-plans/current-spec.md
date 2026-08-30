# Current Development Intent

## Coverage

This document is authoritative only for current intent introduced or revised by feature specs
under `docs/dev-plans/specs/` from 2026-08-30 onward. Absence from this document does not cancel a
constraint outside that coverage.

## Development-plan artifacts

- A feature plan separates durable `Tracked Feature Spec` content from a disposable
  `Local Implementation Plan`.
- Feature specs are tracked at `docs/dev-plans/specs/<id>/spec.md` and preserve the change intent,
  user decisions, rationale, and semantic acceptance criteria.
- This file contains only currently valid intent. It replaces or removes superseded statements
  instead of accumulating a chronological log.
- Local plans remain under `<git-common-dir>/dev-plan-workflow/plans/<id>/plan.md`, are not tracked,
  and are deleted only after successful integration smoke.
- Source code and tests are the source of truth for actual behavior. This document is the source
  of intent within its declared coverage.

## Workflow

- `$create-dev-plan` reads this file first, then inspects code and only linked relevant feature
  specs when rationale is needed.
- `$save-dev-plan` atomically saves standalone `spec.md`, `plan.md`, and schema-v2 `state.json` in
  Git common metadata without modifying a worktree or branch.
- `$implement-dev-plan` promotes only the feature spec, applies its `Current Spec Impact`, and uses
  the local plan solely as an execution artifact. Successful smoke writes a durable completion
  marker before deleting the plan; state becomes terminal before that marker is cleared.
- A feature whose current intent is unchanged still records the invariants and acceptance criteria
  in its feature spec, but does not edit this file merely for provenance or a timestamp.

The decision source for this section is
[`20260830-separate-specs-and-local-plans`](specs/20260830-separate-specs-and-local-plans/spec.md).
