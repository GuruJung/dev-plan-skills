# Dev Plan Skills

[Korean](README-ko.md)

Dev Plan Skills is a set of Codex skills for turning an agreed development plan into an
implemented, evaluated, independently reviewed, and integrated change. It keeps durable
feature intent in Git while keeping short-lived implementation details in local Git metadata.

The workflow provides three skills:

- `$create-dev-plan` interviews you and produces a decision-complete plan.
- `$save-dev-plan` saves a finalized plan without implementing it when called directly.
- `$implement-dev-plan` implements, evaluates, reviews, and integrates a saved plan.

## Installation

Clone the repository, install the three skills globally, and verify the installation.

```bash
git clone https://github.com/GuruJung/dev-plan-skills.git
cd dev-plan-skills
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

The installer copies the English skills under `skills/` into separate directories under
`~/.agents/skills/`. If Codex does not recognize the installed skills, start a new session.
Run the installer again after updating or moving this repository.

## Quick start

Switch Codex to Plan mode and describe the change while explicitly invoking the planning skill.
The `$` character is part of the skill name; these examples are Codex prompts, not shell commands.

```text
$create-dev-plan <describe the change>
```

Answer the material questions until the plan is finalized, then select the host's
"Implement this plan" action. The host switches to Default mode, saves the same conversation's
latest finalized plan with `$save-dev-plan`, and then continues with `$implement-dev-plan` using
the resolved feature ID without another confirmation. Implementation does not start when saving
fails or the saved artifacts do not match the plan.

## Skill reference

| Skill | When to invoke it | Result |
|---|---|---|
| `$create-dev-plan` | Explicitly in Plan mode | Inspects the repository, resolves decisions with you, and separates a durable feature spec from a local implementation plan. It does not change the repository while planning. |
| `$save-dev-plan` | Explicitly in Default mode when you only want to save | Saves the latest finalized plan in common Git metadata and reports its feature ID. A direct invocation does not start implementation. |
| `$implement-dev-plan <feature-id>` | Explicitly in Default mode to implement or resume | Uses an isolated feature worktree to promote the spec, implement the plan, run evaluations and independent review, and integrate the verified tree into `main` as one squash commit. |

### Manual save and implementation

If the automatic handoff does not start, or if you want to save before implementing, switch to
Default mode and invoke:

```text
$save-dev-plan
$implement-dev-plan <feature-id>
```

Use the `<feature-id>` reported by the first invocation in the second invocation. Use the same
`$implement-dev-plan <feature-id>` form to resume interrupted work. A successful implementation
does not automatically `push` or delete the feature branch or worktree.

## Workflow artifacts

Finalized plans are saved atomically under
`<git-common-dir>/dev-plan-workflow/plans/<id>/` as `spec.md`, `plan.md`, and `state.json`.
When implementation starts, only the durable feature spec is promoted to
`docs/dev-plans/specs/<id>/spec.md` and committed. The local implementation plan remains in Git
metadata for execution and recovery, then is deleted only after a successful integration smoke.

`docs/dev-plans/current-spec.md` normalizes current intent introduced or changed by the new
workflow. It is not a chronological archive or a merger of old specs. Source code and tests are
the source of truth for behavior, while current spec is authoritative for intent within its
declared coverage. A pure refactor that preserves current intent adds only its feature spec.
When current-spec meaning changes, align the prose language of the entire document with the
predominant prose language of the feature spec. Do not translate it for `No change`.

## Updating, uninstalling, and restoring

### Update

Pull the desired repository revision and run the installer and its check again.

```bash
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

### Uninstall

```bash
scripts/uninstall-global-skills.sh
```

The uninstaller backs up and removes the three managed skills together. It succeeds without
changes when none of them is installed and leaves items with other names untouched.

### Restore a backup

Installation and removal backups are stored as workflow-wide sets under
`~/.agents/skill-backups/dev-plan-workflow/`. Before restoring manually, verify that every managed
destination is absent.

```bash
test ! -e "$HOME/.agents/skills/create-dev-plan"
test ! -e "$HOME/.agents/skills/save-dev-plan"
test ! -e "$HOME/.agents/skills/implement-dev-plan"
```

Select a `<backup-set>`, copy each available skill, and verify it against the backup.

```bash
for skill in create-dev-plan save-dev-plan implement-dev-plan; do
  if test -d "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill"; then
    cp -a "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill" \
      "$HOME/.agents/skills/$skill"
    diff -qr "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill" \
      "$HOME/.agents/skills/$skill"
  fi
done
```

Start a new Codex session if restored skills are not recognized. A later installation backs up
an older restored set again before replacing it with the current repository version.

## Maintainer guide

### Keep README translations synchronized

`README.md` is English and `README-ko.md` is Korean. They have the same meaning, strength,
structure, commands, paths, identifiers, and constraints. Neither language is a fixed editing
source.

After changing the intended source but before translating its counterpart, snapshot both Git
states and filesystem mtimes. A normal source candidate has exactly ` M`, `M `, or `MM` status.
When only one file is a candidate, use it as the source. When both are candidates, use the file
with the newer snapshotted mtime. Do not select a source for a clean pair. Stop and ask for an
explicit choice when mtimes are equal or either file has an `A`, `D`, `R`, `U`, untracked, or
other non-`M` change.

Keep that source selection fixed until synchronization finishes. Stop rather than overwrite an
unexpected later change. Translate the counterpart, compare the complete documents, and run:

```bash
tests/test-readme-sync.sh
```

The test checks structure, language boundaries, links, commands, and key contracts. It does not
replace the required semantic translation review.

### Edit and synchronize skill translations

`skills-ko/<skill>/SKILL.md` and `skills/<skill>/SKILL.md` are Korean and English counterparts
with the same meaning and strength. Neither language is a fixed editing source. Before changing
behavior in an existing tracked pair, snapshot its Git states and filesystem mtimes.

```bash
git status --short -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
stat -c '%y %n' -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
```

A normal source candidate has exactly ` M`, `M `, or `MM` status. If only one side is a candidate,
use it as the source. If both are candidates, use the newer snapshotted mtime. Do not synchronize
a clean pair. Stop for an explicit user choice when mtimes are equal or an `A`, `D`, `R`, `U`,
untracked, or other non-`M` change exists.

Keep the selected source fixed through the synchronization. Stop rather than overwrite unexpected
changes. When the selected source is Korean, translate its counterpart into English; when the
selected source is English, translate its counterpart into Korean with the same meaning and
strength. Preserve commands, paths, identifiers, enum values, and YAML or JSON keys.
Files installed from `skills/` must contain English ASCII text only; do not copy Korean counterparts
or development-only files there. `agents/openai.yaml` files and executable scripts have no Korean
counterparts and are maintained directly in English.

After comparing both documents, record and verify the synchronization state.

```bash
scripts/record-skill-sync.sh
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
```

The recording command does not translate or select a source. It validates language boundaries
and paired changes, then atomically records current checksums. It refuses a one-sided change and
requires the tracked checksum state to match Git `HEAD`. Do not edit or delete
`skills-ko/.sync-state.sha256` directly. If the state is missing, modified, or damaged, restore it
from Git instead of re-baselining the current contents. Semantic equivalence is verified during
implementation review and independent review.

### Installation safety details

If one installed skill differs, the installer stages and verifies all three, backs up the complete
installed set, and replaces it transactionally. A failure restores the state from before the
installation. Installation and removal share one exclusive lock.

Only `create-dev-plan`, `save-dev-plan`, and `implement-dev-plan` are managed. Other names are
ignored. A symbolic link at a managed name causes a safe failure instead of being followed or
replaced. Only the five most recent workflow-wide backup sets are retained.

For isolated validation, set both `DEV_PLAN_WORKFLOW_TARGET_ROOT` and
`DEV_PLAN_WORKFLOW_BACKUP_ROOT`. The removed `FEATURE_WORKFLOW_*`,
`~/.agents/skill-backups/feature-workflow/`, and `.feature-workflow-*` namespaces are unsupported.
If an old environment variable is set, the scripts fail instead of silently falling back to the
default global paths.

### Improve the skills

Do not edit a globally installed copy when a problem is discovered in another project.

1. Preserve the consumer project's work at a safe checkpoint.
2. Prepare a report containing the skill name, this repository's Git commit, invocation, expected
   and actual behavior, minimal reproduction, relevant output and diff, and whether work is blocked.
3. Open a new Codex session in this repository and provide the report.
4. Plan and implement behavior changes with `$create-dev-plan`, `$save-dev-plan`, and
   `$implement-dev-plan`.
5. Validate candidate skills in the feature worktree with the minimal reproduction and an
   independent fresh session. Do not alter global installations for candidate testing.
6. Integrate the verified feature tree into `main` as one squash commit and rerun the failing step
   in the consumer project.

Keep the canonical working directory on a clean `main`. Make skill changes in feature worktrees and
use the Git commit hash as the installed version identifier. Start a new session or resume the
session if it does not recognize an integrated change.
