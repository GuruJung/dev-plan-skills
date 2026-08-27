#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: uninstall-global-skills.sh

Remove this workflow's installed skill copies after preserving them as one
recoverable backup set.
EOF
}

case ${1-} in
  '')
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
if (($# > 1)); then
  usage >&2
  exit 64
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=global-skills-common.sh
source "$script_dir/global-skills-common.sh"
initialize_paths
validate_roots
acquire_workflow_lock
validate_roots

has_existing=false
for skill in "${managed_skill_names[@]}"; do
  target=$target_root/$skill
  if [[ -L "$target" ]]; then
    if ! is_retired_skill "$skill"; then
      fail "refusing to remove symbolic-link target: $target"
    fi
    is_managed_retired_link "$target" "$skill" ||
      fail "refusing to remove unmanaged retired symbolic link: $target"
    has_existing=true
  elif [[ -e "$target" ]]; then
    [[ -d "$target" ]] || fail "target exists and is not a directory: $target"
    has_existing=true
  fi
done

if [[ "$has_existing" == false ]]; then
  printf 'unchanged: no global workflow skill copies are installed\n'
  exit 0
fi

mkdir -p -- "$target_root"
backup_path=$(create_backup_set uninstall)
transaction_dir=$(make_transaction_directory uninstall)
transaction_finished=false
moved=()

recover_uninstall() {
  local skill target
  local recovery_failed=false

  for skill in "${managed_skill_names[@]}"; do
    target=$target_root/$skill
    if path_exists "$transaction_dir/$skill"; then
      if path_exists "$target" || ! mv -- "$transaction_dir/$skill" "$target"; then
        recovery_failed=true
      fi
    fi
  done
  [[ "$recovery_failed" == false ]]
}

cleanup_transaction() {
  local status=$?
  if [[ "$transaction_finished" == true ]]; then
    return "$status"
  fi

  if recover_uninstall; then
    case ${transaction_dir:-} in
      "$target_parent"/.feature-workflow-uninstall-*)
        rm -rf -- "$transaction_dir"
        ;;
    esac
  else
    printf 'error: automatic restore was incomplete; recovery data remains at: %s\n' \
      "$transaction_dir" >&2
  fi
  return "$status"
}
trap cleanup_transaction EXIT

move_failed=false
for skill in "${managed_skill_names[@]}"; do
  target=$target_root/$skill
  if path_exists "$target"; then
    if ! mv -- "$target" "$transaction_dir/$skill"; then
      move_failed=true
      break
    fi
    moved+=("$skill")
  fi
done

if [[ "$move_failed" == true ]]; then
  if ! recover_uninstall; then
    transaction_finished=true
    trap - EXIT
    fail "uninstall failed and automatic restore was incomplete; recovery data remains at: $transaction_dir"
  fi
  transaction_finished=true
  trap - EXIT
  rm -rf -- "$transaction_dir"
  fail 'uninstall failed; the previous workflow installation was restored'
fi

rm -rf -- "$transaction_dir"
transaction_finished=true
trap - EXIT
prune_backups
printf 'removed: global workflow skill copies\n'
printf 'backup: %s\n' "$backup_path"
