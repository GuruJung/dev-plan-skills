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
promoter=$repo_root/skills/implement-dev-plan/scripts/promote-spec.sh
integrator=$repo_root/skills/implement-dev-plan/scripts/integrate-feature.sh
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

# Promotion commits only the feature spec, removes temporary spec, retains local plan, and is idempotent.
make_repo promotion
feature_id=20260830-example
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
mkdir -p -- "$temporary_dir"
printf '# Durable feature spec\n' >"$temporary_dir/spec.md"
printf '# Local implementation plan\n' >"$temporary_dir/plan.md"
$promoter \
  --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" \
  --feature-id "$feature_id" >/dev/null
relative_spec=docs/dev-plans/specs/$feature_id/spec.md
assert_absent "$temporary_dir/spec.md"
grep -Fq '# Local implementation plan' "$temporary_dir/plan.md" ||
  fail 'promotion removed or changed the local plan'
grep -Fq '# Durable feature spec' "$case_root/$relative_spec" ||
  fail 'tracked spec content is missing'
[[ $(git -C "$case_root" log -1 --format=%s) == "docs(spec): add $feature_id" ]] ||
  fail 'promotion used the wrong commit message'
mapfile -t committed_paths < <(git -C "$case_root" diff-tree --no-commit-id --name-only -r HEAD)
[[ ${#committed_paths[@]} == 1 && ${committed_paths[0]} == "$relative_spec" ]] ||
  fail 'promotion commit contains paths other than the spec'
[[ -z $(git -C "$case_root" status --porcelain --untracked-files=all) ]] ||
  fail 'promotion did not leave a clean worktree'
$promoter \
  --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" \
  --feature-id "$feature_id" >/dev/null

# Missing local plan, conflicting destination, symlink, or unrelated change preserves metadata.
make_repo missing-plan
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
mkdir -p -- "$temporary_dir"
printf 'temporary spec\n' >"$temporary_dir/spec.md"
expect_failure 'promoter accepted a missing local plan' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
[[ -f "$temporary_dir/spec.md" ]] || fail 'missing-plan failure removed temporary spec'

make_repo destination-conflict
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
tracked_dir=$case_root/docs/dev-plans/specs/$feature_id
mkdir -p -- "$temporary_dir" "$tracked_dir"
printf 'temporary spec\n' >"$temporary_dir/spec.md"
printf 'local plan\n' >"$temporary_dir/plan.md"
printf 'different spec\n' >"$tracked_dir/spec.md"
expect_failure 'promoter overwrote a conflicting destination' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
grep -Fq 'temporary spec' "$temporary_dir/spec.md" || fail 'conflict removed temporary spec'
grep -Fq 'local plan' "$temporary_dir/plan.md" || fail 'conflict removed local plan'
grep -Fq 'different spec' "$tracked_dir/spec.md" || fail 'conflict changed destination'

make_repo symlink-destination
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
tracked_dir=$case_root/docs/dev-plans/specs/$feature_id
mkdir -p -- "$temporary_dir" "$tracked_dir"
printf 'temporary spec\n' >"$temporary_dir/spec.md"
printf 'local plan\n' >"$temporary_dir/plan.md"
outside_spec=$test_root/outside-spec
printf 'outside\n' >"$outside_spec"
ln -s -- "$outside_spec" "$tracked_dir/spec.md"
expect_failure 'promoter followed a destination symlink' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
grep -Fq 'outside' "$outside_spec" || fail 'symlink target was changed'
[[ -f "$temporary_dir/spec.md" && -f "$temporary_dir/plan.md" ]] ||
  fail 'symlink failure removed metadata'

make_repo unrelated-change
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
temporary_dir=$metadata_dir/plans/$feature_id
mkdir -p -- "$temporary_dir"
printf 'temporary spec\n' >"$temporary_dir/spec.md"
printf 'local plan\n' >"$temporary_dir/plan.md"
printf 'unrelated\n' >"$case_root/unrelated.txt"
expect_failure 'promoter accepted an unrelated worktree change' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
[[ -f "$temporary_dir/spec.md" && -f "$temporary_dir/plan.md" ]] ||
  fail 'unrelated-change failure removed metadata'

make_integration_case() {
  local name=$1
  make_repo "$name"
  main_root=$case_root
  feature_root=$test_root/$name-feature
  git -C "$main_root" worktree add -qb "feature/$feature_id" "$feature_root"
  printf 'feature\n' >>"$feature_root/README.md"
  git -C "$feature_root" add README.md
  git -C "$feature_root" commit -qm 'Implement feature'
  expected_main=$(git -C "$main_root" rev-parse HEAD)
  expected_feature=$(git -C "$feature_root" rev-parse HEAD)
  metadata_dir=$main_root/.git/dev-plan-workflow
  temporary_dir=$metadata_dir/plans/$feature_id
  mkdir -p -- "$temporary_dir"
  printf 'local plan\n' >"$temporary_dir/plan.md"
}

# Successful integration removes the local plan only after smoke passes.
make_integration_case integration-success
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --main-branch main \
  --smoke 'test -f README.md' >/dev/null
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_feature" ]] ||
  fail 'successful integration did not advance main'
assert_absent "$temporary_dir/plan.md"
assert_absent "$metadata_dir/integration.pending"

# Smoke rollback restores main and preserves the local plan.
make_integration_case integration-rollback
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --main-branch main \
  --smoke 'false' >/dev/null
integration_status=$?
set -e
[[ $integration_status == 30 ]] || fail 'smoke rollback returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'smoke rollback did not restore main'
[[ -f "$temporary_dir/plan.md" ]] || fail 'smoke rollback removed the local plan'
assert_absent "$metadata_dir/integration.pending"

printf 'All dev plan workflow tests passed.\n'
