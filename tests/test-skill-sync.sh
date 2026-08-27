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

assert_path_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected legacy path: $1"
}

# Planning infers a clear feature type and only asks between the two supported types when unclear.
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  '유형이 명확하면 `standard` 또는 `goal-loop`를 직접 선택하고'
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  '조사 후에도 유형이 불명확할 때만 `standard`와 `goal-loop` 중 하나를 반드시 선택하게 하세요.'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'When the type is clear, select `standard` or `goal-loop` directly'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'Only when the type remains unclear after exploration, require the user to choose between `standard`'
assert_absent "$repo_root/skills-ko/plan-feature" '`other`'
assert_absent "$repo_root/skills/plan-feature" '`other`'

# Planning and execution agree on the one-minute automatic smoke policy.
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  '기본값이 60초인 자동 smoke 기준 시간'
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  'smoke_threshold_seconds: 60'
assert_contains "$repo_root/skills-ko/run-feature/SKILL.md" \
  '계획의 threshold, 기본 60초를 사용하세요.'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'automatic smoke threshold, defaulting to 60 seconds;'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'smoke_threshold_seconds: 60'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'plan threshold, default 60 seconds.'
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  '별도의 eval별 smoke 선택을 묻거나 기록하지 마세요.'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'Ignore legacy per-eval smoke-selection fields'
assert_absent "$repo_root/skills" 'smoke_threshold_seconds: 300'
assert_absent "$repo_root/skills" 'default 300 seconds'
assert_absent "$repo_root/skills" 'defaulting to 300 seconds'
assert_absent "$repo_root/skills-ko" 'smoke_threshold_seconds: 300'
assert_absent "$repo_root/skills-ko" '기본값이 300초'
assert_absent "$repo_root/skills-ko" '기본 300초'

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

# Plan handoff saves only; running remains an explicit and separate action.
assert_path_absent "$repo_root/skills-ko/plan-run-feature"
assert_path_absent "$repo_root/skills/plan-run-feature"
assert_contains "$repo_root/skills-ko/plan-feature/SKILL.md" \
  'skill: save-approved-plan'
assert_contains "$repo_root/skills/plan-feature/SKILL.md" \
  'continuation: save-only'
assert_contains "$repo_root/skills-ko/save-approved-plan/SKILL.md" \
  '명시 호출과 handoff 호출 모두 저장 전용입니다.'
assert_contains "$repo_root/skills/save-approved-plan/SKILL.md" \
  'Do not invoke `$run-feature` or start branch creation'
assert_contains "$repo_root/skills-ko/run-feature/SKILL.md" \
  '`$run-feature [<feature-id>]`를 명시적으로 호출한 경우에만 실행하세요.'
assert_contains "$repo_root/skills/run-feature/SKILL.md" \
  'Run only after an explicit `$run-feature [<feature-id>]` invocation.'
assert_contains "$repo_root/skills-ko/save-approved-plan/SKILL.md" \
  'goal objective의 저장 계획 경로를 포함해 feature ID를 나타내는 모든 필드와 경로'
assert_contains "$repo_root/skills/save-approved-plan/SKILL.md" \
  'every feature-ID-bearing field and path, including'
assert_contains "$repo_root/skills/save-approved-plan/agents/openai.yaml" \
  'allow_implicit_invocation: true'
for skill in plan-feature run-feature; do
  assert_contains "$repo_root/skills/$skill/agents/openai.yaml" \
    'allow_implicit_invocation: false'
done
assert_absent "$repo_root/skills-ko/plan-feature" '$plan-run-feature'
assert_absent "$repo_root/skills/plan-feature" '$plan-run-feature'
assert_absent "$repo_root/skills-ko/save-approved-plan" '$plan-run-feature'
assert_absent "$repo_root/skills/save-approved-plan" '$plan-run-feature'
assert_absent "$repo_root/skills-ko/run-feature" '$plan-run-feature'
assert_absent "$repo_root/skills/run-feature" '$plan-run-feature'

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
