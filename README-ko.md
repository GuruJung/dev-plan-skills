# Dev Plan Skills

[English](README.md)

Dev Plan Skills는 사용자와 함께 확정한 개발 계획을 구현·평가·독립 리뷰·통합까지
이어 주는 Codex 스킬 모음이다. 지속되는 기능 의도는 Git에 보존하고, 단기 구현 세부는
로컬 Git metadata에만 유지한다.

워크플로는 세 스킬을 제공한다.

- `$create-dev-plan`은 사용자를 인터뷰해 결정 완료 계획을 만든다.
- `$save-dev-plan`을 직접 호출하면 확정 계획을 구현하지 않고 저장한다.
- `$implement-dev-plan`은 저장된 계획을 구현·평가·리뷰·통합한다.

## 설치

저장소를 clone하고 세 스킬을 전역으로 설치한 뒤 설치 상태를 검사한다.

```bash
git clone https://github.com/GuruJung/dev-plan-skills.git
cd dev-plan-skills
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

설치 스크립트는 `skills/` 아래의 영문 스킬을 `~/.agents/skills/` 아래의 독립된
디렉터리로 복사한다. Codex가 설치된 스킬을 인식하지 못하면 새 세션을 시작한다.
저장소를 갱신하거나 이동한 뒤에는 설치 스크립트를 다시 실행한다.

## 빠른 시작

Codex를 Plan mode로 전환한 뒤 계획 스킬을 명시적으로 호출하면서 원하는 변경을 설명한다.
`$`는 스킬 이름의 일부이며, 아래 예시는 셸 명령이 아니라 Codex에 입력하는 프롬프트다.

```text
$create-dev-plan <describe the change>
```

중요한 질문에 답해 계획을 확정한 다음 호스트의 “Implement this plan” 동작을 선택한다.
호스트는 Default mode로 전환하고 같은 대화의 최신 확정 계획을 `$save-dev-plan`으로 저장한
뒤, 확정된 feature ID로 `$implement-dev-plan`을 추가 확인 없이 이어서 실행한다. 저장에
실패하거나 저장물이 계획과 일치하지 않으면 구현을 시작하지 않는다.

## 스킬 역할

| 스킬 | 호출 시점 | 결과 |
|---|---|---|
| `$create-dev-plan` | Plan mode에서 명시적으로 호출 | 저장소를 조사하고 사용자와 결정을 확정하며, 지속 기능 명세와 로컬 구현 계획을 분리한다. 계획 중에는 저장소를 변경하지 않는다. |
| `$save-dev-plan` | 계획을 저장만 하려면 Default mode에서 명시적으로 호출 | 최신 확정 계획을 Git 공용 metadata에 저장하고 feature ID를 알려 준다. 직접 호출만으로는 구현을 시작하지 않는다. |
| `$implement-dev-plan <feature-id>` | 저장된 계획을 구현하거나 재개하려면 Default mode에서 명시적으로 호출 | 격리된 feature worktree에서 명세 승격, 구현, 평가, 독립 리뷰를 수행하고 검증된 tree를 `main`에 단일 squash commit으로 통합한다. |

### 수동 저장과 구현

자동 handoff가 시작되지 않거나 구현 전에 계획만 저장하려면 Default mode로 전환해 다음을
호출한다.

```text
$save-dev-plan
$implement-dev-plan <feature-id>
```

첫 호출이 알려 준 `<feature-id>`를 두 번째 호출에 사용한다. 중단된 작업을 재개할 때도
같은 `$implement-dev-plan <feature-id>` 형식을 사용한다. 구현이 성공해도 자동으로
`push`하거나 feature branch 또는 worktree를 삭제하지 않는다.

## 워크플로 산출물

확정 계획은 `<git-common-dir>/dev-plan-workflow/plans/<id>/` 아래에 `spec.md`, `plan.md`,
`state.json`으로 원자적으로 저장된다. 구현을 시작하면 지속 기능 명세만
`docs/dev-plans/specs/<id>/spec.md`로 승격되어 commit된다. 로컬 구현 계획은 실행과 복구를
위해 Git metadata에 남고, 성공적인 통합 smoke 뒤에만 삭제된다.

`docs/dev-plans/current-spec.md`는 새 워크플로가 도입하거나 바꾼 현재 의도를 정규화한다.
과거 spec의 합본이나 연대기가 아니다. source code와 tests는 동작의 source of truth이고,
current spec은 명시된 coverage 안에서 의도의 기준이다. 현재 의도를 보존하는 순수 refactor는
feature spec만 추가한다. current spec의 의미가 바뀌면 문서 전체의 서술 언어를 feature
spec의 주된 서술 언어에 맞춘다. `No change`이면 번역하지 않는다.

## 업데이트·제거·복원

### 업데이트

원하는 저장소 revision을 받은 뒤 설치와 검사를 다시 실행한다.

```bash
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

### 제거

```bash
scripts/uninstall-global-skills.sh
```

제거 스크립트는 현재 설치본을 백업하고 관리 대상 세 스킬을 함께 제거한다. 설치된 스킬이
하나도 없으면 변경 없이 성공하며, 다른 이름의 항목은 건드리지 않는다.

### 백업 복원

설치와 제거 백업은 `~/.agents/skill-backups/dev-plan-workflow/` 아래에 워크플로 전체
단위로 저장된다. 수동으로 복원하기 전에 모든 관리 대상 경로가 없는지 확인한다.

```bash
test ! -e "$HOME/.agents/skills/create-dev-plan"
test ! -e "$HOME/.agents/skills/save-dev-plan"
test ! -e "$HOME/.agents/skills/implement-dev-plan"
```

복원할 `<backup-set>`을 선택하고 존재하는 각 스킬을 복사한 뒤 백업과 일치하는지 확인한다.

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

복원한 스킬을 Codex가 인식하지 못하면 새 세션을 시작한다. 복원본이 현재 저장소보다 오래된
버전이면 다음 설치 때 다시 백업된 뒤 현재 저장소 버전으로 교체된다.

## 유지보수자 안내

### README 번역 동기화

`README.md`는 영문, `README-ko.md`는 한글이며 의미와 강도, 구조, 명령, 경로, 식별자와
제약이 같다. 어느 언어도 고정 편집 원본은 아니다.

의도한 원본을 수정한 뒤 대응본을 번역하기 전에 두 파일의 Git 상태와 파일시스템 mtime을
스냅샷한다. 정상 원본 후보는 정확히 ` M`, `M `, `MM` 상태다. 한쪽만 후보이면 그 파일을
원본으로 삼고, 양쪽 모두 후보이면 스냅샷한 mtime이 더 최신인 파일을 원본으로 삼는다.
깨끗한 쌍은 원본을 선정하지 않는다. mtime이 같거나 어느 파일에 `A`, `D`, `R`, `U`,
untracked 또는 다른 `M` 이외의 변경이 있으면 중단하고 사용자의 명시적 선택을 받는다.

동기화가 끝날 때까지 원본 선정을 고정한다. 이후 예상 밖 변경이 생기면 덮어쓰지 않고
중단한다. 대응본을 번역하고 전체 문서를 대조한 뒤 다음을 실행한다.

```bash
tests/test-readme-sync.sh
```

테스트는 구조, 언어 경계, 링크, 명령과 핵심 계약을 검사하지만 필수 의미 번역 리뷰를
대신하지 않는다.

### 스킬 번역 편집과 동기화

`skills-ko/<skill>/SKILL.md`와 `skills/<skill>/SKILL.md`는 의미와 강도가 같은 한글·영문
대응본이며 어느 언어도 고정 편집 원본은 아니다. 기존 tracked 쌍의 행동을 바꾸기 전에
Git 상태와 파일시스템 mtime을 스냅샷한다.

```bash
git status --short -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
stat -c '%y %n' -- skills-ko/<skill>/SKILL.md skills/<skill>/SKILL.md
```

정상 원본 후보는 정확히 ` M`, `M `, `MM` 상태다. 한쪽만 후보이면 그 파일을 원본으로
삼고, 양쪽 모두 후보이면 더 최신인 스냅샷 mtime의 파일을 원본으로 삼는다. 깨끗한 쌍은
동기화하지 않는다. mtime이 같거나 `A`, `D`, `R`, `U`, untracked 또는 다른 `M` 이외의
변경이 있으면 사용자의 명시적 선택을 받는다.

선정한 원본은 동기화가 끝날 때까지 고정하고 예상 밖 변경을 덮어쓰지 않는다. 선정한 원본이
한글이면 대응본을 영문으로, 영문이면 대응본을 한글로 의미와 강도가 같도록 번역한다. 명령,
경로, 식별자, enum 값, YAML 또는 JSON 키는 원형을 유지한다. `skills/`에서 설치되는 파일에는
영어 ASCII 텍스트만 포함하며 한글 대응본이나 개발용 파일을 복사하지 않는다.
`agents/openai.yaml`과 실행 스크립트는 한글 대응본 없이 영문으로 직접 관리한다.

두 문서를 대조한 뒤 동기화 상태를 기록하고 검사한다.

```bash
scripts/record-skill-sync.sh
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
```

기록 명령은 번역하거나 원본을 선정하지 않는다. 언어 경계와 paired change를 검증한 뒤
현재 체크섬을 원자적으로 기록한다. 한쪽만 바뀐 상태를 거부하고 tracked 체크섬 상태가
Git `HEAD`와 같아야 한다. `skills-ko/.sync-state.sha256`을 직접 편집하거나 삭제하지 않는다.
상태가 없거나 수정·손상됐으면 현재 내용으로 재기준화하지 말고 Git에서 복구한다. 의미
동등성은 구현 검토와 독립 리뷰에서 검증한다.

### 설치 안전 세부사항

설치본 하나라도 원본과 다르면 설치 스크립트는 세 스킬 전체를 staging하고 검증한 뒤
설치본 전체를 백업하고 원자적으로 교체한다. 실패하면 설치 전 상태로 되돌린다. 설치와
제거는 같은 배타 잠금을 사용한다.

관리 대상 이름은 `create-dev-plan`, `save-dev-plan`, `implement-dev-plan`뿐이다. 다른
이름은 무시한다. 관리 이름의 symbolic link는 따라가거나 교체하지 않고 안전하게 실패한다.
워크플로 전체 단위의 최근 백업 5세트만 유지한다.

격리 검증에는 `DEV_PLAN_WORKFLOW_TARGET_ROOT`와 `DEV_PLAN_WORKFLOW_BACKUP_ROOT`를 함께
설정한다. 제거된 `FEATURE_WORKFLOW_*`, `~/.agents/skill-backups/feature-workflow/`,
`.feature-workflow-*` namespace는 지원하지 않는다. 이전 환경변수가 설정돼 있으면 기본
전역 경로로 조용히 fallback하지 않고 실패한다.

### 스킬 개선

다른 프로젝트에서 문제를 발견해도 전역 설치본을 직접 수정하지 않는다.

1. 소비 프로젝트의 작업을 안전한 checkpoint에 보존한다.
2. 스킬 이름, 이 저장소의 Git commit, 호출, 기대·실제 동작, 최소 재현, 관련 출력과 diff,
   작업 차단 여부를 포함한 보고서를 준비한다.
3. 이 저장소에서 새 Codex 세션을 열고 보고서를 전달한다.
4. `$create-dev-plan`, `$save-dev-plan`, `$implement-dev-plan`으로 행동 변경을 계획·구현한다.
5. feature worktree의 후보 스킬을 최소 재현과 독립된 새 세션으로 검증한다. 후보 테스트를
   위해 전역 설치본을 바꾸지 않는다.
6. 검증된 feature tree를 단일 squash commit으로 `main`에 통합하고 소비 프로젝트에서 실패
   단계를 다시 실행한다.

canonical 작업 디렉터리는 깨끗한 `main`으로 유지한다. 스킬 변경은 feature worktree에서
수행하고 Git commit hash를 설치본의 버전 식별자로 사용한다. 통합된 변경을 인식하지 못하면
새 세션을 시작하거나 기존 세션을 resume한다.
