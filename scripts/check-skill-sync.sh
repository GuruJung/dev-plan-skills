#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=skill-sync-common.sh
source "$script_dir/skill-sync-common.sh"
initialize_skill_sync
validate_skill_sync_sources

[[ -f "$sync_state_path" && ! -L "$sync_state_path" ]] ||
  sync_fail "missing or invalid sync state: $sync_state_path"

expected_state=$(mktemp "${TMPDIR:-/tmp}/feature-workflow-sync.XXXXXX")
cleanup() {
  rm -f -- "$expected_state"
}
trap cleanup EXIT

write_current_skill_checksums >"$expected_state"
if ! cmp -s -- "$expected_state" "$sync_state_path"; then
  (
    cd -- "$sync_repo_root"
    sha256sum -c -- "$sync_state_path"
  ) >&2 || true
  sync_fail 'skill translations or sync state are stale; translate both sides and record again'
fi

printf 'ok: all Korean sources and English installed skills are synchronized\n'
