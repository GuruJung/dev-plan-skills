---
name: save-approved-plan
description: Persist the latest finalized standard or goal-loop feature plan into shared Git metadata without preparing or implementing it. Use only when the user explicitly invokes "$save-approved-plan" after completing a plan with plan-feature.
---

# Save Approved Plan

Save one finalized feature plan only. Never treat saving as implementation approval.

Use the user's current conversation language for questions, status, and prose artifacts unless the
user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and
machine-readable schema keys exactly.

## Check the handoff

If Plan mode is active, ask the user to switch to Default mode and invoke `$save-approved-plan`
again. Do not write files.

Use the latest finalized `$plan-feature` plan in the conversation. Require:

- a unique `feature_id`;
- `feature_type` equal to `standard` or `goal-loop`;
- scope, acceptance criteria, and implementation approach;
- executable eval commands with success conditions;
- per-eval post-merge selection and at least one eligible smoke;
- an approved smoke threshold;
- a complete `Goal Contract` for `goal-loop`.

If the plan is absent, incomplete, or outside the supported feature types, do not invent content.
Ask the user to return to Plan mode and invoke `$plan-feature`.

## Persist the feature

1. Resolve the repository and absolute common Git directory.
2. Reuse the finalized `YYYYMMDD-<slug>` ID. If it now collides, append the next numeric suffix
   and update the saved plan consistently.
3. Create `<git-common-dir>/feature-workflow/features/<id>/`.
4. Save the complete plan as `plan.md` without changing approved decisions.
5. Create `state.json` atomically with:

   ```json
   {
     "schema_version": 1,
     "id": "<id>",
     "title": "<title>",
     "feature_type": "<standard-or-goal-loop>",
     "status": "planned",
     "base_branch": "main",
     "branch": "feature/<id>",
     "worktree": null,
     "created_at": "<ISO-8601>",
     "updated_at": "<ISO-8601>",
     "last_checkpoint": null,
     "validated_feature_head": null,
     "validated_main_sha": null,
     "last_failure": null,
     "remaining_p3": [],
     "goal": null
   }
   ```

6. For `goal-loop`, replace `goal: null` with:

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

   Populate the approved budgets and baseline from the plan. Leave unselected budget dimensions
   null.

7. Use a temporary file in the destination directory followed by atomic rename for state writes.
8. Do not create a branch or worktree, implement, test, commit, or push.
9. Report the saved ID and path, then show `$run-feature <id>` as the next explicit command.

Never overwrite an existing feature plan without explicit user approval.
