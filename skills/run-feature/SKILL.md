---
name: run-feature
description: Prepare, implement, evaluate, independently review, and integrate a saved standard or goal-loop feature, or diagnose and resume an interrupted feature. Use only when the user explicitly invokes "$run-feature", optionally with a feature ID.
---

# Run Feature

Keep implementation ownership in the foreground chat. Create a subagent only for independent
review. Do not create a separate implementation agent.

Use the user's current conversation language for questions, status, and prose artifacts unless the
user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and
machine-readable schema keys exactly.

## Resolve the feature

Accept `$run-feature [<feature-id>]`. Resolve in this order:

1. explicit ID;
2. the most recently planned, saved, or run feature in the conversation;
3. the feature associated with the current registered worktree;
4. the only nonterminal feature;
5. otherwise, show candidates and ask the user to choose.

Reject an unknown ID. Read `plan.md` and `state.json`. Require `standard` or `goal-loop`.

## Prepare a planned feature

When state is `planned`, perform preparation before implementation:

1. resolve the absolute common Git directory and parse `git worktree list --porcelain`;
2. find exactly one worktree with `refs/heads/main`;
3. add `/.worktrees/` once to `<git-common-dir>/info/exclude`;
4. require main to have a commit and be clean, including non-ignored untracked files;
5. fetch `origin/main` when configured;
6. fast-forward local main when behind, continue when equal or ahead, and stop when refs diverge;
7. use branch `feature/<id>` and worktree `<main-worktree>/.worktrees/<id>`;
8. if both already exist and are consistently mapped, reuse them;
9. if only one exists or either conflicts, stop without deleting, moving, resetting, or overwriting;
10. otherwise create them with `git worktree add -b`;
11. atomically set state to `prepared`, record the canonical worktree path, branch, checkpoint,
    and timestamp.

Continue directly into implementation after successful preparation. Do not ask for an additional
confirmation.

Use the canonical feature worktree as the working root for every repository read, edit, command,
test, and commit. Verify the expected branch before mutations. Modify main only through the
documented synchronization steps and integration helper.

## Diagnose re-entry

Treat a newly prepared feature with no implementation, eval, or review evidence as a first run.
Otherwise inspect:

- plan and state;
- registered worktrees, branch, HEAD, and merge-base with main;
- staged, unstaged, and untracked changes;
- commits after the merge-base;
- authoritative eval and review HEADs;
- native goal state for a goal loop;
- integration and rollback evidence.

Treat Git as source of truth. When metadata disagrees, show the mismatch and repair it only after
the user chooses a recovery action. Offer relevant choices such as preserving changes, making a
checkpoint, rerunning eval, restarting review, retrying integration, or re-planning.

Never discard, reset, or remove feature work without explicit approval.

If `<git-common-dir>/feature-workflow/integration.pending` exists, block other integrations. For
the matching feature, offer:

- rerun smoke with `--recover-pending smoke`;
- roll main back with `--recover-pending rollback`.

Require an explicit choice.

## Implement a standard feature

Implement the approved plan autonomously within scope. Ask the user when requirements need
reinterpretation, an unsafe decision is required, or progress genuinely stalls.

Run the complete eval contract and record command, result, duration, feature HEAD, and timestamp
in `eval-results.json`. Checkpoint commits are allowed. Before authoritative review, require a
clean worktree and logical commits.

## Run a native goal loop

Read the complete `Goal Contract` before changing code.

### Establish the native goal

1. Query the active native goal when goal tools are available.
2. If it matches this feature ID and objective, adopt it.
3. If another unfinished goal exists, do not replace it. Ask the user whether to pause or clear it,
   or stop this feature. Use available goal controls; otherwise provide the exact `/goal pause` or
   `/goal clear` command and wait.
4. If no goal exists, create it from the approved objective.
5. Pass a token budget only when the plan contains a user-approved token count.
6. If goal tools are unavailable, output the exact `/goal <objective>` command and wait for the
   user to start it.

Keep the objective non-empty and at most 4,000 characters. Point it to the saved plan for detailed
experiment instructions.

### Iterate

1. measure and record the clean baseline;
2. start each experiment from the current best checkpoint;
3. modify only the approved search space;
4. run the measurement and every guardrail;
5. record parameters, metric, guardrails, duration, budget usage, and resulting HEAD;
6. when the result is valid and better under the approved comparison and tie-breaker, create a
   best-so-far checkpoint commit and update state;
7. otherwise preserve the record and restore only agent-owned experiment changes to the best
   checkpoint;
8. stop rather than overwrite unexpected user or concurrent changes.

Enforce every selected budget. If the target is not reached when a budget is exhausted, do not
mark the goal complete. Ask the user to re-plan or choose goal pause, edit, or clear.

When the target and guardrails are reproducibly verified, mark the native goal complete. For a
token-budgeted goal, report final token usage returned by the goal tool. Then continue with the
feature's full eval, independent review, and integration; those stages are not part of native-goal
completion.

## Bind authoritative results

Bind authoritative eval and review results to a clean feature HEAD. Mark them stale after any
change. For a goal loop, use the verified best checkpoint as the candidate HEAD and run the full
feature eval contract even if individual measurement commands already passed.

## Run independent review

After full eval passes, create one fresh reviewer subagent with isolated implementation context
when supported and tell it to perform the review contract below directly. Provide only:

- `plan.md` and acceptance criteria;
- comparison ref and feature HEAD;
- complete merge diff target;
- eval results.

The reviewer must work read-only. It must not modify files, create commits, push branches, post
review comments, or delegate to another agent. It must read the applicable `AGENTS.md`, supplied
plan, acceptance criteria, and eval results.

It must compute the merge base of the supplied feature HEAD and comparison ref, then inspect the
complete change that would merge with `git diff <merge-base-sha> <feature-head>`. It must read
enough surrounding code for every changed path and continue through the whole diff after finding
the first issue. It must inspect relevant tests and call sites to verify that each finding is real
and actionable. It must independently verify the acceptance criteria and look for correctness,
security, performance, regression, unsafe behavior, missing tests, and maintainability problems.

Report a finding only when all of these are true:

- it has a meaningful correctness, security, performance, or maintainability impact;
- it is discrete and actionable;
- the reviewed change introduced it;
- the affected scenario or call path can be demonstrated from the code;
- the author would probably fix it if they knew about it.

Do not report speculative concerns, pre-existing problems, intentional behavior changes, or style
nits that do not obscure the code.

Use these priorities: P0 for a universal release blocker or critical failure, P1 for an urgent
defect that should be fixed next, P2 for an ordinary defect that should be fixed, and P3 for a
low-impact issue that is still worth fixing.

Present findings first, ordered by severity. Use
`[P1] <imperative finding title> - path/to/file:line` followed by a short paragraph that explains
the affected scenario and why the behavior is wrong. Keep the cited lines as small as possible and
make them overlap the reviewed diff. If there are no qualifying findings, say so without inventing
one. After the findings, return an overall assessment, any material test gaps or residual risks,
and an explicit acceptance decision. Accept only when no P0-P2 findings remain; otherwise reject.

Keep the same reviewer for follow-up during one uninterrupted review stage. If unavailable after
resume, create a fresh reviewer.

- Fix P0-P2, rerun affected evals, and request recheck.
- Record P3 in `review.md` and `state.json`; do not block integration on P3.
- Require no remaining P0-P2.

If the reviewer facility itself is unavailable, stop before integration. Do not substitute
foreground self-review.

## Revalidate against latest main

Find the unique clean main worktree and fetch `origin/main` when configured:

- fast-forward main when behind;
- allow main when equal or ahead;
- set `integration-blocked` when local and origin diverge.

If main is not an ancestor of feature HEAD, rebase the feature onto main. Resolve conflicts within
the plan and re-plan when product intent would change.

Whenever main changed after authoritative eval:

1. rerun the full eval contract;
2. compare the effective merge diff;
3. create a fresh reviewer when that diff changed;
4. retain prior review only for an unchanged diff.

Set `integration-ready`, `validated_feature_head`, and `validated_main_sha` only for the clean,
fully evaluated and accepted HEAD.

## Select post-merge smoke

Use the latest successful eval durations and the plan threshold, default 300 seconds:

- `always`: include regardless of duration;
- `never`: exclude;
- `auto`: include only within the threshold.

Require at least one command. Smoke must be local, repeatable, and free of deployment or
irreversible external side effects.

## Integrate

Resolve the bundled helper relative to this SKILL.md and invoke its absolute path:

```text
scripts/integrate-feature.sh \
  --main-worktree <main-path> \
  --feature-worktree <feature-path> \
  --expected-main <validated-main-sha> \
  --expected-feature <validated-feature-head> \
  --main-branch main \
  --smoke '<command>' [--smoke '<command>' ...]
```

For interrupted integration, use the same identifying arguments with
`--recover-pending smoke` plus smoke commands, or `--recover-pending rollback`.

Interpret outcomes:

- `integrated`: update state and finish;
- `stale-main` or `not-fast-forward`: return to main revalidation;
- `smoke-rolled-back`: set `needs-replan`, preserve the feature, and brainstorm before modifying;
- `recovery-required`: stop further integration until main is repaired.

Do not push, delete the feature branch, or remove its worktree automatically. Write all shared
state updates atomically.
