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

count_backups() {
  local root=$1 path kind marker count=0
  for path in \
    "$root"/????????T??????Z-??????-install \
    "$root"/????????T??????Z-??????-uninstall; do
    [[ -d "$path" && ! -L "$path" ]] || continue
    marker=$path/.dev-plan-workflow-backup
    [[ -f "$marker" && ! -L "$marker" ]] || continue
    kind=${path##*-}
    grep -Fxq 'schema_version=1' "$marker" || continue
    grep -Fxq "kind=$kind" "$marker" || continue
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

newest_backup() {
  find "$1" -mindepth 1 -maxdepth 1 -type d \
    -name '????????T??????Z-??????-*' -print | sort | tail -n 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
install_script=$repo_root/scripts/install-global-skills.sh
uninstall_script=$repo_root/scripts/uninstall-global-skills.sh
source_root=$repo_root/skills
skill_names=(create-dev-plan save-dev-plan implement-dev-plan)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dev plan workflow skills tests.XXXXXX")

cleanup() {
  case $test_root in
    "${TMPDIR:-/tmp}"/'dev plan workflow skills tests.'*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing unsafe test cleanup: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

run_install() {
  local root=$1
  shift
  DEV_PLAN_WORKFLOW_TARGET_ROOT=$root/skills \
    DEV_PLAN_WORKFLOW_BACKUP_ROOT=$root/backups \
    "$install_script" "$@"
}

run_uninstall() {
  local root=$1
  shift
  DEV_PLAN_WORKFLOW_TARGET_ROOT=$root/skills \
    DEV_PLAN_WORKFLOW_BACKUP_ROOT=$root/backups \
    "$uninstall_script" "$@"
}

# Removed environment-variable names fail instead of silently targeting the default installation.
legacy_namespace_root=$test_root/'removed environment namespace'
mkdir -p -- "$legacy_namespace_root/home"
if env -u DEV_PLAN_WORKFLOW_TARGET_ROOT -u DEV_PLAN_WORKFLOW_BACKUP_ROOT \
  HOME="$legacy_namespace_root/home" \
  FEATURE_WORKFLOW_TARGET_ROOT="$legacy_namespace_root/legacy-skills" \
  FEATURE_WORKFLOW_BACKUP_ROOT="$legacy_namespace_root/legacy-backups" \
  "$install_script" >/dev/null 2>&1; then
  fail 'installer accepted removed FEATURE_WORKFLOW environment variables'
fi
assert_absent "$legacy_namespace_root/legacy-skills"
assert_absent "$legacy_namespace_root/legacy-backups"
assert_absent "$legacy_namespace_root/home/.agents/skills"

assert_current_install() {
  local root=$1 skill
  for skill in "${skill_names[@]}"; do
    assert_directory "$root/skills/$skill"
    diff -qr -- "$source_root/$skill" "$root/skills/$skill" >/dev/null ||
      fail "installed copy differs from source: $skill"
  done
  assert_absent "$root/skills/skills-ko"
}

# A path containing spaces supports fresh install, check, and idempotent reinstall.
fresh_root=$test_root/'fresh root'
run_install "$fresh_root"
assert_current_install "$fresh_root"
run_install "$fresh_root" --check
run_install "$fresh_root"
[[ $(count_backups "$fresh_root/backups") == 0 ]] ||
  fail 'idempotent install created a backup'

# Names outside the current workflow are ignored by install, check, and uninstall.
legacy_root=$test_root/'unmanaged names root'
legacy_link_target=$test_root/'unmanaged names target'
legacy_names=(plan-feature run-feature plan-run-feature)
mkdir -p -- "$legacy_root/skills" "$legacy_link_target"
for legacy_name in "${legacy_names[@]}"; do
  mkdir -- "$legacy_root/skills/$legacy_name"
  printf 'unmanaged sentinel: %s\n' "$legacy_name" \
    >"$legacy_root/skills/$legacy_name/sentinel"
done
ln -s -- "$legacy_link_target/missing" \
  "$legacy_root/skills/save-approved-plan"
run_install "$legacy_root"
assert_current_install "$legacy_root"
run_install "$legacy_root" --check
[[ $(count_backups "$legacy_root/backups") == 0 ]] ||
  fail 'unmanaged names caused an install backup'
for legacy_name in "${legacy_names[@]}"; do
  grep -Fq "unmanaged sentinel: $legacy_name" \
    "$legacy_root/skills/$legacy_name/sentinel" ||
    fail "installer changed unmanaged name: $legacy_name"
done
[[ -L "$legacy_root/skills/save-approved-plan" ]] ||
  fail 'installer changed unmanaged symbolic link'
run_uninstall "$legacy_root"
for skill in "${skill_names[@]}"; do
  assert_absent "$legacy_root/skills/$skill"
done
for legacy_name in "${legacy_names[@]}"; do
  assert_directory "$legacy_root/skills/$legacy_name"
done
[[ -L "$legacy_root/skills/save-approved-plan" ]] ||
  fail 'uninstaller changed unmanaged symbolic link'

# Metadata drift, including a lost executable bit, is detected and repaired.
chmod 0644 "$fresh_root/skills/implement-dev-plan/scripts/integrate-feature.sh"
if run_install "$fresh_root" --check >/dev/null 2>&1; then
  fail '--check accepted an installed helper with the wrong mode'
fi
run_install "$fresh_root"
[[ -x "$fresh_root/skills/implement-dev-plan/scripts/integrate-feature.sh" ]] ||
  fail 'reinstall did not restore the integration helper executable bit'
[[ $(count_backups "$fresh_root/backups") == 1 ]] ||
  fail 'mode repair did not create exactly one backup set'

# A change to one installed skill backs up and replaces the complete workflow.
printf '\nlocal installed change\n' >>"$fresh_root/skills/create-dev-plan/SKILL.md"
run_install "$fresh_root"
assert_current_install "$fresh_root"
[[ $(count_backups "$fresh_root/backups") == 2 ]] ||
  fail 'changed install did not create one additional backup set'
first_backup=$(newest_backup "$fresh_root/backups")
grep -Fq 'local installed change' "$first_backup/create-dev-plan/SKILL.md" ||
  fail 'backup did not preserve the changed installation'
for skill in "${skill_names[@]}"; do
  assert_directory "$first_backup/$skill"
done

# Symbolic links at current managed names are refused without modification.
symlink_root=$test_root/'managed-name symlink root'
mkdir -p -- "$symlink_root/skills"
for skill in "${skill_names[@]}"; do
  ln -s -- "$source_root/$skill" "$symlink_root/skills/$skill"
done
if run_install "$symlink_root" >/dev/null 2>&1; then
  fail 'installer accepted symbolic links at current managed names'
fi
if run_uninstall "$symlink_root" >/dev/null 2>&1; then
  fail 'uninstaller accepted symbolic links at current managed names'
fi
for skill in "${skill_names[@]}"; do
  [[ -L "$symlink_root/skills/$skill" ]] ||
    fail "workflow command changed managed-name symbolic link: $skill"
done
assert_absent "$symlink_root/backups"

# Stale checks, unmanaged links, broken links, and file conflicts are refused unchanged.
stale_root=$test_root/'stale root'
run_install "$stale_root"
printf '\nstale\n' >>"$stale_root/skills/implement-dev-plan/SKILL.md"
if run_install "$stale_root" --check >/dev/null 2>&1; then
  fail '--check accepted a stale installation'
fi

conflict_root=$test_root/'conflict root'
outside=$test_root/'outside target'
mkdir -p -- "$conflict_root/skills" "$outside"
printf 'outside sentinel\n' >"$outside/sentinel"
ln -s -- "$outside" "$conflict_root/skills/create-dev-plan"
if run_install "$conflict_root" >/dev/null 2>&1; then
  fail 'installer accepted an unmanaged symbolic link'
fi
[[ -L "$conflict_root/skills/create-dev-plan" ]] || fail 'unmanaged link was changed'
grep -Fq 'outside sentinel' "$outside/sentinel" || fail 'unmanaged link destination was changed'

broken_root=$test_root/'broken link root'
mkdir -p -- "$broken_root/skills"
ln -s -- "$broken_root/missing" "$broken_root/skills/create-dev-plan"
if run_install "$broken_root" >/dev/null 2>&1; then
  fail 'installer accepted a broken symbolic link'
fi
[[ -L "$broken_root/skills/create-dev-plan" ]] || fail 'broken link was changed'

file_root=$test_root/'file root'
mkdir -p -- "$file_root/skills"
printf 'keep file\n' >"$file_root/skills/create-dev-plan"
if run_install "$file_root" >/dev/null 2>&1; then
  fail 'installer accepted a file conflict'
fi
grep -Fq 'keep file' "$file_root/skills/create-dev-plan" || fail 'file conflict was changed'

linked_root=$test_root/'linked managed root'
linked_destination=$test_root/'linked managed destination'
mkdir -p -- "$linked_root" "$linked_destination"
ln -s -- "$linked_destination" "$linked_root/skills"
if run_install "$linked_root" >/dev/null 2>&1; then
  fail 'installer accepted a symbolic-link target root'
fi
[[ -L "$linked_root/skills" ]] || fail 'symbolic-link target root was changed'

# Acquiring a pre-existing regular lock never truncates it or a hard-linked inode.
lock_root=$test_root/'existing lock root'
lock_victim=$test_root/'lock victim'
lock_snapshot=$test_root/'lock victim snapshot'
mkdir -p -- "$lock_root"
printf 'pre-existing lock content must survive\n' >"$lock_victim"
cp -- "$lock_victim" "$lock_snapshot"
ln -- "$lock_victim" "$lock_root/.dev-plan-workflow.lock"
run_install "$lock_root"
cmp -s -- "$lock_snapshot" "$lock_victim" ||
  fail 'installer truncated a pre-existing lock inode'

# A failed promotion restores every previous target, including local installed changes.
rollback_root=$test_root/'rollback root'
run_install "$rollback_root"
printf 'must survive rollback\n' >>"$rollback_root/skills/create-dev-plan/SKILL.md"
fake_bin=$test_root/'fake bin'
mkdir -p -- "$fake_bin"
real_mv=$(command -v mv)
cp -- "$script_dir/fixtures/fake-mv.sh" "$fake_bin/mv"
chmod 0755 "$fake_bin/mv"
if DEV_PLAN_WORKFLOW_TARGET_ROOT="$rollback_root/skills" \
  DEV_PLAN_WORKFLOW_BACKUP_ROOT="$rollback_root/backups" \
  PATH="$fake_bin:$PATH" REAL_MV="$real_mv" \
  FAKE_FAIL_TARGET="$rollback_root/skills/implement-dev-plan" \
  FAKE_FAIL_MARKER="$test_root/failure-marker" \
  "$install_script" >/dev/null 2>&1; then
  fail 'installer unexpectedly succeeded when promotion failed'
fi
for skill in "${skill_names[@]}"; do
  assert_directory "$rollback_root/skills/$skill"
done
grep -Fq 'must survive rollback' "$rollback_root/skills/create-dev-plan/SKILL.md" ||
  fail 'failed promotion did not restore the previous workflow'

# A failed uninstall move also restores the complete workflow.
uninstall_rollback_root=$test_root/'uninstall rollback root'
run_install "$uninstall_rollback_root"
printf 'must survive uninstall rollback\n' \
  >>"$uninstall_rollback_root/skills/create-dev-plan/SKILL.md"
if DEV_PLAN_WORKFLOW_TARGET_ROOT="$uninstall_rollback_root/skills" \
  DEV_PLAN_WORKFLOW_BACKUP_ROOT="$uninstall_rollback_root/backups" \
  PATH="$fake_bin:$PATH" REAL_MV="$real_mv" \
  FAKE_FAIL_BASENAME=implement-dev-plan \
  FAKE_FAIL_MARKER="$test_root/uninstall-failure-marker" \
  "$uninstall_script" >/dev/null 2>&1; then
  fail 'uninstaller unexpectedly succeeded when a target move failed'
fi
for skill in "${skill_names[@]}"; do
  assert_directory "$uninstall_rollback_root/skills/$skill"
done
grep -Fq 'must survive uninstall rollback' \
  "$uninstall_rollback_root/skills/create-dev-plan/SKILL.md" ||
  fail 'failed uninstall did not restore the previous workflow'

# Concurrent installers serialize the complete inspection and promotion transaction.
concurrent_root=$test_root/'concurrent root'
run_install "$concurrent_root"
printf 'concurrent stale change\n' >>"$concurrent_root/skills/create-dev-plan/SKILL.md"
concurrent_pids=()
for iteration in 1 2 3 4 5 6 7 8; do
  run_install "$concurrent_root" >"$test_root/concurrent-$iteration.log" 2>&1 &
  concurrent_pids+=("$!")
done
for pid in "${concurrent_pids[@]}"; do
  wait "$pid" || fail 'a serialized concurrent installer failed'
done
assert_current_install "$concurrent_root"
run_install "$concurrent_root" --check
[[ $(count_backups "$concurrent_root/backups") == 1 ]] ||
  fail 'concurrent installers created duplicate backup sets'

# Retention keeps the newest five managed sets without touching unrelated entries.
retention_root=$test_root/'retention root'
run_install "$retention_root"
mkdir -p -- "$retention_root/backups/keep-me"
mkdir -p -- "$retention_root/backups/20000101T000000Z-000000-install"
printf 'unrelated matching-name directory\n' \
  >"$retention_root/backups/20000101T000000Z-000000-install/sentinel"
for iteration in 1 2 3 4 5 6; do
  printf 'change %s\n' "$iteration" >>"$retention_root/skills/create-dev-plan/SKILL.md"
  run_install "$retention_root" >/dev/null
done
[[ $(count_backups "$retention_root/backups") == 5 ]] ||
  fail 'backup retention did not keep exactly five managed sets'
assert_directory "$retention_root/backups/keep-me"
grep -Fq 'unrelated matching-name directory' \
  "$retention_root/backups/20000101T000000Z-000000-install/sentinel" ||
  fail 'retention deleted an unrelated matching-name directory'

# Uninstall backs up the whole workflow, is idempotent, and supports manual restoration.
run_uninstall "$retention_root"
for skill in "${skill_names[@]}"; do
  assert_absent "$retention_root/skills/$skill"
done
[[ $(count_backups "$retention_root/backups") == 5 ]] ||
  fail 'uninstall did not preserve the five-backup limit'
uninstall_backup=$(find "$retention_root/backups" -mindepth 1 -maxdepth 1 -type d \
  -name '????????T??????Z-??????-uninstall' -print | sort | tail -n 1)
[[ -n "$uninstall_backup" ]] || fail 'uninstall backup is missing'
for skill in "${skill_names[@]}"; do
  cp -a -- "$uninstall_backup/$skill" "$retention_root/skills/$skill"
  diff -qr -- "$uninstall_backup/$skill" "$retention_root/skills/$skill" >/dev/null ||
    fail "manual restoration differs from backup: $skill"
done
run_install "$retention_root" --check
run_uninstall "$retention_root" >/dev/null
run_uninstall "$retention_root"

printf 'All global skill installer tests passed.\n'
