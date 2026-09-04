#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
english_readme=$repo_root/README.md
korean_readme=$repo_root/README-ko.md
agents_file=$repo_root/AGENTS.md

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file=$1 expected=$2
  grep -Fq -- "$expected" "$file" || fail "missing text in $file: $expected"
}

assert_order() {
  local file=$1 marker line previous=0
  shift
  for marker in "$@"; do
    line=$(grep -nF -m1 -- "$marker" "$file" | cut -d: -f1) ||
      fail "missing ordered section in $file: $marker"
    ((line > previous)) || fail "section is out of order in $file: $marker"
    previous=$line
  done
}

[[ -f "$english_readme" && ! -L "$english_readme" ]] ||
  fail "missing or invalid English README: $english_readme"
[[ -f "$korean_readme" && ! -L "$korean_readme" ]] ||
  fail "missing or invalid Korean README: $korean_readme"

if LC_ALL=C.utf8 grep -qP '[\x{AC00}-\x{D7A3}]' "$english_readme"; then
  fail 'English README contains Hangul text'
fi
LC_ALL=C.utf8 grep -qP '[\x{AC00}-\x{D7A3}]' "$korean_readme" ||
  fail 'Korean README contains no Hangul text'
if LC_ALL=C.utf8 grep -qP '[\x{AC00}-\x{D7A3}]' "$agents_file"; then
  fail 'AGENTS.md contains Hangul text'
fi

assert_contains "$english_readme" '[Korean](README-ko.md)'
assert_contains "$korean_readme" '[English](README.md)'
assert_contains "$agents_file" '`README.md` is the English document and `README-ko.md` is its Korean counterpart.'
assert_contains "$agents_file" 'Neither language is a fixed source.'
assert_contains "$agents_file" 'after modifying the intended source and before translating the counterpart'
assert_contains "$agents_file" 'then pass `tests/test-readme-sync.sh`.'

assert_order "$english_readme" \
  '## Installation' \
  '## Quick start' \
  '## Skill reference' \
  '## Workflow artifacts' \
  '## Updating, uninstalling, and restoring' \
  '## Maintainer guide'
assert_order "$korean_readme" \
  '## 설치' \
  '## 빠른 시작' \
  '## 스킬 역할' \
  '## 워크플로 산출물' \
  '## 업데이트·제거·복원' \
  '## 유지보수자 안내'

for marker in \
  'scripts/install-global-skills.sh' \
  'scripts/install-global-skills.sh --check' \
  'scripts/uninstall-global-skills.sh' \
  '$create-dev-plan' \
  '$save-dev-plan' \
  '$implement-dev-plan <feature-id>' \
  'Plan mode' \
  'Default mode' \
  'Implement this plan' \
  '<git-common-dir>/dev-plan-workflow/plans/<id>/' \
  'docs/dev-plans/specs/<id>/spec.md' \
  'tests/test-readme-sync.sh'; do
  assert_contains "$english_readme" "$marker"
  assert_contains "$korean_readme" "$marker"
done

assert_contains "$english_readme" 'A direct invocation does not start implementation.'
assert_contains "$korean_readme" '직접 호출만으로는 구현을 시작하지 않는다.'
assert_contains "$english_readme" 'does not automatically `push` or delete the feature branch or worktree.'
assert_contains "$korean_readme" '자동으로'
assert_contains "$korean_readme" '`push`하거나 feature branch 또는 worktree를 삭제하지 않는다.'
assert_order "$english_readme" \
  "saves the same conversation's" \
  'and then continues with `$implement-dev-plan`'
assert_contains "$english_readme" 'Implementation does not start when saving'
assert_contains "$english_readme" 'fails or the saved artifacts do not match the plan.'
assert_order "$korean_readme" \
  '같은 대화의 최신 확정 계획을 `$save-dev-plan`으로 저장한' \
  'feature ID로 `$implement-dev-plan`을 추가 확인 없이 이어서 실행한다.'
assert_contains "$korean_readme" '실패하거나 저장물이 계획과 일치하지 않으면 구현을 시작하지 않는다.'

english_blocks=$(mktemp "${TMPDIR:-/tmp}/readme-english-blocks.XXXXXX")
korean_blocks=$(mktemp "${TMPDIR:-/tmp}/readme-korean-blocks.XXXXXX")
cleanup() {
  rm -f -- "$english_blocks" "$korean_blocks"
}
trap cleanup EXIT

extract_fenced_blocks() {
  awk '
    /^```/ {
      inside = !inside
      print
      next
    }
    inside { print }
    END { if (inside) exit 2 }
  ' "$1"
}

extract_fenced_blocks "$english_readme" >"$english_blocks"
extract_fenced_blocks "$korean_readme" >"$korean_blocks"
cmp -s -- "$english_blocks" "$korean_blocks" ||
  fail 'English and Korean README code blocks differ'

english_level_two=$(grep -c '^## ' "$english_readme")
korean_level_two=$(grep -c '^## ' "$korean_readme")
[[ "$english_level_two" == "$korean_level_two" ]] ||
  fail 'English and Korean README top-level section counts differ'

printf 'All bilingual README synchronization tests passed.\n'
