#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: promote-plan.sh \
  --metadata-dir PATH \
  --feature-worktree PATH \
  --feature-id ID
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

ensure_plain_directory() {
  local path=$1
  if [[ -L "$path" || -e "$path" && ! -d "$path" ]]; then
    fail "refusing non-directory or symbolic-link path: $path"
  fi
  [[ -d "$path" ]] || mkdir -- "$path"
}

require_only_plan_changes() {
  local line path
  while IFS= read -r line; do
    path=${line:3}
    [[ "$path" == "$relative_plan" ]] ||
      fail "feature worktree contains an unrelated change: $path"
  done < <(git -C "$feature_root" status --porcelain --untracked-files=all)
}

metadata_dir=
feature_worktree=
feature_id=
while (($#)); do
  case $1 in
    --metadata-dir)
      (($# >= 2)) || fail 'missing value for --metadata-dir'
      metadata_dir=$2
      shift 2
      ;;
    --feature-worktree)
      (($# >= 2)) || fail 'missing value for --feature-worktree'
      feature_worktree=$2
      shift 2
      ;;
    --feature-id)
      (($# >= 2)) || fail 'missing value for --feature-id'
      feature_id=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$metadata_dir" ]] || fail '--metadata-dir is required'
[[ -n "$feature_worktree" ]] || fail '--feature-worktree is required'
[[ "$feature_id" =~ ^[0-9]{8}-[a-z0-9][a-z0-9-]*$ ]] ||
  fail "invalid feature ID: $feature_id"
[[ -d "$metadata_dir" && ! -L "$metadata_dir" ]] ||
  fail "metadata directory is not a plain directory: $metadata_dir"
command -v git >/dev/null || fail 'git is required'

feature_root=$(git -C "$feature_worktree" rev-parse --path-format=absolute --show-toplevel 2>/dev/null) ||
  fail "not a Git worktree: $feature_worktree"
branch=$(git -C "$feature_root" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
  fail 'feature worktree must have a branch checked out'
[[ "$branch" == "feature/$feature_id" ]] ||
  fail "unexpected feature branch: $branch"

relative_plan=docs/superpowers/plans/$feature_id/plan.md
temporary_plan=$metadata_dir/features/$feature_id/plan.md
tracked_plan=$feature_root/$relative_plan

if ! path_exists "$temporary_plan"; then
  [[ -f "$tracked_plan" && ! -L "$tracked_plan" ]] ||
    fail "temporary and tracked plans are both missing for $feature_id"
  git -C "$feature_root" cat-file -e "HEAD:$relative_plan" 2>/dev/null ||
    fail "tracked plan is not committed at HEAD: $relative_plan"
  [[ -z $(git -C "$feature_root" status --porcelain --untracked-files=all) ]] ||
    fail 'feature worktree is not clean after plan promotion'
  printf 'plan_path=%s commit=%s\n' "$relative_plan" "$(git -C "$feature_root" rev-parse HEAD)"
  exit 0
fi

[[ -f "$temporary_plan" && ! -L "$temporary_plan" ]] ||
  fail "temporary plan is not a plain file: $temporary_plan"
require_only_plan_changes

ensure_plain_directory "$feature_root/docs"
ensure_plain_directory "$feature_root/docs/superpowers"
ensure_plain_directory "$feature_root/docs/superpowers/plans"
ensure_plain_directory "$feature_root/docs/superpowers/plans/$feature_id"

if path_exists "$tracked_plan"; then
  [[ -f "$tracked_plan" && ! -L "$tracked_plan" ]] ||
    fail "tracked plan destination is not a plain file: $tracked_plan"
  cmp -s -- "$temporary_plan" "$tracked_plan" ||
    fail "temporary and tracked plans differ: $relative_plan"
else
  staged_plan=$feature_root/docs/superpowers/plans/$feature_id/.plan.md.tmp-$$
  cp -- "$temporary_plan" "$staged_plan"
  cmp -s -- "$temporary_plan" "$staged_plan" ||
    fail 'copied plan failed verification'
  mv -- "$staged_plan" "$tracked_plan"
fi

require_only_plan_changes
git -C "$feature_root" add -- "$relative_plan"
mapfile -t staged_paths < <(git -C "$feature_root" diff --cached --name-only)
if ((${#staged_paths[@]} > 1)) ||
   ((${#staged_paths[@]} == 1)) && [[ "${staged_paths[0]}" != "$relative_plan" ]]; then
  fail 'index contains changes outside the tracked plan'
fi

if ((${#staged_paths[@]} == 1)); then
  git -C "$feature_root" commit -m "docs(plan): add $feature_id" -- "$relative_plan"
else
  git -C "$feature_root" cat-file -e "HEAD:$relative_plan" 2>/dev/null ||
    fail "tracked plan is neither staged nor committed: $relative_plan"
fi

git -C "$feature_root" show "HEAD:$relative_plan" | cmp -s - "$temporary_plan" ||
  fail 'committed plan differs from temporary plan'
[[ -z $(git -C "$feature_root" status --porcelain --untracked-files=all) ]] ||
  fail 'feature worktree is not clean after plan commit'

rm -- "$temporary_plan"
printf 'plan_path=%s commit=%s\n' "$relative_plan" "$(git -C "$feature_root" rev-parse HEAD)"
