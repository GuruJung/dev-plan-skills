---
name: implement-dev-plan
description: Prepare, implement, evaluate, independently review, and integrate a saved new-format durable feature spec and local implementation plan, or diagnose and resume interrupted implementation. Use only when the user explicitly invokes "$implement-dev-plan", optionally with a feature ID.
---

# Implement Dev Plan

Keep implementation ownership in the foreground chat. Create a subagent only for independent review. Do not create a separate implementation agent.

Use the user's current conversation language for questions, status, and prose artifacts unless another language is requested. Preserve commands, identifiers, paths, enum values, and YAML or JSON keys exactly.

## Resolve the feature

Run only after an explicit `$implement-dev-plan [<feature-id>]` invocation. Resolve the absolute common Git directory and find an ID under `<git-common-dir>/dev-plan-workflow/plans/` in this order:

1. explicit ID;
2. the most recently planned, saved, or run feature in the conversation;
3. the feature associated with the current registered worktree;
4. the only nonterminal feature;
5. otherwise, show candidates and ask the user to choose.

Reject an unknown ID. Require `state.json` to have `schema_version` exactly `2` and `feature_type` equal to `standard` or `goal-loop`. For a nonterminal feature, require plain local `plan.md`, except that a plain `integration.complete` marker permits a missing plan for integration recovery below. Require either temporary `spec.md` or a committed tracked spec at the state's `spec_path`. When required new artifacts are missing or invalid, do not infer content or search other paths; stop without changes.

## Prepare a planned feature

When state is `planned`:

1. resolve the absolute common Git directory and registered worktrees;
2. find exactly one worktree with `refs/heads/main`;
3. add `/.worktrees/` once to `<git-common-dir>/info/exclude`;
4. require main to have a commit and be clean, including non-ignored untracked files;
5. fetch `origin/main` when configured, fast-forward local main when behind, and stop when refs diverge;
6. use branch `feature/<id>` and worktree `<main-worktree>/.worktrees/<id>`;
7. reuse both only when they exist and map consistently; if only one exists or either conflicts, stop without deletion, movement, reset, or overwrite;
8. otherwise create them with `git worktree add -b`;
9. complete feature-spec promotion below;
10. atomically set state to `prepared` and record canonical worktree, branch, spec-commit checkpoint, and timestamp.

Continue directly into implementation after preparation.

## Promote the feature spec

Resolve bundled `scripts/promote-spec.sh` relative to this SKILL.md and invoke it by absolute path:

```text
scripts/promote-spec.sh \
  --metadata-dir <git-common-dir>/dev-plan-workflow \
  --feature-worktree <feature-path> \
  --feature-id <id>
```

The helper verifies that every path component through Git common metadata and `plans/<id>` is a plain directory. It atomically copies temporary `spec.md` to the contract path `docs/dev-plans/specs/<id>/spec.md`, stages only that path, and creates commit `docs(spec): add <id>`. After verifying the commit and clean worktree, it removes only temporary spec and retains local `plan.md`. It preserves all artifacts and stops for another change, a conflicting destination, a symlink, a missing local plan, or commit failure.

On re-entry, when only tracked spec remains, require it to be committed at HEAD and use it as authoritative intent. When temporary and tracked specs both exist, use the helper to verify equality and finish promotion. Stop when they differ. Begin implementation and checkpoints from the spec commit.

Use the canonical feature worktree for every repository read, edit, command, test, and commit. Verify the expected branch before mutations.

## Apply current-spec impact

Before implementation, read `Current Spec Impact` from the tracked feature spec.

- When current spec is absent, create `docs/dev-plans/current-spec.md` with coverage stating that only decisions made under the new system are authoritative there, plus the approved current intent introduced by this feature.
- Apply `add`, `replace`, and `remove` as current-state statements without chronology or superseded text. Link a relevant feature spec when rationale is needed in current context.
- For `No change`, preserve the named invariants and do not edit current spec.
- When latest main's current spec conflicts semantically, do not choose an intent silently; re-plan.

## Diagnose re-entry

Treat a newly prepared feature with no implementation, eval, or review evidence as a first run. Otherwise inspect:

- local plan, tracked feature spec, current spec, and state;
- worktree, branch, HEAD, and merge-base with main;
- staged, unstaged, and untracked changes and commits after the merge-base;
- authoritative eval and review HEADs;
- native-goal state for a goal loop;
- integration and rollback evidence.

Treat Git as source of truth. Show metadata mismatches and repair them only after the user chooses a recovery action. Never discard, reset, or remove feature work without explicit approval.

When `<git-common-dir>/dev-plan-workflow/integration.pending` exists, block other integrations and require the matching feature to choose smoke recovery or main rollback.

## Implement a standard feature

Implement autonomously within the local plan while treating feature spec and current spec as authoritative intent. Ask when intent must be reinterpreted, an unsafe decision is required, or progress genuinely stalls.

Run the full eval contract and record command, result, duration, feature HEAD, and timestamp in `eval-results.json`. Require a clean worktree and logical commits before authoritative review.

## Run a native goal loop

Before code changes, read the complete local `Goal Contract` and tracked target and guardrails.

When goal tools exist, query the active goal. Adopt it only when feature ID and objective match. Do not replace another unfinished goal; require a pause, clear, or stop choice. When no goal exists, create it from the approved objective and pass a token budget only when an approved token count exists. Without goal tools, print the exact `/goal <objective>` and wait for the user to start it.

Start each experiment from clean baseline or current best checkpoint and change only the approved search space. Record measurement and guardrails, parameters, metric, duration, budget usage, and HEAD. Retain only valid improvements as best commits and restore failed or worse agent-owned changes to the best checkpoint. Never overwrite unexpected user or concurrent changes.

Enforce every budget. When budget is exhausted before target, do not mark complete; require re-planning or goal pause, edit, or clear. When target and guardrails are reproducibly verified, mark the goal complete, report final token usage returned by the goal tool when a token budget exists, and continue with full feature eval, independent review, and integration.

## Bind results and run independent review

Bind eval and review results to a clean feature HEAD and mark them stale after changes. For a goal loop, rerun full eval at the verified best checkpoint.

After full eval passes, create one reviewer subagent with isolated implementation context and provide only:

- tracked feature spec, relevant current spec, and acceptance criteria;
- comparison ref and feature HEAD;
- complete merge diff target;
- eval results.

The reviewer must work read-only and must not modify files, commit, push, post comments, or delegate. It must read applicable `AGENTS.md`, spec, current spec, and eval results, then inspect the complete diff from merge-base through feature HEAD, surrounding code for every changed path, relevant tests, and call sites. It must continue through the whole diff after finding the first issue and keep cited lines minimal and overlapping the reviewed diff.

Report a finding only when it has meaningful correctness, security, performance, or maintainability impact, is discrete and actionable, was introduced by this change, is demonstrated by a real scenario, and would probably be fixed by the author. Exclude speculation, pre-existing problems, intentional changes, and trivial style nits.

Order findings by severity and use `[P1] <imperative title> - path/to/file:line` with brief evidence. After findings, return an overall assessment, material test gaps or residual risk, and an explicit acceptance decision. P0 is a universal blocker, P1 urgent, P2 an ordinary defect, and P3 low impact. Accept only with no P0-P2. Fix P0-P2, rerun affected evals, and use the same reviewer for recheck during one uninterrupted review stage. Record P3 in `review.md` and state without blocking integration. If reviewer capability is unavailable, stop before integration.

## Revalidate main and build smoke

Find the unique clean main worktree and fetch `origin/main` when configured. Fast-forward when behind and stop as `integration-blocked` when diverged. Rebase feature when main is not its ancestor and re-plan conflicts that change intent.

When main changed after authoritative eval, rerun full eval and create a new reviewer when effective merge diff changed. Set `integration-ready`, `validated_feature_head`, and `validated_main_sha` only for a clean, fully evaluated, accepted HEAD.

Use latest successful eval durations and the plan threshold, default 60 seconds. Include every eval within the threshold as automatic smoke. Require at least one local, repeatable command without deployment or irreversible external side effects.

## Integrate

Invoke the bundled helper:

```text
scripts/integrate-feature.sh \
  --metadata-dir <git-common-dir>/dev-plan-workflow \
  --feature-id <id> \
  --main-worktree <main-path> \
  --feature-worktree <feature-path> \
  --expected-main <validated-main-sha> \
  --expected-feature <validated-feature-head> \
  --main-branch main \
  --smoke '<command>' [--smoke '<command>' ...]
```

The helper verifies that every path component through the feature metadata directory and local plan is plain. After every smoke passes, it atomically records `integration.complete`, removes local plan and the pending marker, and returns `integrated`. The marker records validated main and feature HEADs and worktrees so the same call can safely reproduce `integrated` after interruption between helper return and state update. Smoke rollback and recovery-required before marker creation preserve local plan. Use the same arguments with `--recover-pending smoke` or `--recover-pending rollback` for interrupted integration.

On `integrated`, atomically update state and only then remove `integration.complete`. On re-entry with a marker, reproduce the result with the same helper call when Git and marker agree. Return to revalidation for `stale-main` or `not-fast-forward`; set `needs-replan` for `smoke-rolled-back`; block further integration until main recovery for `recovery-required`. Terminal state may omit local plan.

Do not push or delete the feature branch or worktree automatically. Write shared state atomically.
