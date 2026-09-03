# Dev Plan Skills

사용자와 함께 계획을 확정한 뒤 구현·평가·독립 리뷰·통합을 수행하는 Codex 스킬
모음이다. `skills-ko/`와 `skills/`의 `SKILL.md`는 의미와 강도가 같은 한글·영문
대응본이며, `skills/` 쪽이 전역으로 설치된다. 어느 언어도 고정 편집 원본은 아니다.
`$create-dev-plan`은 명시적으로 호출한다. `$save-dev-plan`은 명시적으로 호출하거나,
확정 계획에서 "Implement this plan"을 선택한 같은 대화의 handoff로 활성화한다.
직접 호출한 `$save-dev-plan`은 저장만 하고, handoff 호출은 저장 성공 후 확정 ID로
`$implement-dev-plan`까지 추가 확인 없이 이어진다. `$implement-dev-plan <id>`의 직접
호출도 계속 지원한다.

확정 결과는 `<git-common-dir>/dev-plan-workflow/plans/<id>/`의 `spec.md`, `plan.md`,
`state.json`에 원자적으로 임시 저장된다. 구현을 시작하면 지속 의도인 feature spec만
`docs/dev-plans/specs/<id>/spec.md`로 승격되어 spec 전용 commit에 포함된다. 구현 세부인
local plan은 Git metadata에 남아 실행과 재개에 사용되고 통합 smoke 성공 뒤 삭제된다.

`docs/dev-plans/current-spec.md`는 새 workflow로 추가되거나 바뀐 현재 의도를 정규화해
보관한다. 과거 spec의 합본이나 연대기가 아니며, 순수 refactor처럼 현재 의도가 변하지
않으면 feature spec만 추가하고 current spec은 수정하지 않는다. 코드와 테스트는 실제
동작의 source of truth이고, current spec은 명시된 coverage 안에서 현재 intent의 기준이다.
current spec에 의미 변경을 적용할 때는 기존 내용을 포함한 문서 전체의 서술 언어를 해당
feature spec의 주된 서술 언어와 맞춘다. `No change`에서는 언어 차이만으로 수정하지 않는다.

## 스킬 작성 언어와 동기화

기존 tracked 스킬 쌍의 행동을 수정할 때는 번역 전에 두 대응 파일의 Git 상태와
파일시스템 mtime을 한 번 스냅샷한다.

```bash
git status --short -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
stat -c '%y %n' -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
```

정상 수정 후보는 정확히 ` M`, `M `, `MM` 상태인 파일이다. 한쪽만 후보이면 그 파일을
원본으로 선정하고, 양쪽 모두 후보이면 스냅샷한 mtime이 더 최신인 파일을 원본으로
선정한다. 깨끗한 쌍은 동기화 대상이 아니다. mtime이 같거나 `A`, `D`, `R`, `U`,
untracked 등 `M` 이외의 변경이 있으면 임의의 언어를 우선하지 않고 중단하여 사용자의
명시적 선택을 받는다.

선정 결과는 해당 동기화 작업이 끝날 때까지 유지한다. 대응본을 저장해서 mtime이나 Git
상태가 달라져도 원본을 다시 선정하지 않는다. 원본 파일이나 관련 상태에 예상 밖 변경이
생기면 덮어쓰지 않고 중단한다.

선정한 원본이 한글이면 `skills/<skill>/SKILL.md`를 영어로, 영문이면
`skills-ko/<skill>/SKILL.md`를 한글로 의미와 강도가 같도록 갱신한다. 명령, 경로,
식별자, enum 값, YAML/JSON 키는 번역하지 않는다. `agents/openai.yaml`과 실행 스크립트는
대응 한글 파일을 두지 않고 영어로 직접 관리한다.

Codex가 문맥에 맞게 번역한 두 파일을 대조한 뒤 동기화 상태를 기록하고 검사한다.

```bash
scripts/record-skill-sync.sh
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
```

기록 명령은 번역이나 원본 선정을 수행하지 않으며, 파일 쌍과 언어 경계를 검증한 뒤
현재 체크섬만 원자적으로 저장한다. 기존 기록과 비교했을 때 한쪽 파일만 바뀌었으면
기록을 거부한다.
기록 전에는 체크섬 파일이 Git `HEAD`에 추적된 내용과 같은지도 확인한다. 동기화 상태가
없거나 수정·손상됐을 때 현재 내용으로 재기준화하지 않으며 Git에서 정상 상태를 복구해야
한다. 의미 일치는 구현 검토와 독립 리뷰에서 확인한다. 설치 스크립트는 계속 `skills/`만
복사하므로 한글 대응본과 개발 지침은 전역 설치에 포함되지 않는다.

## 전역 설치

```bash
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

설치 스크립트는 `skills/` 아래의 세 스킬을 `~/.agents/skills/`에 독립된 디렉터리로
복사한다. 설치본 하나라도 원본과 다르면 세 스킬을 함께 staging하고 검증한 뒤 기존
설치본 전체를 백업하고 교체한다. 중간에 실패하면 관리 대상 전체를 설치 전 상태로
되돌린다. 설치와 제거는 같은 배타 잠금을 사용하므로 동시에 실행해도 순서대로 처리된다.
저장소를 수정하거나 이동한 뒤에는 설치 스크립트를 다시 실행해야 한다.

설치와 제거는 현재 세 스킬 이름만 관리하며 다른 이름의 디렉터리, 파일, symbolic link는
검사하거나 변경하지 않는다. 현재 관리 이름에 symbolic link가 있으면 대상을 따라가거나
교체하지 않고 오류로 중단한다.

설치·제거 백업은
`~/.agents/skill-backups/dev-plan-workflow/`에 워크플로 전체 단위로 저장하며, 관리되는
최근 5세트만 유지한다. 격리된 검증에는 `DEV_PLAN_WORKFLOW_TARGET_ROOT`와
`DEV_PLAN_WORKFLOW_BACKUP_ROOT` 환경 변수를 함께 지정할 수 있다. 이전
`FEATURE_WORKFLOW_*`, `~/.agents/skill-backups/feature-workflow/`, `.feature-workflow-*`
namespace는 지원하지 않는다. 이전 환경변수가 설정되어 있으면 기본 전역 경로로 조용히
fallback하지 않고 오류로 중단한다.

## 제거와 복원

```bash
scripts/uninstall-global-skills.sh
```

제거 스크립트는 현재 설치본을 백업한 뒤 세 스킬을 함께 제거한다. 이미 설치되어 있지
않으면 변경 없이 성공한다. 다른 이름의 항목은 그대로 둔다.

백업을 수동으로 복원하려면 먼저 아래 대상이 모두 없는지 확인한다.

```bash
test ! -e "$HOME/.agents/skills/create-dev-plan"
test ! -e "$HOME/.agents/skills/save-dev-plan"
test ! -e "$HOME/.agents/skills/implement-dev-plan"
```

복원할 `<backup-set>`을 선택하고 그 안의 스킬 디렉터리를 복사한 뒤 백업과 일치하는지
확인한다.

```bash
for skill in create-dev-plan save-dev-plan implement-dev-plan; do
  if test -d "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill"; then
    cp -a "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill" \
      "$HOME/.agents/skills/$skill"
    diff -qr "$HOME/.agents/skill-backups/dev-plan-workflow/<backup-set>/$skill" \
      "$HOME/.agents/skills/$skill"
  fi
done
```

Codex가 복원된 스킬을 자동으로 인식하지 못하면 세션을 새로 연다. 복원본이 현재
저장소보다 오래된 버전이면 다음 설치 때 다시 백업된 후 최신 버전으로 교체된다.

## 스킬 개선

다른 프로젝트에서 문제를 발견하더라도 해당 프로젝트의 세션에서 전역 설치본을 직접
수정하지 않는다.

1. 소비 프로젝트의 작업을 안전한 체크포인트에 보존한다.
2. 스킬 이름과 이 저장소의 Git 커밋, 호출 명령, 기대·실제 동작, 최소 재현 절차,
   관련 출력과 diff, 작업 차단 여부를 포함한 개선 보고서를 만든다.
3. 이 저장소에서 새 Codex 세션을 열고 보고서를 전달한다.
4. 행동 변경은 `$create-dev-plan`, `$save-dev-plan`, `$implement-dev-plan`으로 계획·구현한다.
5. feature worktree의 후보 스킬을 최소 재현과 독립된 새 세션으로 검증한다. 전역
   설치본은 후보를 시험하기 위해 변경하지 않는다.
6. 검증된 변경은 feature tree 전체를 담는 단일 squash commit으로 `main`에 통합하고
   소비 프로젝트에서 실패 단계를 다시 실행한다.

canonical 작업 디렉터리는 깨끗한 `main`으로 유지한다. 스킬 변경은 feature worktree에서
수행하며, Git 커밋 해시를 설치본의 버전 식별자로 사용한다. 활성 세션이 병합된 변경을
인식하지 못하면 해당 세션을 새로 열거나 resume한다.
