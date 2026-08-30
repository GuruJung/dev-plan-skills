#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  integrate-feature.sh \
    --metadata-dir PATH \
    --feature-id ID \
    --main-worktree PATH \
    --feature-worktree PATH \
    --expected-main SHA \
    --expected-feature SHA \
    --feature-title TITLE \
    [--main-branch NAME] \
    [--recover-pending smoke|rollback] \
    [--smoke COMMAND ...]

At least one --smoke is required except with --recover-pending rollback.

Exit codes:
  0   integrated
  20  stale-main
  21  not-fast-forward
  22  invalid-or-dirty-worktree
  30  smoke-rolled-back
  31  recovery-required
  64  usage error
EOF
}

die_usage() {
  printf 'status=usage-error message=%q\n' "$1" >&2
  usage >&2
  exit 64
}

metadata_dir=
feature_id=
main_worktree=
feature_worktree=
expected_main=
expected_feature=
feature_title=
main_branch=main
recover_pending=
declare -a smoke_commands=()

while (($#)); do
  case "$1" in
    --metadata-dir)
      (($# >= 2)) || die_usage "missing value for --metadata-dir"
      metadata_dir=$2
      shift 2
      ;;
    --feature-id)
      (($# >= 2)) || die_usage "missing value for --feature-id"
      feature_id=$2
      shift 2
      ;;
    --main-worktree)
      (($# >= 2)) || die_usage "missing value for --main-worktree"
      main_worktree=$2
      shift 2
      ;;
    --feature-worktree)
      (($# >= 2)) || die_usage "missing value for --feature-worktree"
      feature_worktree=$2
      shift 2
      ;;
    --expected-main)
      (($# >= 2)) || die_usage "missing value for --expected-main"
      expected_main=$2
      shift 2
      ;;
    --expected-feature)
      (($# >= 2)) || die_usage "missing value for --expected-feature"
      expected_feature=$2
      shift 2
      ;;
    --feature-title)
      (($# >= 2)) || die_usage "missing value for --feature-title"
      feature_title=$2
      shift 2
      ;;
    --main-branch)
      (($# >= 2)) || die_usage "missing value for --main-branch"
      main_branch=$2
      shift 2
      ;;
    --recover-pending)
      (($# >= 2)) || die_usage "missing value for --recover-pending"
      recover_pending=$2
      shift 2
      ;;
    --smoke)
      (($# >= 2)) || die_usage "missing value for --smoke"
      smoke_commands+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown argument: $1"
      ;;
  esac
done

[[ -n "$metadata_dir" ]] || die_usage "--metadata-dir is required"
[[ "$feature_id" =~ ^[0-9]{8}-[a-z0-9][a-z0-9-]*$ ]] ||
  die_usage "--feature-id is invalid"
[[ -d "$metadata_dir" && ! -L "$metadata_dir" ]] ||
  die_usage "--metadata-dir must be a plain directory"
[[ -n "$main_worktree" ]] || die_usage "--main-worktree is required"
[[ -n "$feature_worktree" ]] || die_usage "--feature-worktree is required"
[[ -n "$expected_main" ]] || die_usage "--expected-main is required"
[[ -n "$expected_feature" ]] || die_usage "--expected-feature is required"
[[ -n "$feature_title" ]] || die_usage "--feature-title is required"
if [[ "$feature_title" == *$'\n'* || "$feature_title" == *$'\r'* ]]; then
  die_usage "--feature-title must be a non-empty single line"
fi
commit_subject="$feature_title ($feature_id)"
if [[ -n "$recover_pending" ]] &&
   [[ "$recover_pending" != smoke ]] &&
   [[ "$recover_pending" != rollback ]]; then
  die_usage "--recover-pending must be smoke or rollback"
fi
if [[ "$recover_pending" != rollback ]] && ((${#smoke_commands[@]} == 0)); then
  die_usage "at least one --smoke command is required"
fi

command -v git >/dev/null || die_usage "git is required"
command -v flock >/dev/null || die_usage "flock is required"

resolve_root() {
  git -C "$1" rev-parse --path-format=absolute --show-toplevel 2>/dev/null
}

main_root=$(resolve_root "$main_worktree") || {
  printf 'status=invalid-or-dirty-worktree reason=invalid-main-worktree\n' >&2
  exit 22
}
feature_root=$(resolve_root "$feature_worktree") || {
  printf 'status=invalid-or-dirty-worktree reason=invalid-feature-worktree\n' >&2
  exit 22
}

[[ "$main_root" != "$feature_root" ]] || {
  printf 'status=invalid-or-dirty-worktree reason=same-worktree\n' >&2
  exit 22
}

current_main_branch=$(git -C "$main_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
[[ "$current_main_branch" == "$main_branch" ]] || {
  printf 'status=invalid-or-dirty-worktree reason=wrong-main-branch actual=%q expected=%q\n' \
    "$current_main_branch" "$main_branch" >&2
  exit 22
}

common_dir=$(git -C "$main_root" rev-parse --path-format=absolute --git-common-dir)
workflow_dir=$common_dir/dev-plan-workflow
metadata_root=$(CDPATH= cd -- "$metadata_dir" 2>/dev/null && pwd -P) || {
  printf 'status=invalid-or-dirty-worktree reason=invalid-metadata-dir\n' >&2
  exit 22
}
[[ "$metadata_root" == "$workflow_dir" ]] || {
  printf 'status=invalid-or-dirty-worktree reason=metadata-dir-mismatch expected=%q actual=%q\n' \
    "$workflow_dir" "$metadata_root" >&2
  exit 22
}
local_plan=$workflow_dir/plans/$feature_id/plan.md
plans_dir=$workflow_dir/plans
feature_metadata_dir=$plans_dir/$feature_id
completion_file=$feature_metadata_dir/integration.complete
pending_file=$workflow_dir/integration.pending
lock_file=$workflow_dir/integration.lock
[[ -d "$plans_dir" && ! -L "$plans_dir" ]] || {
  printf 'status=invalid-or-dirty-worktree reason=invalid-plans-dir\n' >&2
  exit 22
}
[[ -d "$feature_metadata_dir" && ! -L "$feature_metadata_dir" ]] || {
  printf 'status=invalid-or-dirty-worktree reason=invalid-feature-metadata-dir\n' >&2
  exit 22
}
if [[ -L "$completion_file" || -e "$completion_file" && ! -f "$completion_file" ]]; then
  printf 'status=invalid-or-dirty-worktree reason=invalid-completion-marker\n' >&2
  exit 22
fi
if [[ -L "$pending_file" || -e "$pending_file" && ! -f "$pending_file" ]]; then
  printf 'status=invalid-or-dirty-worktree reason=invalid-pending-marker\n' >&2
  exit 22
fi
if [[ -L "$lock_file" || -e "$lock_file" && ! -f "$lock_file" ]]; then
  printf 'status=invalid-or-dirty-worktree reason=invalid-lock-file\n' >&2
  exit 22
fi
if [[ -L "$local_plan" || -e "$local_plan" && ! -f "$local_plan" ]]; then
  die_usage "local plan must be a plain file"
fi
if [[ ! -f "$local_plan" && ! -f "$completion_file" ]]; then
  die_usage "local plan must be a plain file"
fi

# Reject the legacy four-field marker format before opening the lock file so this compatibility
# failure leaves both refs and metadata unchanged.
if [[ -f "$pending_file" ]]; then
  mapfile -t marker_probe < "$pending_file"
  if ((${#marker_probe[@]} != 5)); then
    printf 'status=recovery-required reason=invalid-pending-marker marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi
fi
if [[ -f "$completion_file" ]]; then
  mapfile -t marker_probe < "$completion_file"
  if ((${#marker_probe[@]} != 5)); then
    printf 'status=recovery-required reason=completion-marker-mismatch marker=%q\n' \
      "$completion_file" >&2
    exit 31
  fi
fi

if [[ ! -f "$pending_file" ]]; then
  if [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
    printf 'status=invalid-or-dirty-worktree reason=dirty-main\n' >&2
    exit 22
  fi
  if [[ -n "$(git -C "$feature_root" status --porcelain)" ]]; then
    printf 'status=invalid-or-dirty-worktree reason=dirty-feature\n' >&2
    exit 22
  fi
fi

exec 9>"$lock_file"
flock -x 9

current_main_branch=$(git -C "$main_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [[ "$current_main_branch" != "$main_branch" ]] ||
   { [[ ! -f "$pending_file" ]] &&
     { [[ -n "$(git -C "$main_root" status --porcelain)" ]] ||
       [[ -n "$(git -C "$feature_root" status --porcelain)" ]]; }; }; then
  printf 'status=invalid-or-dirty-worktree reason=changed-while-waiting\n' >&2
  exit 22
fi

actual_main=$(git -C "$main_root" rev-parse HEAD)
actual_feature=$(git -C "$feature_root" rev-parse HEAD)

validate_squash_commit() {
  local squash_sha=$1 pre_merge_sha=$2 feature_sha=$3
  local parent_line feature_tree squash_tree actual_subject

  git -C "$main_root" cat-file -e "$squash_sha^{commit}" 2>/dev/null || return 1
  git -C "$main_root" cat-file -e "$pre_merge_sha^{commit}" 2>/dev/null || return 1
  git -C "$main_root" cat-file -e "$feature_sha^{commit}" 2>/dev/null || return 1
  parent_line=$(git -C "$main_root" rev-list --parents -n 1 "$squash_sha") || return 1
  [[ "$parent_line" == "$squash_sha $pre_merge_sha" ]] || return 1
  feature_tree=$(git -C "$main_root" rev-parse "$feature_sha^{tree}") || return 1
  squash_tree=$(git -C "$main_root" rev-parse "$squash_sha^{tree}") || return 1
  [[ "$squash_tree" == "$feature_tree" ]] || return 1
  actual_subject=$(git -C "$main_root" log -1 --format=%s "$squash_sha") || return 1
  [[ "$actual_subject" == "$commit_subject" ]]
}

if [[ -f "$completion_file" && ! -f "$pending_file" ]]; then
  mapfile -t completion_values < "$completion_file"
  if ((${#completion_values[@]} != 5)) ||
     [[ "${completion_values[0]}" != "$expected_main" ]] ||
     [[ "${completion_values[1]}" != "$expected_feature" ]] ||
     [[ "${completion_values[3]}" != "$main_root" ]] ||
     [[ "${completion_values[4]}" != "$feature_root" ]]; then
    printf 'status=recovery-required reason=completion-marker-mismatch marker=%q\n' \
      "$completion_file" >&2
    exit 31
  fi
  merged_sha=${completion_values[2]}
  if [[ "$actual_main" != "$merged_sha" ]] ||
     [[ "$actual_feature" != "$expected_feature" ]] ||
     ! validate_squash_commit "$merged_sha" "$expected_main" "$expected_feature"; then
    printf 'status=recovery-required reason=completion-marker-mismatch marker=%q\n' \
      "$completion_file" >&2
    exit 31
  fi
  printf 'status=integrated pre=%s feature=%s head=%s smoke_count=%s recovered=true marker=%q\n' \
    "$expected_main" "$expected_feature" "$merged_sha" "${#smoke_commands[@]}" \
    "$completion_file"
  exit 0
fi

smoke_already_complete=false
if [[ -f "$pending_file" ]]; then
  if [[ -z "$recover_pending" ]]; then
    printf 'status=recovery-required reason=pending-integration marker=%q\n' "$pending_file" >&2
    exit 31
  fi

  mapfile -t pending_values < "$pending_file"
  if ((${#pending_values[@]} != 5)); then
    printf 'status=recovery-required reason=invalid-pending-marker marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi
  pre_merge_sha=${pending_values[0]}
  pending_feature_sha=${pending_values[1]}
  merged_sha=${pending_values[2]}
  pending_main_root=${pending_values[3]}
  pending_feature_root=${pending_values[4]}

  if [[ "$pre_merge_sha" != "$expected_main" ]] ||
     [[ "$pending_feature_sha" != "$expected_feature" ]] ||
     [[ "$pending_main_root" != "$main_root" ]] ||
     [[ "$pending_feature_root" != "$feature_root" ]]; then
    printf 'status=recovery-required reason=pending-marker-mismatch marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi

  if [[ "$recover_pending" == rollback ]]; then
    [[ ! -f "$completion_file" ]] ||
      die_usage "completed smoke must be recovered with --recover-pending smoke"
    if [[ "$actual_main" != "$pre_merge_sha" && "$actual_main" != "$merged_sha" ]]; then
      printf 'status=recovery-required reason=pending-marker-mismatch marker=%q\n' \
        "$pending_file" >&2
      exit 31
    fi
    if [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
      printf 'status=recovery-required reason=dirty-main-before-rollback\n' >&2
      exit 31
    fi
    if [[ "$actual_main" == "$merged_sha" ]]; then
      parent_line=$(git -C "$main_root" rev-list --parents -n 1 "$merged_sha") || {
        printf 'status=recovery-required reason=invalid-squash-parent head=%s\n' \
          "$merged_sha" >&2
        exit 31
      }
      if [[ "$parent_line" != "$merged_sha $pre_merge_sha" ]]; then
        printf 'status=recovery-required reason=invalid-squash-parent head=%s\n' \
          "$merged_sha" >&2
        exit 31
      fi
      if ! git -C "$main_root" reset --hard "$pre_merge_sha" >/dev/null; then
        printf 'status=recovery-required reason=reset-failed pre=%s merged=%s\n' \
          "$pre_merge_sha" "$merged_sha" >&2
        exit 31
      fi
    fi
    if [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
      printf 'status=recovery-required reason=dirty-after-reset pre=%s merged=%s\n' \
        "$pre_merge_sha" "$merged_sha" >&2
      exit 31
    fi
    rm -f "$pending_file"
    printf 'status=smoke-rolled-back pre=%s feature=%s head=%s failed_smoke=recovery-requested\n' \
      "$pre_merge_sha" "$expected_feature" "$merged_sha"
    exit 30
  fi

  if [[ "$actual_feature" != "$expected_feature" ]] ||
     { [[ "$actual_main" != "$pre_merge_sha" ]] && [[ "$actual_main" != "$merged_sha" ]]; } ||
     ! validate_squash_commit "$merged_sha" "$pre_merge_sha" "$pending_feature_sha"; then
    printf 'status=recovery-required reason=pending-marker-mismatch marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi

  if [[ -n "$(git -C "$main_root" status --porcelain)" ]] ||
     [[ -n "$(git -C "$feature_root" status --porcelain)" ]]; then
    printf 'status=recovery-required reason=dirty-worktree-during-recovery\n' >&2
    exit 31
  fi

  if [[ -f "$completion_file" ]]; then
    mapfile -t completion_values < "$completion_file"
    if ((${#completion_values[@]} != 5)) ||
       [[ "${completion_values[0]}" != "${pending_values[0]}" ]] ||
       [[ "${completion_values[1]}" != "${pending_values[1]}" ]] ||
       [[ "${completion_values[2]}" != "${pending_values[2]}" ]] ||
       [[ "${completion_values[3]}" != "${pending_values[3]}" ]] ||
       [[ "${completion_values[4]}" != "${pending_values[4]}" ]] ||
       [[ "$actual_main" != "$merged_sha" ]]; then
      printf 'status=recovery-required reason=completion-marker-mismatch marker=%q\n' \
        "$completion_file" >&2
      exit 31
    fi
    smoke_already_complete=true
  fi

  if [[ "$actual_main" == "$pre_merge_sha" ]]; then
    if ! git -C "$main_root" merge --ff-only "$merged_sha" >/dev/null; then
      printf 'status=recovery-required reason=merge-failed pre=%s feature=%s head=%s\n' \
        "$pre_merge_sha" "$expected_feature" "$merged_sha" >&2
      exit 31
    fi
  fi
else
  [[ -z "$recover_pending" ]] || die_usage "no pending integration exists"

  if [[ "$actual_feature" != "$expected_feature" ]]; then
    printf 'status=invalid-or-dirty-worktree reason=stale-feature expected=%s actual=%s\n' \
      "$expected_feature" "$actual_feature" >&2
    exit 22
  fi
  if [[ "$actual_main" != "$expected_main" ]]; then
    printf 'status=stale-main expected=%s actual=%s\n' "$expected_main" "$actual_main"
    exit 20
  fi
  if ! git -C "$main_root" merge-base --is-ancestor "$actual_main" "$actual_feature"; then
    printf 'status=not-fast-forward main=%s feature=%s\n' "$actual_main" "$actual_feature"
    exit 21
  fi

  pre_merge_sha=$actual_main
  feature_tree=$(git -C "$main_root" rev-parse "$actual_feature^{tree}")
  commit_signing=false
  if configured_signing=$(git -C "$main_root" config --bool --get commit.gpgSign); then
    commit_signing=$configured_signing
  else
    signing_status=$?
    if [[ $signing_status != 1 ]]; then
      printf 'status=recovery-required reason=invalid-commit-signing-config\n' >&2
      exit 31
    fi
  fi
  commit_tree_args=("$feature_tree" -p "$pre_merge_sha" -m "$commit_subject")
  if [[ "$commit_signing" == true ]]; then
    commit_tree_args+=(-S)
  fi
  if ! merged_sha=$(git -C "$main_root" commit-tree "${commit_tree_args[@]}"); then
    printf 'status=recovery-required reason=squash-commit-failed pre=%s feature=%s\n' \
      "$pre_merge_sha" "$actual_feature" >&2
    exit 31
  fi
  if ! validate_squash_commit "$merged_sha" "$pre_merge_sha" "$actual_feature"; then
    printf 'status=recovery-required reason=invalid-squash-commit pre=%s feature=%s head=%s\n' \
      "$pre_merge_sha" "$actual_feature" "$merged_sha" >&2
    exit 31
  fi
  pending_tmp=$pending_file.$$
  printf '%s\n%s\n%s\n%s\n%s\n' \
    "$pre_merge_sha" "$actual_feature" "$merged_sha" "$main_root" "$feature_root" \
    >"$pending_tmp"
  mv -- "$pending_tmp" "$pending_file"

  if ! git -C "$main_root" merge --ff-only "$merged_sha" >/dev/null; then
    current_after_merge=$(git -C "$main_root" rev-parse HEAD)
    if [[ "$current_after_merge" == "$pre_merge_sha" ]]; then
      rm -f "$pending_file"
    fi
    printf 'status=recovery-required reason=merge-failed pre=%s feature=%s head=%s actual=%s\n' \
      "$pre_merge_sha" "$actual_feature" "$merged_sha" "$current_after_merge" >&2
    exit 31
  fi
fi

failed_index=
if [[ "$smoke_already_complete" == false ]]; then
  for index in "${!smoke_commands[@]}"; do
    if ! (cd "$main_root" && bash -c "${smoke_commands[$index]}"); then
      failed_index=$index
      break
    fi
  done
fi

if [[ -z "$failed_index" ]] && [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
  failed_index=dirty-main-after-smoke
fi
if [[ -z "$failed_index" ]] &&
   { [[ "$(git -C "$feature_root" rev-parse HEAD)" != "$expected_feature" ]] ||
     [[ -n "$(git -C "$feature_root" status --porcelain)" ]]; }; then
  failed_index=changed-feature-after-smoke
fi

if [[ -n "$failed_index" ]]; then
  current_after_smoke=$(git -C "$main_root" rev-parse HEAD)
  if [[ "$current_after_smoke" != "$merged_sha" ]]; then
    printf 'status=recovery-required reason=main-moved-during-smoke pre=%s merged=%s actual=%s\n' \
      "$pre_merge_sha" "$merged_sha" "$current_after_smoke" >&2
    exit 31
  fi

  if ! git -C "$main_root" reset --hard "$pre_merge_sha" >/dev/null; then
    printf 'status=recovery-required reason=reset-failed pre=%s merged=%s\n' \
      "$pre_merge_sha" "$merged_sha" >&2
    exit 31
  fi
  if [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
    printf 'status=recovery-required reason=dirty-after-reset pre=%s merged=%s\n' \
      "$pre_merge_sha" "$merged_sha" >&2
    exit 31
  fi

  rm -f "$pending_file"
  printf 'status=smoke-rolled-back pre=%s feature=%s head=%s failed_smoke=%s\n' \
    "$pre_merge_sha" "$expected_feature" "$merged_sha" "$failed_index"
  exit 30
fi

if [[ "$smoke_already_complete" == false ]]; then
  completion_tmp=$completion_file.tmp-$$
  printf '%s\n%s\n%s\n%s\n%s\n' \
    "$pre_merge_sha" "$expected_feature" "$merged_sha" "$main_root" "$feature_root" \
    >"$completion_tmp"
  mv -- "$completion_tmp" "$completion_file"
fi

if [[ -f "$local_plan" ]] && ! rm -- "$local_plan"; then
  printf 'status=recovery-required reason=local-plan-cleanup-failed plan=%q\n' \
    "$local_plan" >&2
  exit 31
fi
rm -f "$pending_file"
printf 'status=integrated pre=%s feature=%s head=%s smoke_count=%s marker=%q\n' \
  "$pre_merge_sha" "$expected_feature" "$merged_sha" "${#smoke_commands[@]}" \
  "$completion_file"
