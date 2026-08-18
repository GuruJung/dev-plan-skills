---
name: plan-feature
description: Interview the user and produce a decision-complete implementation plan for a standard or native-goal-loop software feature. Use only when the user explicitly invokes "$plan-feature" before saving or implementation, or when `$plan-run-feature` delegates its approved Plan phase.
---

# Plan Feature

Plan only. Do not write files, create branches, implement, or run mutating commands.

Use the user's current conversation language for questions, status, and prose artifacts unless the
user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and
machine-readable schema keys exactly.

## Require Plan mode

If Plan mode is not active, ask the user to switch to Plan mode and invoke `$plan-feature` again.
Delegation from `$plan-run-feature` also requires Plan mode. Stop without changing repository state.

## Ground the interview

Inspect the repository before asking questions. Read applicable instructions, relevant code,
configuration, tests, and existing conventions. Resolve discoverable facts directly.

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
- post-merge smoke selection for every eval: `auto`, `always`, or `never`;
- smoke threshold, defaulting to 300 seconds;
- rollout, migration, or monitoring only when the feature needs them.

Require at least one post-merge smoke command.

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
- full final eval and post-merge smoke contract.

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
integration remain later `$run-feature` stages, outside native-goal completion.

## Finalize the plan

Generate `YYYYMMDD-<slug>` from the feature title. Inspect
`<git-common-dir>/feature-workflow/features/` read-only and append `-2`, `-3`, and so on for a
collision.

Allow only `standard` or `goal-loop` in the final frontmatter:

```yaml
---
feature_id: <id>
title: <title>
feature_type: <standard-or-goal-loop>
base_branch: main
smoke_threshold_seconds: 300
---
```

For a goal loop, include a `Goal Contract` section containing every approved experiment field,
including the native objective and budgets.

Produce the decision-complete plan in the required Plan-mode format.

For an ordinary `$plan-feature` invocation, end with a localized blockquote telling the user to
switch to Default mode and explicitly invoke `$save-approved-plan` to save the plan.

For an invocation delegated by `$plan-run-feature`, add `execution_handoff: plan-run-feature` to
the frontmatter. End with a localized blockquote explaining that choosing "Implement this plan"
continues with plan persistence and execution in Default mode, with an explicit
`$plan-run-feature` invocation in Default mode as the fallback when automatic continuation does
not start.
