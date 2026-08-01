#!/usr/bin/env bash

sync_fail() {
  printf 'error: %s\n' "$*" >&2
  return 1
}

initialize_skill_sync() {
  local script_dir
  script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd -P)
  sync_repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
  sync_english_root=$sync_repo_root/skills
  sync_korean_root=$sync_repo_root/skills-ko
  sync_state_path=$sync_korean_root/.sync-state.sha256
  sync_skill_names=()
}

frontmatter_name() {
  awk '
    NR == 1 {
      if ($0 != "---") exit 2
      next
    }
    $0 == "---" { exit }
    /^[[:space:]]*name:[[:space:]]*/ {
      sub(/^[[:space:]]*name:[[:space:]]*/, "")
      print
      found = 1
    }
    END {
      if (!found) exit 3
    }
  ' "$1"
}

collect_skill_names() {
  local root=$1 path
  local -n destination=$2

  destination=()
  while IFS= read -r path; do
    destination+=("${path##*/}")
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
}

validate_skill_sync_sources() {
  local name english_file korean_file english_name korean_name file
  local -a english_names korean_names

  command -v sha256sum >/dev/null 2>&1 || sync_fail 'required command not found: sha256sum'
  [[ -d "$sync_english_root" && ! -L "$sync_english_root" ]] ||
    sync_fail "missing or invalid English skill root: $sync_english_root"
  [[ -d "$sync_korean_root" && ! -L "$sync_korean_root" ]] ||
    sync_fail "missing or invalid Korean skill root: $sync_korean_root"

  collect_skill_names "$sync_english_root" english_names
  collect_skill_names "$sync_korean_root" korean_names
  ((${#english_names[@]} > 0)) || sync_fail 'no English skills found'

  if ((${#english_names[@]} != ${#korean_names[@]})); then
    sync_fail 'English and Korean skill inventories differ'
  fi
  for name in "${!english_names[@]}"; do
    [[ "${english_names[$name]}" == "${korean_names[$name]}" ]] ||
      sync_fail 'English and Korean skill inventories differ'
  done
  sync_skill_names=("${english_names[@]}")

  for name in "${sync_skill_names[@]}"; do
    english_file=$sync_english_root/$name/SKILL.md
    korean_file=$sync_korean_root/$name/SKILL.md
    [[ -f "$english_file" && ! -L "$english_file" ]] ||
      sync_fail "missing or invalid English SKILL.md: $english_file"
    [[ -f "$korean_file" && ! -L "$korean_file" ]] ||
      sync_fail "missing or invalid Korean SKILL.md: $korean_file"

    english_name=$(frontmatter_name "$english_file") ||
      sync_fail "invalid English frontmatter: $english_file"
    korean_name=$(frontmatter_name "$korean_file") ||
      sync_fail "invalid Korean frontmatter: $korean_file"
    [[ "$english_name" == "$name" ]] ||
      sync_fail "English frontmatter name does not match directory: $english_file"
    [[ "$korean_name" == "$name" ]] ||
      sync_fail "Korean frontmatter name does not match directory: $korean_file"

    LC_ALL=C.utf8 grep -qP '[\x{AC00}-\x{D7A3}]' "$korean_file" ||
      sync_fail "Korean source has no Hangul content: $korean_file"
  done

  while IFS= read -r -d '' file; do
    if LC_ALL=C grep -qP '[^\x00-\x7F]' "$file"; then
      sync_fail "installed skill content is not ASCII English: $file"
    fi
  done < <(find "$sync_english_root" -type f -print0)
}

write_current_skill_checksums() {
  local name

  (
    cd -- "$sync_repo_root"
    for name in "${sync_skill_names[@]}"; do
      sha256sum -- "skills-ko/$name/SKILL.md" "skills/$name/SKILL.md"
    done
  )
}

validate_paired_changes_from_recorded_state() {
  local hash path extra name current_korean_hash current_english_hash
  local korean_changed english_changed
  local -A recorded_korean=() recorded_english=() current_names=()

  [[ -f "$sync_state_path" && ! -L "$sync_state_path" ]] ||
    sync_fail "missing or invalid sync state: $sync_state_path"

  while read -r hash path extra; do
    [[ -z "${extra:-}" && "$hash" =~ ^[0-9a-f]{64}$ ]] ||
      sync_fail "invalid sync state entry: $sync_state_path"
    if [[ "$path" =~ ^skills-ko/([^/]+)/SKILL\.md$ ]]; then
      name=${BASH_REMATCH[1]}
      [[ -z "${recorded_korean[$name]+present}" ]] ||
        sync_fail "duplicate Korean sync state entry: $name"
      recorded_korean[$name]=$hash
    elif [[ "$path" =~ ^skills/([^/]+)/SKILL\.md$ ]]; then
      name=${BASH_REMATCH[1]}
      [[ -z "${recorded_english[$name]+present}" ]] ||
        sync_fail "duplicate English sync state entry: $name"
      recorded_english[$name]=$hash
    else
      sync_fail "unexpected path in sync state: $path"
    fi
  done <"$sync_state_path"

  ((${#recorded_korean[@]} > 0)) || sync_fail 'sync state contains no skill pairs'
  for name in "${!recorded_korean[@]}"; do
    [[ -n "${recorded_english[$name]+present}" ]] ||
      sync_fail "sync state is missing the English side: $name"
  done
  for name in "${!recorded_english[@]}"; do
    [[ -n "${recorded_korean[$name]+present}" ]] ||
      sync_fail "sync state is missing the Korean side: $name"
  done

  for name in "${sync_skill_names[@]}"; do
    current_names[$name]=true
    if [[ -z "${recorded_korean[$name]+present}" ]]; then
      continue
    fi
    current_korean_hash=$(sha256sum -- "$sync_korean_root/$name/SKILL.md")
    current_korean_hash=${current_korean_hash%% *}
    current_english_hash=$(sha256sum -- "$sync_english_root/$name/SKILL.md")
    current_english_hash=${current_english_hash%% *}
    korean_changed=false
    english_changed=false
    [[ "$current_korean_hash" == "${recorded_korean[$name]}" ]] || korean_changed=true
    [[ "$current_english_hash" == "${recorded_english[$name]}" ]] || english_changed=true
    [[ "$korean_changed" == "$english_changed" ]] ||
      sync_fail "only one side of the recorded skill pair changed: $name"
  done

  # Removing a skill is paired only when both current directories are absent. Source inventory
  # validation already guarantees that newly added skills exist on both sides.
  for name in "${!recorded_korean[@]}"; do
    if [[ -z "${current_names[$name]+present}" ]]; then
      [[ ! -e "$sync_korean_root/$name" && ! -e "$sync_english_root/$name" ]] ||
        sync_fail "only one side of the recorded skill pair was removed: $name"
    fi
  done
}
