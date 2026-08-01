---
name: plan-run-feature
description: "Produce a decision-complete plan with the existing feature-planning contract, then connect plan persistence and feature execution in an approved same-thread implementation continuation. Use only when the user explicitly invokes '$plan-run-feature' in Plan mode, or implements a finalized plan from that invocation containing `execution_handoff: plan-run-feature` in Default mode."
---

# Plan and Run Feature

Create plans only in Plan mode and save and run them only in Default mode. This skill connects sibling skill contracts in two phases instead of duplicating them.

Use the user's current conversation language for questions, status, and prose artifacts unless the user explicitly requests another language. Preserve commands, identifiers, paths, enum values, and machine-readable schema keys exactly.

## Resolve sibling contracts

Resolve these sibling files relative to the directory containing this `SKILL.md`:

- `../plan-feature/SKILL.md`
- `../save-approved-plan/SKILL.md`
- `../run-feature/SKILL.md`

Read each file needed for the current phase completely and verify that its frontmatter `name` matches the expected name. If a required sibling is missing or invalid, do not search other directories or catalogs or try to install it. Stop without changes.

## Plan phase

Start this phase only when the user explicitly invokes `$plan-run-feature` in Plan mode. Otherwise, tell the user to switch to Plan mode and invoke it explicitly, then stop.

Read `../plan-feature/SKILL.md` completely and apply its full contract as a delegated invocation. Do not write files, create branches or worktrees, implement, or run mutating commands.

Add this marker to the finalized plan alongside its existing frontmatter fields:

```yaml
execution_handoff: plan-run-feature
```

In the final blockquote, tell the user that choosing "Implement this plan" will automatically save and run the plan in Default mode. Also provide an explicit `$plan-run-feature` invocation in Default mode as the fallback when automatic continuation does not start. Do not save or run anything in Plan mode.

## Default continuation phase

Allow automatic continuation only when all of these are true:

- Plan mode is not active.
- In the same conversation, the user started this plan with `$plan-run-feature`.
- The latest finalized plan contains `execution_handoff: plan-run-feature`.
- The user approved implementation with a request such as "Implement this plan" or explicitly invoked `$plan-run-feature` again.

When any condition is missing, do not save or run the plan. When the latest plan has no marker, treat it as an ordinary `$plan-feature` flow and show the existing explicit commands.

Immediately after all conditions pass, and before creating or changing metadata, read both `../save-approved-plan/SKILL.md` and `../run-feature/SKILL.md` completely and validate both `name` values. If either sibling is missing or invalid, stop without changes. Apply these preflighted contracts in the save and run stages below.

## Save or reuse

First look for a feature ID reported as successfully saved for this plan earlier in the same conversation. Otherwise, inspect the plan's proposed ID.

Treat an existing feature as the same plan only when its saved `plan.md` equals the latest approved plan after applying the same canonical ID rewrite as `save-approved-plan`, and the handoff marker remains present. When changing the proposed ID to the ID in saved state, consistently normalize every field and path that denotes the feature ID, including a saved-plan path in a goal objective, but do not rewrite unrelated prose that happens to contain the same text. If the normalization scope cannot be determined unambiguously, do not create a suffix or new metadata; show the mismatch and wait for a user choice. Reuse the ID without creating a suffix or new metadata only when the plans match.

When there is no reusable feature, apply the preflighted `save-approved-plan` contract as a delegated invocation from the approved handoff. If collision handling changes the ID, use the resolved saved ID for every later step. If saving fails or waits for a user choice, do not enter the run phase.

## Run

Only after a feature was newly saved or reused as the same plan, apply the preflighted `run-feature` contract to that ID as a delegated invocation from the approved handoff. Even when reused state says `integrated`, do not report completion directly. Apply `run-feature` re-entry diagnosis and Git-source-of-truth verification, and report completion only when they agree. On a mismatch, stop under the existing recovery-choice rules. Do not ask for an additional confirmation between saving and running.

Preserve every safety stop, recovery choice, state binding, independent-review rule, and integration rule from `save-approved-plan` and `run-feature`. Do not treat this orchestration as authority to bypass conflicts, mismatches, unsafe decisions, or explicit approval requirements.
