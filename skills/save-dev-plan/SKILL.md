---
name: save-dev-plan
description: Persist the latest finalized durable feature spec and local implementation plan into shared Git metadata, then delegate implementation when an approved same-conversation `$create-dev-plan` handoff requests it. Use only when the user explicitly invokes "$save-dev-plan" or that handoff delegates persistence.
---

# Save Dev Plan

Save one finalized feature's tracked spec and local plan. An explicit `$save-dev-plan` invocation is save-only. An approved `$create-dev-plan` handoff delegates the same feature to `$implement-dev-plan` after saving succeeds. Never treat an ordinary save or the marker alone as implementation approval.

Use the user's current conversation language for questions, status, and prose artifacts unless another language is requested. Preserve commands, identifiers, paths, enum values, and YAML or JSON keys exactly.

## Check the handoff

If Plan mode is active, ask the user to switch to Default mode and invoke `$save-dev-plan` again. Do not write files.

Allow the invocation only when either condition is true:

1. The user explicitly invoked `$save-dev-plan`.
2. The latest finalized same-conversation `$create-dev-plan` plan contains the handoff below and the user selected the host's "Implement this plan" action before entering Default mode.

```yaml
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: implement-dev-plan
```

When an existing plan has the same fields with `continuation: save-only`, continue to allow it as a legacy save-only handoff without entering implementation. Do not infer selection from the marker alone. The handoff does not survive a new conversation.

For a `continuation: implement-dev-plan` handoff, before writing files, read `../implement-dev-plan/SKILL.md` relative to this SKILL.md and verify that its frontmatter `name` is `implement-dev-plan`. When the sibling is missing or invalid, do not search elsewhere or install it; stop without changes. Do not require the sibling for an explicit `$save-dev-plan` invocation or a legacy `save-only` handoff.

## Validate the finalized artifacts

Require the latest finalized `$create-dev-plan` plan to contain:

- a unique `feature_id` and `feature_type` equal to `standard` or `goal-loop`;
- `spec_path` in the form `docs/dev-plans/specs/<id>/spec.md`;
- `current_spec_path` equal to `docs/dev-plans/current-spec.md`;
- `plan_path` equal to `<git-common-dir>/dev-plan-workflow/plans/<id>/plan.md`;
- complete `Tracked Feature Spec` and `Local Implementation Plan` sections;
- `Current Spec Impact`, user decisions, and semantic acceptance criteria in the tracked spec;
- implementation approach, executable evals with success conditions, and an approved smoke threshold in the local plan;
- an automatic smoke contract for every eval and at least one eval expected within the threshold;
- for a goal loop, durable target and guardrails plus a complete local `Goal Contract`.

When content is missing or incomplete, do not invent it. Ask the user to return to Plan mode and invoke `$create-dev-plan` again.

## Persist the feature

On a `continuation: implement-dev-plan` handoff retry, regardless of whether save success was reported, inspect the finalized plan's proposed ID, its existing numeric-suffix metadata candidates, and only IDs reported as saved for this finalized plan earlier in the same conversation. Before reading a candidate, require every path component from the absolute Git common metadata directory through the candidate directory and every candidate artifact to be plain. When using a committed tracked spec, also require its contract path inside a registered worktree and every path component to be plain. Do not follow a symbolic link or other non-plain path; stop without changes as an unsafe conflict. Reuse an existing ID when exactly one complete destination has a state whose ID and paths, temporary or committed tracked spec, and local plan when present match the two finalized sections split with the same ID normalization and the new schema. When a terminal state or valid `integration.complete` permits a missing local plan, bind identity through the matching state and tracked spec plus the same-conversation finalized plan. When multiple destinations match or an ID previously reported for this finalized plan mismatches, do not create a suffix or new metadata; show the candidates or mismatch and wait for a recovery choice. When no destination matches, continue with ordinary collision handling below.

1. When there is no reusable saved feature, use the finalized ID. If Git metadata, the new `spec_path`, a branch, or a registered worktree collides, append the next numeric suffix and update every feature-ID-bearing field and path consistently. Do not rewrite unrelated prose.
2. Under `<git-common-dir>/dev-plan-workflow/plans/`, create a unique staging directory on the same filesystem as the destination. Do not change an existing destination without explicit overwrite approval.
3. Save `Tracked Feature Spec` as standalone `spec.md` with this frontmatter. Do not reinterpret approved wording or add local execution information.

   ```yaml
   ---
   feature_id: <id>
   title: <title>
   feature_type: <standard-or-goal-loop>
   current_spec_path: docs/dev-plans/current-spec.md
   ---
   ```

4. Save `Local Implementation Plan` as standalone `plan.md` with this execution frontmatter. Point to `spec_path` instead of duplicating the tracked spec.

   ```yaml
   ---
   feature_id: <id>
   title: <title>
   feature_type: <standard-or-goal-loop>
   base_branch: main
   spec_path: docs/dev-plans/specs/<id>/spec.md
   current_spec_path: docs/dev-plans/current-spec.md
   smoke_threshold_seconds: 60
   ---
   ```

5. Write this `state.json` in staging:

   ```json
   {
     "schema_version": 2,
     "id": "<id>",
     "title": "<title>",
     "feature_type": "<standard-or-goal-loop>",
     "status": "planned",
     "base_branch": "main",
     "branch": "feature/<id>",
     "worktree": null,
     "spec_path": "docs/dev-plans/specs/<id>/spec.md",
     "current_spec_path": "docs/dev-plans/current-spec.md",
     "created_at": "<ISO-8601>",
     "updated_at": "<ISO-8601>",
     "last_checkpoint": null,
     "validated_feature_head": null,
     "validated_main_sha": null,
     "integrated_main_sha": null,
     "last_failure": null,
     "remaining_p3": [],
     "goal": null
   }
   ```

6. For a goal loop, replace `goal: null` with the object below and populate the approved objective, budgets, and baseline. Leave unselected budget dimensions `null`.

   ```json
   {
     "objective": "<approved-native-objective>",
     "native_status": "not-started",
     "budgets": {
       "max_iterations": null,
       "max_wall_time_seconds": null,
       "token_budget": null
     },
     "iterations_used": 0,
     "elapsed_seconds": 0,
     "baseline_metric": null,
     "best_metric": null,
     "best_checkpoint": null,
     "last_measurement": null,
     "stop_reason": null
   }
   ```

7. Verify that all three staging artifacts are plain files and match the finalized content, then atomically rename the staging directory to the destination. On failure, do not create a partial destination; remove only agent-owned staging.
8. During the save stage itself, do not modify the main worktree, a branch, or the index, and do not implement, test, commit, or push.
9. For an explicit `$save-dev-plan` invocation or a legacy `save-only` handoff, report the saved ID, temporary spec and plan paths, and eventual `spec_path`. Show `$implement-dev-plan <id>` as the next manual command without invoking it.
10. For an approved handoff, only after newly saving or reusing a verified saved feature, immediately apply the sibling `$implement-dev-plan` contract as a delegated invocation with the resolved ID. Do not enter implementation after a save failure, mismatch, pending user choice, or failed sibling preflight. Do not request another confirmation between saving and implementation, and preserve every `$implement-dev-plan` safety stop and recovery rule.

Never overwrite an existing saved feature without explicit user approval.
