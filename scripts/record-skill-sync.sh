#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=skill-sync-common.sh
source "$script_dir/skill-sync-common.sh"
initialize_skill_sync
validate_skill_sync_sources

temporary_state=$(mktemp "$sync_korean_root/.sync-state.sha256.tmp.XXXXXX")
record_finished=false
cleanup() {
  if [[ "$record_finished" == false ]]; then
    rm -f -- "$temporary_state"
  fi
}
trap cleanup EXIT

write_current_skill_checksums >"$temporary_state"
chmod 0644 -- "$temporary_state"
mv -- "$temporary_state" "$sync_state_path"
record_finished=true
trap - EXIT

printf 'recorded: Korean sources and English installed skills are synchronized\n'
