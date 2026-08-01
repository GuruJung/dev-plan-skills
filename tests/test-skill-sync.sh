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
  git -C "$case_root" init -q
  git -C "$case_root" config user.name 'Skill Sync Test'
  git -C "$case_root" config user.email 'skill-sync-test@example.invalid'
  git -C "$case_root" add .
  git -C "$case_root" commit -qm 'Record synchronization baseline'
}

expect_failure() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description"
  fi
}

assert_contains() {
  local file=$1 expected=$2
  grep -Fq -- "$expected" "$file" || fail "missing expected text in $file: $expected"
}

assert_absent() {
  local root=$1 unexpected=$2
  if grep -RFq -- "$unexpected" "$root"; then
    fail "unexpected legacy text under $root: $unexpected"
  fi
}

# Planning and execution agree on the five-minute default in both authoring languages.
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  '기본값이 300초인 smoke 기준 시간'
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  'smoke_threshold_seconds: 300'
assert_contains "$repo_root/skills-ko/run-feature/SKILL.md" \
  '계획의 threshold, 기본 300초를 사용하세요.'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'smoke threshold, defaulting to 300 seconds;'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'smoke_threshold_seconds: 300'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'plan threshold, default 300 seconds:'
assert_absent "$repo_root/skills" 'smoke_threshold_seconds: 60'
assert_absent "$repo_root/skills" 'default 60 seconds'
assert_absent "$repo_root/skills" 'defaulting to 60 seconds'
assert_absent "$repo_root/skills-ko" 'smoke_threshold_seconds: 60'
assert_absent "$repo_root/skills-ko" '기본값이 60초'
assert_absent "$repo_root/skills-ko" '기본 60초'

# Independent review uses a complete embedded contract without an optional skill dependency.
assert_absent "$repo_root/skills-ko/run-feature" '$review-agent'
assert_absent "$repo_root/skills/run-feature" '$review-agent'
assert_contains "$repo_root/skills-ko/run-feature/SKILL.md" \
  '첫 문제를 찾은 뒤에도 전체 diff를 끝까지 확인하세요.'
assert_contains "$repo_root/skills-ko/run-feature/SKILL.md" \
  '검토 대상 변경으로 인해 새로 발생했습니다.'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'continue through the whole diff after finding'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'the reviewed change introduced it;'

# A valid repository can record and verify a complete synchronization state.
make_case valid
"$case_root/scripts/record-skill-sync.sh" >/dev/null
"$case_root/scripts/check-skill-sync.sh" >/dev/null

# A change to either side makes the recorded pair stale.
make_case stale-korean
cp -- "$case_root/skills-ko/.sync-state.sha256" "$case_root/state-before"
printf '\n한글 원본 변경\n' >>"$case_root/skills-ko/plan-feature/SKILL.md"
expect_failure 'checker accepted a one-sided Korean change' \
  "$case_root/scripts/check-skill-sync.sh"
expect_failure 'recorder accepted a one-sided Korean change' \
  "$case_root/scripts/record-skill-sync.sh"
cmp -s -- "$case_root/state-before" "$case_root/skills-ko/.sync-state.sha256" ||
  fail 'one-sided Korean record changed the synchronization state'

make_case stale-english
cp -- "$case_root/skills-ko/.sync-state.sha256" "$case_root/state-before"
printf '\nEnglish installed change\n' >>"$case_root/skills/plan-feature/SKILL.md"
expect_failure 'checker accepted a one-sided English change' \
  "$case_root/scripts/check-skill-sync.sh"
expect_failure 'recorder accepted a one-sided English change' \
  "$case_root/scripts/record-skill-sync.sh"
cmp -s -- "$case_root/state-before" "$case_root/skills-ko/.sync-state.sha256" ||
  fail 'one-sided English record changed the synchronization state'

# A modified state file cannot make a one-sided source change look paired.
make_case modified-state
printf -v invalid_hash '%064d' 0
sed -i "1s/^[0-9a-f]\{64\}/$invalid_hash/" \
  "$case_root/skills-ko/.sync-state.sha256"
printf '\n한글 원본 변경\n' >>"$case_root/skills-ko/plan-feature/SKILL.md"
cp -- "$case_root/skills-ko/.sync-state.sha256" "$case_root/state-before"
expect_failure 'recorder trusted synchronization state that differs from HEAD' \
  "$case_root/scripts/record-skill-sync.sh"
cmp -s -- "$case_root/state-before" "$case_root/skills-ko/.sync-state.sha256" ||
  fail 'record overwrote synchronization state that differs from HEAD'

# A paired change can be recorded and then passes verification.
make_case paired-change
printf '\n한글 동기화 변경\n' >>"$case_root/skills-ko/plan-feature/SKILL.md"
printf '\nSynchronized English change\n' >>"$case_root/skills/plan-feature/SKILL.md"
"$case_root/scripts/record-skill-sync.sh" >/dev/null
"$case_root/scripts/check-skill-sync.sh" >/dev/null

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

# Missing state cannot be recreated from unverified current content.
make_case missing-state
rm -- "$case_root/skills-ko/.sync-state.sha256"
expect_failure 'recorder accepted missing synchronization state' \
  "$case_root/scripts/record-skill-sync.sh"
expect_failure 'recorder accepted an unsupported initialization flag' \
  "$case_root/scripts/record-skill-sync.sh" --initialize
expect_failure 'checker accepted missing synchronization state' \
  "$case_root/scripts/check-skill-sync.sh"

printf 'All skill synchronization tests passed.\n'
