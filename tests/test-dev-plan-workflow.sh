#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
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

# Promotion creates a plan-only commit, removes the temporary copy, and is idempotent.
make_repo promotion
feature_id=20260827-example
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
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
temporary_dir=$metadata_dir/plans/$feature_id
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
temporary_dir=$metadata_dir/plans/$feature_id
mkdir -p -- "$temporary_dir"
printf 'temporary plan\n' >"$temporary_dir/plan.md"
printf 'unrelated\n' >"$case_root/unrelated.txt"
expect_failure 'promoter accepted an unrelated worktree change' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
[[ -f "$temporary_dir/plan.md" ]] ||
  fail 'failed promotion removed the temporary plan'

printf 'All dev plan workflow tests passed.\n'
