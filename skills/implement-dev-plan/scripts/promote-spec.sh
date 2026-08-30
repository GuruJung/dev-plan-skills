#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: promote-spec.sh \
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

require_only_spec_changes() {
  local line path
  while IFS= read -r line; do
    path=${line:3}
    [[ "$path" == "$relative_spec" ]] ||
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
common_dir=$(git -C "$feature_root" rev-parse --path-format=absolute --git-common-dir)
metadata_root=$(CDPATH= cd -- "$metadata_dir" 2>/dev/null && pwd -P) ||
  fail "cannot resolve metadata directory: $metadata_dir"
[[ "$metadata_root" == "$common_dir/dev-plan-workflow" ]] ||
  fail "metadata directory does not belong to the feature repository: $metadata_dir"
branch=$(git -C "$feature_root" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
  fail 'feature worktree must have a branch checked out'
[[ "$branch" == "feature/$feature_id" ]] ||
  fail "unexpected feature branch: $branch"

relative_spec=docs/dev-plans/specs/$feature_id/spec.md
temporary_dir=$metadata_dir/plans/$feature_id
temporary_spec=$temporary_dir/spec.md
local_plan=$temporary_dir/plan.md
tracked_spec=$feature_root/$relative_spec

[[ -d "$metadata_dir/plans" && ! -L "$metadata_dir/plans" ]] ||
  fail "plans directory is not a plain directory: $metadata_dir/plans"
[[ -d "$temporary_dir" && ! -L "$temporary_dir" ]] ||
  fail "feature metadata directory is not a plain directory: $temporary_dir"

[[ -f "$local_plan" && ! -L "$local_plan" ]] ||
  fail "local plan is not a plain file: $local_plan"

if ! path_exists "$temporary_spec"; then
  [[ -f "$tracked_spec" && ! -L "$tracked_spec" ]] ||
    fail "temporary and tracked specs are both missing for $feature_id"
  git -C "$feature_root" cat-file -e "HEAD:$relative_spec" 2>/dev/null ||
    fail "tracked spec is not committed at HEAD: $relative_spec"
  [[ -z $(git -C "$feature_root" status --porcelain --untracked-files=all) ]] ||
    fail 'feature worktree is not clean after spec promotion'
  printf 'spec_path=%s commit=%s\n' "$relative_spec" "$(git -C "$feature_root" rev-parse HEAD)"
  exit 0
fi

[[ -f "$temporary_spec" && ! -L "$temporary_spec" ]] ||
  fail "temporary spec is not a plain file: $temporary_spec"
require_only_spec_changes

ensure_plain_directory "$feature_root/docs"
ensure_plain_directory "$feature_root/docs/dev-plans"
ensure_plain_directory "$feature_root/docs/dev-plans/specs"
ensure_plain_directory "$feature_root/docs/dev-plans/specs/$feature_id"

if path_exists "$tracked_spec"; then
  [[ -f "$tracked_spec" && ! -L "$tracked_spec" ]] ||
    fail "tracked spec destination is not a plain file: $tracked_spec"
  cmp -s -- "$temporary_spec" "$tracked_spec" ||
    fail "temporary and tracked specs differ: $relative_spec"
else
  staged_spec=$feature_root/docs/dev-plans/specs/$feature_id/.spec.md.tmp-$$
  cp -- "$temporary_spec" "$staged_spec"
  cmp -s -- "$temporary_spec" "$staged_spec" ||
    fail 'copied spec failed verification'
  mv -- "$staged_spec" "$tracked_spec"
fi

require_only_spec_changes
git -C "$feature_root" add -- "$relative_spec"
mapfile -t staged_paths < <(git -C "$feature_root" diff --cached --name-only)
if ((${#staged_paths[@]} > 1)) ||
   ((${#staged_paths[@]} == 1)) && [[ "${staged_paths[0]}" != "$relative_spec" ]]; then
  fail 'index contains changes outside the tracked spec'
fi

if ((${#staged_paths[@]} == 1)); then
  git -C "$feature_root" commit -m "docs(spec): add $feature_id" -- "$relative_spec"
else
  git -C "$feature_root" cat-file -e "HEAD:$relative_spec" 2>/dev/null ||
    fail "tracked spec is neither staged nor committed: $relative_spec"
fi

git -C "$feature_root" show "HEAD:$relative_spec" | cmp -s - "$temporary_spec" ||
  fail 'committed spec differs from temporary spec'
[[ -z $(git -C "$feature_root" status --porcelain --untracked-files=all) ]] ||
  fail 'feature worktree is not clean after spec commit'

rm -- "$temporary_spec"
printf 'spec_path=%s commit=%s\n' "$relative_spec" "$(git -C "$feature_root" rev-parse HEAD)"
