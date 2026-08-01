#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-global-skills.sh
  install-global-skills.sh --check

Install or verify independent copies of this repository's four skills under
~/.agents/skills. Updates back up and replace the complete workflow atomically.
EOF
}

mode=install
case ${1-} in
  '')
    ;;
  --check)
    mode=check
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
validate_sources
validate_roots
acquire_workflow_lock
validate_roots

all_current=true
has_existing=false
has_legacy_link=false
for skill in "${skill_names[@]}"; do
  source_dir=$source_root/$skill
  target=$target_root/$skill

  if [[ -L "$target" ]]; then
    actual=$(readlink -f -- "$target" || true)
    expected=$(readlink -f -- "$source_dir")
    [[ -n "$actual" && "$actual" == "$expected" ]] ||
      fail "refusing to replace unmanaged or broken symbolic link: $target"
    has_existing=true
    has_legacy_link=true
    all_current=false
  elif [[ -e "$target" ]]; then
    [[ -d "$target" ]] || fail "target exists and is not a directory: $target"
    has_existing=true
    if ! directories_equal "$source_dir" "$target"; then
      all_current=false
    fi
  else
    all_current=false
  fi
done

if [[ "$mode" == check ]]; then
  [[ "$all_current" == true ]] || fail 'global skill copies are missing, stale, or symbolic links'
  printf 'ok: all global skill copies are current\n'
  exit 0
fi

if [[ "$all_current" == true ]]; then
  printf 'unchanged: all global skill copies are current\n'
  exit 0
fi

mkdir -p -- "$target_root"
stage_dir=$(make_transaction_directory stage)
rollback_dir=$stage_dir/rollback
mkdir -- "$rollback_dir"
transaction_finished=false
moved_originals=()
promoted=()

recover_installation() {
  local skill promoted_skill target failed_root=$stage_dir/failed-install
  local was_promoted
  local recovery_failed=false

  mkdir -p -- "$failed_root"
  for skill in "${skill_names[@]}"; do
    target=$target_root/$skill
    if path_exists "$rollback_dir/$skill"; then
      if path_exists "$target" && ! mv -- "$target" "$failed_root/$skill"; then
        recovery_failed=true
        continue
      fi
      if ! mv -- "$rollback_dir/$skill" "$target"; then
        recovery_failed=true
      fi
      continue
    fi

    was_promoted=false
    for promoted_skill in "${promoted[@]}"; do
      if [[ "$promoted_skill" == "$skill" ]]; then
        was_promoted=true
        break
      fi
    done
    if [[ "$was_promoted" == true ]] && path_exists "$target"; then
      if ! mv -- "$target" "$failed_root/$skill"; then
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

  if recover_installation; then
    case ${stage_dir:-} in
      "$target_parent"/.feature-workflow-stage-*)
        rm -rf -- "$stage_dir"
        ;;
    esac
  else
    printf 'error: automatic restore was incomplete; recovery data remains at: %s\n' \
      "$stage_dir" >&2
  fi
  return "$status"
}
trap cleanup_transaction EXIT

for skill in "${skill_names[@]}"; do
  copy_directory_contents "$source_root/$skill" "$stage_dir/$skill"
  directories_equal "$source_root/$skill" "$stage_dir/$skill" ||
    fail "staged copy differs from source: $skill"
done

backup_path=''
if [[ "$has_existing" == true ]]; then
  backup_kind=install
  if [[ "$has_legacy_link" == true ]]; then
    backup_kind=migration
  fi
  backup_path=$(create_backup_set "$backup_kind")
fi

promotion_failed=false
for skill in "${skill_names[@]}"; do
  target=$target_root/$skill
  if path_exists "$target"; then
    if ! mv -- "$target" "$rollback_dir/$skill"; then
      promotion_failed=true
      break
    fi
    moved_originals+=("$skill")
  fi
done

if [[ "$promotion_failed" == false ]]; then
  for skill in "${skill_names[@]}"; do
    if ! mv -- "$stage_dir/$skill" "$target_root/$skill"; then
      promotion_failed=true
      break
    fi
    promoted+=("$skill")
  done
fi

if [[ "$promotion_failed" == true ]]; then
  if ! recover_installation; then
    transaction_finished=true
    trap - EXIT
    fail "installation failed and automatic restore was incomplete; recovery data remains at: $stage_dir"
  fi
  transaction_finished=true
  trap - EXIT
  rm -rf -- "$stage_dir"
  fail 'installation failed; the previous workflow installation was restored'
fi

rm -rf -- "$rollback_dir"
rmdir -- "$stage_dir"
transaction_finished=true
trap - EXIT
prune_backups

if [[ "$has_legacy_link" == true ]]; then
  printf 'migrated: symbolic links replaced with independent skill copies\n'
else
  printf 'installed: all global skill copies are current\n'
fi
if [[ -n "$backup_path" ]]; then
  printf 'backup: %s\n' "$backup_path"
fi
