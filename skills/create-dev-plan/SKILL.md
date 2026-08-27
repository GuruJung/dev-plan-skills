---
name: create-dev-plan
description: Interview the user and produce a decision-complete standard or native-goal-loop development plan with a save-only implementation handoff. Use only when the user explicitly invokes "$create-dev-plan" in Plan mode.
---

# Create Dev Plan

Plan only. Do not write files, create branches, implement, or run mutating commands.

Use the user's current conversation language for questions, status, and prose artifacts unless the
user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and
machine-readable schema keys exactly.

## Require Plan mode

If Plan mode is not active, ask the user to switch to Plan mode and invoke `$create-dev-plan` again.
Stop without changing repository state.

## Ground the interview

Inspect the repository before asking questions. Read applicable instructions, relevant code,
configuration, tests, and existing conventions. Resolve discoverable facts directly.

Also inspect the localized user-decision sections of relevant prior plans under
`docs/superpowers/plans/*/plan.md`. Preserve repository-wide decisions when they do not conflict
with the current request. Treat feature-specific decisions as context only. Do not silently apply
a prior decision to a different scope or let it override a conflicting current request.

After this exploration, classify the feature type from the repository evidence and the user's
request:

- `standard`: a bounded implementation with explicit acceptance and eval criteria;
- `goal-loop`: repeated implementation or tuning against a measurable target;

When the type is clear, select `standard` or `goal-loop` directly, briefly tell the user which type
you selected, and proceed immediately with that interview. Do not ask a feature-type question.

Only when the type remains unclear after exploration, require the user to choose between `standard`
and `goal-loop`. Localize the displayed labels to the current conversation language while
preserving these internal values. Use the structured user-input tool when available.

Do not offer any choice other than `standard` or `goal-loop`.

## Interview a standard feature

Keep asking material questions until the plan fixes:

- intended outcome, audience, and definition of done;
- in-scope and excluded behavior;
- compatibility, security, performance, and operational constraints;
- implementation approach and material interfaces or data flows;
- failure modes and recovery expectations;
- executable eval commands and their success conditions;
- independent-review acceptance;
- automatic smoke threshold, defaulting to 60 seconds;
- rollout, migration, or monitoring only when the feature needs them.

Treat every eval as an automatic smoke candidate. Do not ask for or record a per-eval smoke
selection. Require at least one eval that is verified or reasonably expected to run within the
threshold.

## Interview a goal-loop feature

Fix the complete experiment contract:

- outcome;
- metric, unit, and optimization direction;
- baseline value and reproducible baseline command;
- numeric target and tolerance;
- measurement command and success interpretation;
- correctness, performance, and quality guardrails;
- allowed code, configuration, parameter, and search space;
- forbidden changes and compatibility constraints;
- at least one execution budget: maximum iterations, wall-clock duration, or token budget;
- best-so-far comparison and checkpoint rule;
- tie-breaker when primary metrics are equal;
- conditions for reporting, pausing, or re-planning;
- full final eval and automatic post-merge smoke contract.

Inspect likely eval cost, then recommend concrete budget options. Do not choose a default when the
user is silent. Require explicit approval of at least one numeric budget. Include a native token
budget only when the user explicitly approves a token count.

Construct a native goal objective of at most 4,000 characters. Make it cover only finding and
verifying an implementation that reaches the target while preserving guardrails. Include outcome,
metric target, constraints, verification, and the future saved plan path. Put detailed experiment
instructions in the plan rather than overloading the objective.

Use this checkpoint policy:

- begin from a clean baseline commit;
- retain only guardrail-valid improvements as best-so-far commits;
- record every experiment result;
- restore failed or worse agent-owned experiments to the best checkpoint;
- stop rather than discard unexpected user or concurrent changes.

The native goal ends when the target and guardrails are verified. Independent review and
integration remain later `$implement-dev-plan` stages, outside native-goal completion.

## Finalize the plan

Generate `YYYYMMDD-<slug>` from the feature title. Inspect
`<git-common-dir>/dev-plan-workflow/plans/` and
`docs/superpowers/plans/<id>/plan.md` in the main worktree read-only. Append `-2`, `-3`, and so on
for a collision.

Allow only `standard` or `goal-loop` in the final frontmatter:

```yaml
---
feature_id: <id>
title: <title>
feature_type: <standard-or-goal-loop>
base_branch: main
plan_path: docs/superpowers/plans/<id>/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---
```

For a goal loop, include a `Goal Contract` section containing every approved experiment field,
including the native objective and budgets.

Include a localized `User Decisions` section in every plan. Record the decision topic, the user's
selection, any reason or tradeoff the user stated, and its scope. When the user gave no reason,
say so rather than inventing one. Do not record repository facts or agent-selected defaults that
the user did not approve as user decisions.

Produce the decision-complete plan in the required Plan-mode format.

End with a localized blockquote explaining that the host's "Implement this plan" action switches
to Default mode and delegates only temporary persistence under
`<git-common-dir>/dev-plan-workflow/` to `$save-dev-plan`. This selection does not authorize
implementation, branch or worktree creation, or `$implement-dev-plan`. The plan is promoted and
committed as `docs/superpowers/plans/<id>/plan.md` in the feature worktree only after the user
explicitly invokes `$implement-dev-plan <id>`. When the automatic handoff does not start or the
host has no native implementation action, tell the user to switch to Default mode and invoke
`$save-dev-plan` explicitly. Save nothing when the user keeps planning.
