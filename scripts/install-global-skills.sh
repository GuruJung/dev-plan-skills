#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-global-skills.sh
  install-global-skills.sh --check

Install or verify absolute symbolic links for this repository's skills under
~/.agents/skills. Existing files, directories, broken links, and links to other
targets are never overwritten.
EOF
}

mode=install
case ${1-} in
  "")
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

script_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -P -- "$script_dir/.." && pwd)
source_root=$repo_root/skills
user_home=${HOME:?HOME must be set}
target_root=${FEATURE_WORKFLOW_TARGET_ROOT:-$user_home/.agents/skills}
skill_names=(plan-feature save-approved-plan run-feature)
created_links=()

fail() {
  printf 'error: %s\n' "$*" >&2
  return 1
}

rollback_created_links() {
  local status=$?
  local link

  if ((status != 0)); then
    for link in "${created_links[@]}"; do
      if [[ -L "$link" ]]; then
        rm -f -- "$link"
      fi
    done
  fi
  exit "$status"
}

validate_sources() {
  local skill source metadata

  for skill in "${skill_names[@]}"; do
    source=$source_root/$skill
    metadata=$source/agents/openai.yaml

    [[ -d "$source" ]] || fail "missing skill source: $source"
    [[ -f "$source/SKILL.md" ]] || fail "missing SKILL.md: $source/SKILL.md"
    [[ -f "$metadata" ]] || fail "missing agent metadata: $metadata"
    grep -Eq '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false[[:space:]]*$' \
      "$metadata" || fail "explicit-only policy missing: $metadata"
  done

  [[ -x "$source_root/run-feature/scripts/integrate-feature.sh" ]] ||
    fail "integration helper is not executable"
}

validate_target() {
  local skill=$1
  local source=$source_root/$skill
  local target=$target_root/$skill
  local actual

  if [[ -L "$target" ]]; then
    actual=$(readlink -- "$target")
    [[ "$actual" == "$source" ]] ||
      fail "target conflict: $target -> $actual (expected $source)"
    return
  fi

  if [[ -e "$target" ]]; then
    fail "target conflict: $target exists and is not the managed symbolic link"
  fi

  if [[ "$mode" == check ]]; then
    fail "missing symbolic link: $target"
  fi
}

validate_sources

if [[ -L "$target_root" && ! -e "$target_root" ]]; then
  fail "target root is a broken symbolic link: $target_root"
fi
if [[ -e "$target_root" && ! -d "$target_root" ]]; then
  fail "target root exists and is not a directory: $target_root"
fi

for skill in "${skill_names[@]}"; do
  validate_target "$skill"
done

if [[ "$mode" == check ]]; then
  printf 'ok: all global skill links are valid\n'
  exit 0
fi

trap rollback_created_links EXIT
mkdir -p -- "$target_root"

for skill in "${skill_names[@]}"; do
  source=$source_root/$skill
  target=$target_root/$skill

  if [[ -L "$target" ]]; then
    printf 'unchanged: %s -> %s\n' "$target" "$source"
    continue
  fi

  ln -s -- "$source" "$target"
  created_links+=("$target")
  printf 'installed: %s -> %s\n' "$target" "$source"
done

trap - EXIT
printf 'ok: global skill installation is complete\n'
