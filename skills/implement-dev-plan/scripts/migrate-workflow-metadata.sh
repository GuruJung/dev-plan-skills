#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: migrate-workflow-metadata.sh --repo PATH\n'
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

repo=
while (($#)); do
  case $1 in
    --repo)
      (($# >= 2)) || fail 'missing value for --repo'
      repo=$2
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

[[ -n "$repo" ]] || fail '--repo is required'
command -v git >/dev/null || fail 'git is required'
command -v flock >/dev/null || fail 'flock is required'

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail "not a Git worktree: $repo"
common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
legacy_dir=$common_dir/feature-workflow
workflow_dir=$common_dir/dev-plan-workflow
migration_lock=$common_dir/.dev-plan-workflow-migration.lock

if [[ -L "$migration_lock" || -e "$migration_lock" && ! -f "$migration_lock" ]]; then
  fail "refusing invalid migration lock: $migration_lock"
fi
exec 8>>"$migration_lock"
flock -x 8

legacy_exists=false
workflow_exists=false
path_exists "$legacy_dir" && legacy_exists=true
path_exists "$workflow_dir" && workflow_exists=true

if [[ "$legacy_exists" == true && "$workflow_exists" == true ]]; then
  fail "legacy and canonical workflow directories both exist: $legacy_dir, $workflow_dir"
fi

if [[ "$workflow_exists" == true ]]; then
  [[ -d "$workflow_dir" && ! -L "$workflow_dir" ]] ||
    fail "canonical workflow path is not a plain directory: $workflow_dir"
  printf '%s\n' "$workflow_dir"
  exit 0
fi

if [[ "$legacy_exists" == false ]]; then
  mkdir -- "$workflow_dir"
  printf '%s\n' "$workflow_dir"
  exit 0
fi

[[ -d "$legacy_dir" && ! -L "$legacy_dir" ]] ||
  fail "legacy workflow path is not a plain directory: $legacy_dir"
legacy_lock=$legacy_dir/integration.lock
if [[ -L "$legacy_lock" || -e "$legacy_lock" && ! -f "$legacy_lock" ]]; then
  fail "refusing invalid legacy integration lock: $legacy_lock"
fi
exec 9>>"$legacy_lock"
flock -x 9

path_exists "$workflow_dir" &&
  fail "canonical workflow directory appeared during migration: $workflow_dir"
[[ -d "$legacy_dir" && ! -L "$legacy_dir" ]] ||
  fail "legacy workflow directory changed during migration: $legacy_dir"
if path_exists "$legacy_dir/integration.pending"; then
  fail "legacy pending integration must be recovered before migration: $legacy_dir/integration.pending"
fi

mv -- "$legacy_dir" "$workflow_dir"
[[ -d "$workflow_dir" && ! -L "$workflow_dir" ]] ||
  fail "workflow metadata migration did not produce a plain directory: $workflow_dir"
printf '%s\n' "$workflow_dir"
