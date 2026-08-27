#!/usr/bin/env bash

skill_names=(plan-feature save-approved-plan run-feature)
retired_skill_names=(plan-run-feature)
managed_skill_names=("${skill_names[@]}" "${retired_skill_names[@]}")

fail() {
  printf 'error: %s\n' "$*" >&2
  return 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

assert_plain_directory_or_absent() {
  local path=$1

  if [[ -L "$path" ]]; then
    fail "refusing to use symbolic-link directory: $path"
    return
  fi
  if [[ -e "$path" && ! -d "$path" ]]; then
    fail "path exists and is not a directory: $path"
  fi
}

copy_directory_contents() {
  local source=$1 destination=$2

  mkdir -- "$destination"
  cp -a -- "$source"/. "$destination"/
  chmod --reference="$source" -- "$destination"
}

directories_equal() {
  local left=$1 right=$2

  diff -qr -- "$left" "$right" >/dev/null &&
    cmp -s \
      <(
        CDPATH= cd -- "$left"
        printf '.\0d\0%s\0\0' "$(stat -c %a .)"
        find . -mindepth 1 -printf '%P\0%y\0%m\0%l\0' | LC_ALL=C sort -z
      ) \
      <(
        CDPATH= cd -- "$right"
        printf '.\0d\0%s\0\0' "$(stat -c %a .)"
        find . -mindepth 1 -printf '%P\0%y\0%m\0%l\0' | LC_ALL=C sort -z
      )
}

new_managed_path() {
  local root=$1 kind=$2
  local stamp candidate existing name existing_sequence sequence=0

  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  for existing in "$root/$stamp"-??????-*; do
    if path_exists "$existing"; then
      name=${existing##*/}
      existing_sequence=${name#"$stamp-"}
      existing_sequence=${existing_sequence%%-*}
      if [[ "$existing_sequence" =~ ^[0-9]{6}$ ]] &&
        ((10#$existing_sequence >= sequence)); then
        sequence=$((10#$existing_sequence + 1))
      fi
    fi
  done

  printf -v candidate '%s/%s-%06d-%s' "$root" "$stamp" "$sequence" "$kind"
  while path_exists "$candidate"; do
    sequence=$((sequence + 1))
    printf -v candidate '%s/%s-%06d-%s' "$root" "$stamp" "$sequence" "$kind"
  done
  printf '%s\n' "$candidate"
}

create_backup_set() {
  local kind=$1
  local final_path temporary_path skill target

  mkdir -p -- "$backup_root"
  final_path=$(new_managed_path "$backup_root" "$kind")
  temporary_path="$backup_root/.${final_path##*/}.tmp-$$"
  while path_exists "$temporary_path"; do
    temporary_path="$temporary_path-x"
  done
  mkdir -- "$temporary_path"

  for skill in "${managed_skill_names[@]}"; do
    target=$target_root/$skill
    if path_exists "$target"; then
      copy_directory_contents "$target" "$temporary_path/$skill"
      directories_equal "$target" "$temporary_path/$skill" || {
        rm -rf -- "$temporary_path"
        fail "backup verification failed for $skill"
        return
      }
    fi
  done

  {
    printf 'schema_version=1\n'
    printf 'kind=%s\n' "$kind"
    printf 'created_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'skills=%s\n' "${managed_skill_names[*]}"
  } >"$temporary_path/.feature-workflow-backup"

  mv -- "$temporary_path" "$final_path"
  printf '%s\n' "$final_path"
}

prune_backups() {
  local path kind marker
  local -a backups=()

  [[ -d "$backup_root" && ! -L "$backup_root" ]] || return 0
  while IFS= read -r path; do
    backups+=("$path")
  done < <(
    for path in \
      "$backup_root"/????????T??????Z-??????-install \
      "$backup_root"/????????T??????Z-??????-migration \
      "$backup_root"/????????T??????Z-??????-uninstall; do
      [[ -d "$path" && ! -L "$path" ]] || continue
      marker=$path/.feature-workflow-backup
      [[ -f "$marker" && ! -L "$marker" ]] || continue
      kind=${path##*-}
      grep -Fxq 'schema_version=1' "$marker" || continue
      grep -Fxq "kind=$kind" "$marker" || continue
      printf '%s\n' "$path"
    done | sort
  )

  while ((${#backups[@]} > 5)); do
    rm -rf -- "${backups[0]}"
    backups=("${backups[@]:1}")
  done
}

make_transaction_directory() {
  local kind=$1 candidate

  candidate="$target_parent/.feature-workflow-${kind}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  while path_exists "$candidate"; do
    candidate="$candidate-x"
  done
  mkdir -- "$candidate"
  printf '%s\n' "$candidate"
}

validate_roots() {
  local backup_parent
  backup_parent=$(dirname -- "$backup_root")

  assert_plain_directory_or_absent "$target_parent"
  assert_plain_directory_or_absent "$target_root"
  assert_plain_directory_or_absent "$backup_parent"
  assert_plain_directory_or_absent "$backup_root"
}

acquire_workflow_lock() {
  local lock_path=$target_parent/.feature-workflow.lock

  command -v flock >/dev/null 2>&1 || fail 'required command not found: flock'
  mkdir -p -- "$target_parent"
  if [[ -L "$lock_path" || -e "$lock_path" && ! -f "$lock_path" ]]; then
    fail "refusing to use invalid lock path: $lock_path"
  fi
  exec {workflow_lock_fd}>>"$lock_path"
  flock -x "$workflow_lock_fd"
}

validate_sources() {
  local skill source metadata expected_implicit

  for skill in "${skill_names[@]}"; do
    source=$source_root/$skill
    metadata=$source/agents/openai.yaml
    expected_implicit=false
    if [[ "$skill" == save-approved-plan ]]; then
      expected_implicit=true
    fi

    [[ -d "$source" && ! -L "$source" ]] || fail "missing skill source: $source"
    [[ -f "$source/SKILL.md" ]] || fail "missing SKILL.md: $source/SKILL.md"
    [[ -f "$metadata" ]] || fail "missing agent metadata: $metadata"
    grep -Eq \
      "^[[:space:]]*allow_implicit_invocation:[[:space:]]*$expected_implicit[[:space:]]*$" \
      "$metadata" || fail "unexpected implicit invocation policy: $metadata"
  done

  [[ -x "$source_root/run-feature/scripts/integrate-feature.sh" ]] ||
    fail 'integration helper is not executable'
}

initialize_paths() {
  script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd -P)
  repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
  source_root=$repo_root/skills
  user_home=${HOME:?HOME must be set}
  target_root=${FEATURE_WORKFLOW_TARGET_ROOT:-$user_home/.agents/skills}
  backup_root=${FEATURE_WORKFLOW_BACKUP_ROOT:-$user_home/.agents/skill-backups/feature-workflow}
  target_parent=$(dirname -- "$target_root")

  [[ -n "$target_root" ]] || fail 'target root must not be empty'
  [[ -n "$backup_root" ]] || fail 'backup root must not be empty'
}
