---
name: create-dev-plan
description: Interview the user and produce a standard or native-goal-loop development plan that separates a durable feature spec from a local implementation plan, with a save-only handoff. Use only when the user explicitly invokes "$create-dev-plan" in Plan mode.
---

# Create Dev Plan

Plan only. Do not write files, create branches, implement, or run mutating commands.

Use the user's current conversation language for questions, status, and prose artifacts unless the user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and YAML or JSON keys exactly.

## Require Plan mode

If Plan mode is not active, ask the user to switch to Plan mode and invoke `$create-dev-plan` again. Stop without changing repository state.

## Ground the interview

Inspect the repository before asking questions. Read applicable instructions, relevant code, configuration, tests, and existing conventions. Resolve discoverable facts directly.

When `docs/dev-plans/current-spec.md` exists, read it first for current product intent. Read only `docs/dev-plans/specs/*/spec.md` documents that are relevant to the task and linked from the current spec when decision rationale is needed. Do not infer intent outside current-spec coverage from code; ask the user when that intent is material.

After exploration, classify the feature type:

- `standard`: a bounded implementation with explicit acceptance and eval criteria;
- `goal-loop`: repeated implementation or tuning against a measurable target.

When the type is clear, select it directly, briefly report the selection, and continue with that interview. Only when it remains unclear after exploration, require a choice between `standard` and `goal-loop`. Localize displayed labels while preserving these internal values and use structured user input when available. Do not offer another type.

## Separate durable intent from execution information

Classify each requirement and decision using these rules:

- Put outcomes, observable behavior, public contracts, exclusions, constraints, failure and recovery expectations, decision rationale, and semantic acceptance criteria that must survive a complete implementation replacement in `Tracked Feature Spec`.
- Put code-derived files, symbols, internal flow, implementation order, commands, checkpoints, one-time budgets, and operational procedure in `Local Implementation Plan`.
- Do not put short-lived execution choices in the tracked spec or present implementation details as current product intent.

## Interview a standard feature

Keep asking material questions until the following are fixed:

- intended outcome, audience, and definition of done;
- in-scope and excluded behavior;
- compatibility, security, performance, and operational constraints;
- failure modes and recovery expectations;
- implementation approach and material interfaces or data flows;
- executable eval commands and success conditions;
- independent-review acceptance;
- automatic smoke threshold, defaulting to 60 seconds;
- rollout, migration, or monitoring only when needed.

Treat every eval as an automatic smoke candidate. Do not ask for or record per-eval selection. Require at least one eval verified or reasonably expected to finish within the threshold.

## Interview a goal-loop feature

In the durable feature spec, fix the outcome, metric and unit, optimization direction, numeric target and tolerance, correctness, performance, and quality guardrails, allowed and forbidden changes, and compatibility constraints.

In the local plan, fix the reproducible baseline and measurement commands, success interpretation, at least one of maximum iterations, wall-clock duration, or token budget, best-so-far comparison and checkpoint rules, tie-breaker, reporting, stopping, and re-planning conditions, full final eval, and automatic post-merge smoke contract.

Inspect likely eval cost and recommend concrete budget choices. Do not choose a default when the user is silent. Require explicit approval of at least one numeric budget and include a native token budget only when the user approves a token count.

Construct a native goal objective of at most 4,000 characters. Include outcome, metric target, constraints, verification, and the future local plan path. Keep detailed experiment instructions in the plan.

Use this checkpoint policy:

- begin from a clean baseline commit;
- retain only guardrail-valid improvements as best-so-far commits;
- record every experiment result;
- restore failed or worse agent-owned experiments to the best checkpoint;
- stop rather than discard unexpected user or concurrent changes.

The native goal ends when target and guardrails are verified. Independent review and integration remain later `$implement-dev-plan` stages.

## Fix current-spec impact

In `Tracked Feature Spec`, make `Current Spec Impact` state exactly which current intentions to add, replace, or remove in `docs/dev-plans/current-spec.md`. When no current spec exists, include creation of the initial file with coverage limited to decisions made under the new system and the current intent introduced by this feature.

For a pure refactor or another change that preserves current intent, write `No change` and state the invariants to preserve. Do not plan a provenance-only or timestamp-only current-spec edit.

## Finalize the plan

Generate `YYYYMMDD-<slug>` from the feature title. Inspect `<git-common-dir>/dev-plan-workflow/plans/`, `docs/dev-plans/specs/<id>/spec.md` in the main worktree, branches, and registered worktrees read-only. Append `-2`, `-3`, and so on for a collision.

Allow only `standard` or `goal-loop` in final frontmatter:

```yaml
---
feature_id: <id>
title: <title>
feature_type: <standard-or-goal-loop>
base_branch: main
spec_path: docs/dev-plans/specs/<id>/spec.md
current_spec_path: docs/dev-plans/current-spec.md
plan_path: <git-common-dir>/dev-plan-workflow/plans/<id>/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---
```

Include these two top-level sections:

1. `Tracked Feature Spec`: summary, requirements and exclusions, `Current Spec Impact`, user decisions, and acceptance criteria.
2. `Local Implementation Plan`: implementation approach, work sequence, eval contract, and execution decisions.

Include a localized `User Decisions` section in every tracked spec. Record the decision topic, the user's selection, any stated reason or tradeoff, and its scope. When no reason was given, say so instead of inventing one. Do not record repository facts or agent defaults as user decisions.

For a goal loop, put durable target and guardrails in the tracked spec and the complete `Goal Contract`, including native objective and budgets, in the local plan.

Produce the decision-complete plan in the required Plan-mode format.

End with a localized blockquote explaining that the host's "Implement this plan" action switches to Default mode and delegates only temporary Git-common-metadata persistence to `$save-dev-plan`. It does not authorize implementation, branch or worktree creation, or `$implement-dev-plan`. After the user explicitly invokes `$implement-dev-plan <id>`, only the feature spec is promoted into Git while the local plan remains in metadata until successful integration. When automatic handoff does not start, tell the user to invoke `$save-dev-plan` explicitly in Default mode. Save nothing while the user continues planning.
