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

make_repo metadata-symlink
git -C "$case_root" switch -qc "feature/$feature_id"
metadata_dir=$case_root/.git/dev-plan-workflow
mkdir -p -- "$metadata_dir/plans"
outside_metadata=$test_root/promotion-outside-metadata
mkdir -p -- "$outside_metadata"
printf 'temporary spec\n' >"$outside_metadata/spec.md"
printf 'local plan\n' >"$outside_metadata/plan.md"
ln -s -- "$outside_metadata" "$metadata_dir/plans/$feature_id"
expect_failure 'promoter followed a feature metadata symlink' \
  "$promoter" --metadata-dir "$metadata_dir" \
  --feature-worktree "$case_root" --feature-id "$feature_id"
[[ -f "$outside_metadata/spec.md" && -f "$outside_metadata/plan.md" ]] ||
  fail 'metadata symlink failure removed external artifacts'

make_integration_case() {
  local name=$1
  make_repo "$name"
  main_root=$case_root
  feature_root=$test_root/$name-feature
  git -C "$main_root" worktree add -qb "feature/$feature_id" "$feature_root"
  expected_main=$(git -C "$main_root" rev-parse HEAD)
  printf 'feature one\n' >>"$feature_root/README.md"
  git -C "$feature_root" add README.md
  git -C "$feature_root" commit -qm 'Implement first feature part'
  printf 'feature two\n' >"$feature_root/feature.txt"
  git -C "$feature_root" add feature.txt
  git -C "$feature_root" commit -qm 'Implement second feature part'
  expected_feature=$(git -C "$feature_root" rev-parse HEAD)
  feature_title='Example squash feature'
  squash_subject="$feature_title ($feature_id)"
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
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'test -f README.md' >/dev/null
integrated_head=$(git -C "$main_root" rev-parse HEAD)
[[ "$integrated_head" != "$expected_feature" ]] ||
  fail 'successful integration reused feature HEAD instead of creating a squash commit'
[[ $(git -C "$main_root" rev-list --count "$expected_main..$integrated_head") == 1 ]] ||
  fail 'successful integration added more than one commit to main'
[[ $(git -C "$main_root" rev-list --parents -n 1 "$integrated_head") == \
   "$integrated_head $expected_main" ]] ||
  fail 'squash commit does not have validated main as its only parent'
[[ $(git -C "$main_root" rev-parse "$integrated_head^{tree}") == \
   $(git -C "$feature_root" rev-parse "$expected_feature^{tree}") ]] ||
  fail 'squash commit tree differs from validated feature tree'
[[ $(git -C "$main_root" log -1 --format=%s "$integrated_head") == "$squash_subject" ]] ||
  fail 'squash commit subject does not contain the feature title and ID'
[[ $(git -C "$feature_root" rev-parse HEAD) == "$expected_feature" ]] ||
  fail 'successful integration changed feature HEAD'
[[ $(git -C "$feature_root" rev-list --count "$expected_main..$expected_feature") == 2 ]] ||
  fail 'successful integration changed feature commit history'
assert_absent "$temporary_dir/plan.md"
assert_absent "$metadata_dir/integration.pending"
[[ -f "$temporary_dir/integration.complete" && ! -L "$temporary_dir/integration.complete" ]] ||
  fail 'successful integration did not retain a plain completion marker'
mapfile -t completion_values <"$temporary_dir/integration.complete"
[[ ${#completion_values[@]} == 5 && ${completion_values[0]} == "$expected_main" &&
   ${completion_values[1]} == "$expected_feature" &&
   ${completion_values[2]} == "$integrated_head" ]] ||
  fail 'successful integration wrote an invalid completion marker'
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'test -f README.md' >/dev/null
rm -- "$temporary_dir/integration.complete"

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
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'false' >/dev/null
integration_status=$?
set -e
[[ $integration_status == 30 ]] || fail 'smoke rollback returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'smoke rollback did not restore main'
[[ -f "$temporary_dir/plan.md" ]] || fail 'smoke rollback removed the local plan'
assert_absent "$metadata_dir/integration.pending"
assert_absent "$temporary_dir/integration.complete"

# Concurrent feature changes during smoke are preserved while main is rolled back.
make_integration_case integration-feature-moved-during-smoke
printf -v change_feature_smoke 'git -C %q commit --allow-empty -qm %q' \
  "$feature_root" 'Concurrent feature change'
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke "$change_feature_smoke" >/dev/null
integration_status=$?
set -e
[[ $integration_status == 30 ]] || fail 'concurrent feature change returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'concurrent feature change did not roll main back'
[[ $(git -C "$feature_root" rev-parse HEAD) != "$expected_feature" ]] ||
  fail 'concurrent feature change was discarded'
[[ -f "$temporary_dir/plan.md" ]] || fail 'concurrent feature change removed the local plan'
assert_absent "$metadata_dir/integration.pending"
assert_absent "$temporary_dir/integration.complete"

# A new pending marker can resume smoke before main advances.
make_integration_case integration-pending-smoke
feature_tree=$(git -C "$feature_root" rev-parse "$expected_feature^{tree}")
squash_head=$(git -C "$main_root" commit-tree "$feature_tree" \
  -p "$expected_main" -m "$squash_subject")
printf '%s\n%s\n%s\n%s\n%s\n' \
  "$expected_main" "$expected_feature" "$squash_head" "$main_root" "$feature_root" \
  >"$metadata_dir/integration.pending"
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --recover-pending smoke \
  --smoke 'test -f feature.txt' >/dev/null
[[ $(git -C "$main_root" rev-parse HEAD) == "$squash_head" ]] ||
  fail 'pending smoke recovery did not advance main to the recorded squash commit'
assert_absent "$metadata_dir/integration.pending"
assert_absent "$temporary_dir/plan.md"
rm -- "$temporary_dir/integration.complete"

# A new pending marker can roll back before main advances without removing the local plan.
make_integration_case integration-pending-rollback
feature_tree=$(git -C "$feature_root" rev-parse "$expected_feature^{tree}")
squash_head=$(git -C "$main_root" commit-tree "$feature_tree" \
  -p "$expected_main" -m "$squash_subject")
printf '%s\n%s\n%s\n%s\n%s\n' \
  "$expected_main" "$expected_feature" "$squash_head" "$main_root" "$feature_root" \
  >"$metadata_dir/integration.pending"
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --recover-pending rollback >/dev/null
integration_status=$?
set -e
[[ $integration_status == 30 ]] || fail 'pending rollback returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'pending rollback changed main before integration'
[[ -f "$temporary_dir/plan.md" ]] || fail 'pending rollback removed the local plan'
assert_absent "$metadata_dir/integration.pending"

# Rollback before main advances does not require the unreferenced squash object to survive.
make_integration_case integration-pending-pruned-rollback
feature_tree=$(git -C "$feature_root" rev-parse "$expected_feature^{tree}")
squash_head=$(git -C "$main_root" commit-tree "$feature_tree" \
  -p "$expected_main" -m "$squash_subject")
printf '%s\n%s\n%s\n%s\n%s\n' \
  "$expected_main" "$expected_feature" "$squash_head" "$main_root" "$feature_root" \
  >"$metadata_dir/integration.pending"
git -C "$main_root" prune --expire now
if git -C "$main_root" cat-file -e "$squash_head^{commit}" 2>/dev/null; then
  fail 'prune retained the unreferenced squash commit used by the rollback test'
fi
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --recover-pending rollback >/dev/null
integration_status=$?
set -e
[[ $integration_status == 30 ]] || fail 'pruned pending rollback returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'pruned pending rollback changed main'
[[ -f "$temporary_dir/plan.md" ]] || fail 'pruned pending rollback removed the local plan'
assert_absent "$metadata_dir/integration.pending"

# Squash commit creation honors commit.gpgSign before recording pending integration metadata.
make_integration_case integration-signing-policy
git -C "$main_root" config commit.gpgSign true
git -C "$main_root" config gpg.program /bin/false
git -C "$main_root" config merge.verifySignatures true
signing_output=$test_root/integration-signing-policy.output
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'true' >"$signing_output" 2>&1
integration_status=$?
set -e
[[ $integration_status == 31 ]] || fail 'signing failure returned an unexpected status'
grep -Fq 'reason=squash-commit-failed' "$signing_output" ||
  fail 'integration did not apply commit.gpgSign while creating the squash commit'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'signing failure changed main'
[[ -f "$temporary_dir/plan.md" ]] || fail 'signing failure removed the local plan'
assert_absent "$metadata_dir/integration.pending"
assert_absent "$temporary_dir/integration.complete"

# Legacy four-field markers are rejected without changing main or metadata.
make_integration_case integration-legacy-pending
printf '%s\n%s\n%s\n%s\n' \
  "$expected_main" "$expected_feature" "$main_root" "$feature_root" \
  >"$metadata_dir/integration.pending"
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --recover-pending smoke \
  --smoke 'true' >/dev/null 2>&1
integration_status=$?
set -e
[[ $integration_status == 31 ]] || fail 'legacy pending marker returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'legacy pending marker changed main'
[[ -f "$temporary_dir/plan.md" && -f "$metadata_dir/integration.pending" ]] ||
  fail 'legacy pending marker changed integration metadata'
assert_absent "$metadata_dir/integration.lock"

make_integration_case integration-legacy-complete
git -C "$main_root" merge --ff-only "$expected_feature" >/dev/null
rm -- "$temporary_dir/plan.md"
printf '%s\n%s\n%s\n%s\n' \
  "$expected_main" "$expected_feature" "$main_root" "$feature_root" \
  >"$temporary_dir/integration.complete"
set +e
$integrator \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'true' >/dev/null 2>&1
integration_status=$?
set -e
[[ $integration_status == 31 ]] || fail 'legacy completion marker returned an unexpected status'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_feature" ]] ||
  fail 'legacy completion marker changed main'
[[ -f "$temporary_dir/integration.complete" ]] ||
  fail 'legacy completion marker was removed'
assert_absent "$metadata_dir/integration.lock"

# A symlinked feature metadata directory cannot redirect local-plan access outside Git metadata.
make_integration_case integration-metadata-symlink
outside_metadata=$test_root/integration-outside-metadata
mv -- "$temporary_dir" "$outside_metadata"
ln -s -- "$outside_metadata" "$temporary_dir"
expect_failure 'integrator followed a feature metadata symlink' \
  "$integrator" \
  --metadata-dir "$metadata_dir" \
  --feature-id "$feature_id" \
  --main-worktree "$main_root" \
  --feature-worktree "$feature_root" \
  --expected-main "$expected_main" \
  --expected-feature "$expected_feature" \
  --feature-title "$feature_title" \
  --main-branch main \
  --smoke 'test -f README.md'
[[ -f "$outside_metadata/plan.md" ]] || fail 'symlink failure removed the external plan'
[[ $(git -C "$main_root" rev-parse HEAD) == "$expected_main" ]] ||
  fail 'symlink failure changed main'

printf 'All dev plan workflow tests passed.\n'
