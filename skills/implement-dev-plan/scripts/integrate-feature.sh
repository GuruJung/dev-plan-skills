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

local_plan=$metadata_dir/plans/$feature_id/plan.md
if [[ -L "$local_plan" || -e "$local_plan" && ! -f "$local_plan" ]]; then
  die_usage "local plan must be a plain file"
fi
if [[ ! -f "$local_plan" && "$recover_pending" != smoke ]]; then
  die_usage "local plan must be a plain file"
fi

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
mkdir -p "$workflow_dir"
lock_file=$workflow_dir/integration.lock
pending_file=$workflow_dir/integration.pending

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

if [[ -f "$pending_file" ]]; then
  if [[ -z "$recover_pending" ]]; then
    printf 'status=recovery-required reason=pending-integration marker=%q\n' "$pending_file" >&2
    exit 31
  fi

  mapfile -t pending_values < "$pending_file"
  if ((${#pending_values[@]} != 4)); then
    printf 'status=recovery-required reason=invalid-pending-marker marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi
  pre_merge_sha=${pending_values[0]}
  merged_sha=${pending_values[1]}
  pending_main_root=${pending_values[2]}
  pending_feature_root=${pending_values[3]}

  if [[ "$pre_merge_sha" != "$expected_main" ]] ||
     [[ "$merged_sha" != "$expected_feature" ]] ||
     [[ "$pending_main_root" != "$main_root" ]] ||
     [[ "$pending_feature_root" != "$feature_root" ]] ||
     [[ "$actual_main" != "$merged_sha" ]]; then
    printf 'status=recovery-required reason=pending-marker-mismatch marker=%q\n' \
      "$pending_file" >&2
    exit 31
  fi

  if [[ "$recover_pending" == rollback ]]; then
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
    printf 'status=smoke-rolled-back pre=%s feature=%s failed_smoke=recovery-requested\n' \
      "$pre_merge_sha" "$merged_sha"
    exit 30
  fi

  if [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
    printf 'status=recovery-required reason=dirty-main-before-smoke-recovery\n' >&2
    exit 31
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
  pending_tmp=$pending_file.$$
  printf '%s\n%s\n%s\n%s\n' \
    "$pre_merge_sha" "$actual_feature" "$main_root" "$feature_root" >"$pending_tmp"
  mv "$pending_tmp" "$pending_file"

  if ! git -C "$main_root" merge --ff-only "$actual_feature" >/dev/null; then
    current_after_merge=$(git -C "$main_root" rev-parse HEAD)
    if [[ "$current_after_merge" == "$pre_merge_sha" ]]; then
      rm -f "$pending_file"
    fi
    printf 'status=recovery-required reason=merge-failed pre=%s feature=%s actual=%s\n' \
      "$pre_merge_sha" "$actual_feature" "$current_after_merge" >&2
    exit 31
  fi
  merged_sha=$(git -C "$main_root" rev-parse HEAD)
fi

failed_index=
for index in "${!smoke_commands[@]}"; do
  if ! (cd "$main_root" && bash -c "${smoke_commands[$index]}"); then
    failed_index=$index
    break
  fi
done

if [[ -z "$failed_index" ]] && [[ -n "$(git -C "$main_root" status --porcelain)" ]]; then
  failed_index=dirty-main-after-smoke
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
  printf 'status=smoke-rolled-back pre=%s feature=%s failed_smoke=%s\n' \
    "$pre_merge_sha" "$merged_sha" "$failed_index"
  exit 30
fi

if [[ -f "$local_plan" ]] && ! rm -- "$local_plan"; then
  printf 'status=recovery-required reason=local-plan-cleanup-failed plan=%q\n' \
    "$local_plan" >&2
  exit 31
fi
rm -f "$pending_file"
printf 'status=integrated pre=%s head=%s smoke_count=%s\n' \
  "$pre_merge_sha" "$merged_sha" "${#smoke_commands[@]}"
