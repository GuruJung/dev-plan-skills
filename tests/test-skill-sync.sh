#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/feature workflow skill sync tests.XXXXXX")

cleanup() {
  case $test_root in
    "${TMPDIR:-/tmp}"/'feature workflow skill sync tests.'*) rm -rf -- "$test_root" ;;
    *) printf 'Refusing unsafe test cleanup: %s\n' "$test_root" >&2 ;;
  esac
}
trap cleanup EXIT

make_case() {
  local name=$1
  case_root=$test_root/$name
  mkdir -p -- "$case_root/scripts"
  cp -a -- "$repo_root/skills" "$repo_root/skills-ko" "$case_root/"
  cp -a -- \
    "$repo_root/scripts/skill-sync-common.sh" \
    "$repo_root/scripts/check-skill-sync.sh" \
    "$repo_root/scripts/record-skill-sync.sh" \
    "$case_root/scripts/"
}

expect_failure() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description"
  fi
}

# A valid repository can record and verify a complete synchronization state.
make_case valid
"$case_root/scripts/record-skill-sync.sh" >/dev/null
"$case_root/scripts/check-skill-sync.sh" >/dev/null

# A change to either side makes the recorded pair stale.
make_case stale-korean
printf '\n한글 원본 변경\n' >>"$case_root/skills-ko/plan-feature/SKILL.md"
expect_failure 'checker accepted a one-sided Korean change' \
  "$case_root/scripts/check-skill-sync.sh"

make_case stale-english
printf '\nEnglish installed change\n' >>"$case_root/skills/plan-feature/SKILL.md"
expect_failure 'checker accepted a one-sided English change' \
  "$case_root/scripts/check-skill-sync.sh"

# Missing and additional counterparts are rejected before checksums are recorded.
make_case missing-counterpart
rm -- "$case_root/skills-ko/run-feature/SKILL.md"
expect_failure 'recorder accepted a missing Korean SKILL.md' \
  "$case_root/scripts/record-skill-sync.sh"

make_case extra-counterpart
mkdir -p -- "$case_root/skills-ko/extra-skill"
cp -- "$case_root/skills-ko/plan-feature/SKILL.md" \
  "$case_root/skills-ko/extra-skill/SKILL.md"
expect_failure 'recorder accepted an additional Korean skill' \
  "$case_root/scripts/record-skill-sync.sh"

# Directory names and frontmatter names must remain identical.
make_case mismatched-name
sed -i 's/^name: plan-feature$/name: renamed-feature/' \
  "$case_root/skills-ko/plan-feature/SKILL.md"
expect_failure 'recorder accepted a mismatched Korean frontmatter name' \
  "$case_root/scripts/record-skill-sync.sh"

# The English installation tree cannot contain non-ASCII text, and a failed record is non-mutating.
make_case non-ascii-english
cp -- "$case_root/skills-ko/.sync-state.sha256" "$case_root/state-before"
printf '\n한글 유입\n' >>"$case_root/skills/save-approved-plan/SKILL.md"
expect_failure 'recorder accepted non-ASCII installed content' \
  "$case_root/scripts/record-skill-sync.sh"
cmp -s -- "$case_root/state-before" "$case_root/skills-ko/.sync-state.sha256" ||
  fail 'failed record changed the synchronization state'

# Every Korean source must contain actual Hangul prose.
make_case english-only-korean-source
cp -- "$case_root/skills/plan-feature/SKILL.md" \
  "$case_root/skills-ko/plan-feature/SKILL.md"
expect_failure 'recorder accepted an English-only Korean source' \
  "$case_root/scripts/record-skill-sync.sh"

printf 'All skill synchronization tests passed.\n'
