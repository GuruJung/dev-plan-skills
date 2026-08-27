#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_directory() {
  [[ -d "$1" && ! -L "$1" ]] || fail "expected plain directory: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected absent path: $1"
}

expect_failure() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description"
  fi
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
save_migrator=$repo_root/skills/save-dev-plan/scripts/migrate-workflow-metadata.sh
implement_migrator=$repo_root/skills/implement-dev-plan/scripts/migrate-workflow-metadata.sh
promoter=$repo_root/skills/implement-dev-plan/scripts/promote-plan.sh
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dev plan workflow tests.XXXXXX")

cleanup() {
  case $test_root in
    "${TMPDIR:-/tmp}"/'dev plan workflow tests.'*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing unsafe test cleanup: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

make_repo() {
  case_root=$test_root/$1
  mkdir -p -- "$case_root"
  git -C "$case_root" init -qb main
  git -C "$case_root" config user.name 'Dev Plan Workflow Test'
  git -C "$case_root" config user.email 'dev-plan-workflow@example.invalid'
  printf 'fixture\n' >"$case_root/README.md"
  git -C "$case_root" add README.md
  git -C "$case_root" commit -qm 'Create fixture repository'
}

cmp -s -- "$save_migrator" "$implement_migrator" ||
  fail 'installed metadata migration helpers differ'

# A repository without metadata gets the canonical directory and remains idempotent.
make_repo empty
workflow_path=$($save_migrator --repo "$case_root")
[[ "$workflow_path" == "$case_root/.git/dev-plan-workflow" ]] ||
  fail "unexpected canonical workflow path: $workflow_path"
assert_directory "$workflow_path"
[[ $($implement_migrator --repo "$case_root") == "$workflow_path" ]] ||
  fail 'canonical metadata lookup is not idempotent'

# Legacy metadata is moved as one directory, preserving feature state and its lock.
make_repo legacy
mkdir -p -- "$case_root/.git/feature-workflow/features/20260827-example"
printf 'legacy state\n' >"$case_root/.git/feature-workflow/features/20260827-example/state.json"
printf 'lock sentinel\n' >"$case_root/.git/feature-workflow/integration.lock"
$save_migrator --repo "$case_root" >/dev/null
assert_absent "$case_root/.git/feature-workflow"
assert_directory "$case_root/.git/dev-plan-workflow/features/20260827-example"
grep -Fq 'legacy state' \
  "$case_root/.git/dev-plan-workflow/features/20260827-example/state.json" ||
  fail 'legacy feature state was not preserved'
grep -Fq 'lock sentinel' "$case_root/.git/dev-plan-workflow/integration.lock" ||
  fail 'legacy integration lock was not preserved'

# Ambiguous, unsafe, and pending legacy states are refused unchanged.
make_repo conflict
mkdir -- "$case_root/.git/feature-workflow" "$case_root/.git/dev-plan-workflow"
expect_failure 'migrator accepted both legacy and canonical directories' \
  "$save_migrator" --repo "$case_root"
assert_directory "$case_root/.git/feature-workflow"
assert_directory "$case_root/.git/dev-plan-workflow"

make_repo pending
mkdir -- "$case_root/.git/feature-workflow"
printf 'pending\n' >"$case_root/.git/feature-workflow/integration.pending"
expect_failure 'migrator accepted a pending legacy integration' \
  "$save_migrator" --repo "$case_root"
assert_directory "$case_root/.git/feature-workflow"
assert_absent "$case_root/.git/dev-plan-workflow"

make_repo symlink
mkdir -- "$case_root/metadata-target"
ln -s -- "$case_root/metadata-target" "$case_root/.git/feature-workflow"
expect_failure 'migrator accepted a symbolic-link legacy directory' \
  "$save_migrator" --repo "$case_root"
[[ -L "$case_root/.git/feature-workflow" ]] ||
  fail 'migrator changed a symbolic-link legacy directory'

# Promotion creates a plan-only commit, removes the temporary copy, and is idempotent.
make_repo promotion
feature_id=20260827-example
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/features/$feature_id
mkdir -p -- "$temporary_dir"
printf '# Example plan\n\n## User Decisions\n\n- Keep it small.\n' >"$temporary_dir/plan.md"
$promoter \
  --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" \
  --feature-id "$feature_id" >/dev/null
relative_plan=docs/superpowers/plans/$feature_id/plan.md
assert_absent "$temporary_dir/plan.md"
grep -Fq '# Example plan' "$case_root/$relative_plan" ||
  fail 'tracked plan content is missing'
[[ $(git -C "$case_root" log -1 --format=%s) == "docs(plan): add $feature_id" ]] ||
  fail 'promotion used the wrong commit message'
mapfile -t committed_paths < <(git -C "$case_root" diff-tree --no-commit-id --name-only -r HEAD)
[[ ${#committed_paths[@]} == 1 && ${committed_paths[0]} == "$relative_plan" ]] ||
  fail 'promotion commit contains paths other than the plan'
[[ -z $(git -C "$case_root" status --porcelain --untracked-files=all) ]] ||
  fail 'promotion did not leave a clean worktree'
$promoter \
  --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" \
  --feature-id "$feature_id" >/dev/null

# A conflicting destination or unrelated worktree change preserves the temporary plan.
make_repo destination-conflict
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/features/$feature_id
mkdir -p -- "$temporary_dir" "$case_root/docs/superpowers/plans/$feature_id"
printf 'temporary plan\n' >"$temporary_dir/plan.md"
printf 'different plan\n' >"$case_root/docs/superpowers/plans/$feature_id/plan.md"
expect_failure 'promoter overwrote a conflicting destination' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
grep -Fq 'temporary plan' "$temporary_dir/plan.md" ||
  fail 'conflicting promotion removed the temporary plan'
grep -Fq 'different plan' "$case_root/docs/superpowers/plans/$feature_id/plan.md" ||
  fail 'conflicting promotion changed the destination plan'

make_repo unrelated-change
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/features/$feature_id
mkdir -p -- "$temporary_dir"
printf 'temporary plan\n' >"$temporary_dir/plan.md"
printf 'unrelated\n' >"$case_root/unrelated.txt"
expect_failure 'promoter accepted an unrelated worktree change' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
[[ -f "$temporary_dir/plan.md" ]] ||
  fail 'failed promotion removed the temporary plan'

printf 'All dev plan workflow tests passed.\n'
