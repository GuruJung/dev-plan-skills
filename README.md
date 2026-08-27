# Feature Workflow Skills

사용자와 함께 계획을 확정한 뒤 구현·평가·독립 리뷰·통합을 수행하는 Codex 스킬
모음이다. `skills-ko/`의 `SKILL.md`가 편집 기준인 한글 원본이고, `skills/`는 전역으로
설치되는 영문 대응본이다. `$plan-feature`와 `$run-feature`는 명시적으로 호출한다.
`$save-approved-plan`은 명시적으로 호출하거나, 확정 계획에서 "Implement this plan"을
선택한 같은 대화의 save-only handoff로 활성화한다. 저장 후 구현은 시작하지 않으며
`$run-feature <id>`를 사용자가 별도로 호출한다.

## 스킬 작성 언어와 동기화

스킬의 행동을 수정할 때는 먼저 `skills-ko/<skill>/SKILL.md`에 의도를 한국어로
반영하고, 같은 변경에서 `skills/<skill>/SKILL.md`를 의미가 같도록 영어로 갱신한다.
명령, 경로, 식별자, enum 값, YAML/JSON 키는 번역하지 않는다. `agents/openai.yaml`과
실행 스크립트는 대응 한글 파일을 두지 않고 영어로 직접 관리한다.

Codex가 문맥에 맞게 번역한 두 파일을 대조한 뒤 동기화 상태를 기록하고 검사한다.

```bash
scripts/record-skill-sync.sh
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
```

기록 명령은 번역을 수행하지 않으며, 파일 쌍과 언어 경계를 검증한 뒤 현재 체크섬만
원자적으로 저장한다. 기존 기록과 비교했을 때 한쪽 파일만 바뀌었으면 기록을 거부한다.
기록 전에는 체크섬 파일이 Git `HEAD`에 추적된 내용과 같은지도 확인한다. 동기화 상태가
없거나 수정·손상됐을 때 현재 내용으로 재기준화하지 않으며 Git에서 정상 상태를 복구해야
한다. 의미 일치는 구현 검토와 독립 리뷰에서 확인한다. 설치 스크립트는 계속 `skills/`만
복사하므로 한글 원본과 개발 지침은 전역 설치에 포함되지 않는다.

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

이전 버전의 독립 디렉터리형 `plan-run-feature` 설치본은 다음 설치 또는 제거 때 retired
대상으로 백업한 뒤 제거한다. 실패 시에는 활성 세 스킬과 함께 원래 상태로 복원한다.

이 저장소를 가리키는 이전 방식의 심볼릭 링크는 최초 설치 때 실제 콘텐츠가 백업되고
일반 디렉터리 설치본으로 전환된다. 다른 링크나 일반 파일은 덮어쓰지 않는다.

설치·마이그레이션·제거 백업은
`~/.agents/skill-backups/feature-workflow/`에 워크플로 전체 단위로 저장하며, 관리되는
최근 5세트만 유지한다. 격리된 검증에는 `FEATURE_WORKFLOW_TARGET_ROOT`와
`FEATURE_WORKFLOW_BACKUP_ROOT` 환경 변수를 함께 지정할 수 있다.

## 제거와 복원

```bash
scripts/uninstall-global-skills.sh
```

제거 스크립트는 현재 설치본을 백업한 뒤 세 스킬과 남아 있는 retired 설치본을 함께 제거한다. 이미 설치되어 있지
않으면 변경 없이 성공한다.

백업을 수동으로 복원하려면 먼저 아래 대상이 모두 없는지 확인한다.

```bash
test ! -e "$HOME/.agents/skills/plan-feature"
test ! -e "$HOME/.agents/skills/plan-run-feature"
test ! -e "$HOME/.agents/skills/save-approved-plan"
test ! -e "$HOME/.agents/skills/run-feature"
```

복원할 `<backup-set>`을 선택하고 그 안의 스킬 디렉터리를 복사한 뒤 백업과 일치하는지
확인한다.

```bash
for skill in plan-feature save-approved-plan run-feature; do
  if test -d "$HOME/.agents/skill-backups/feature-workflow/<backup-set>/$skill"; then
    cp -a "$HOME/.agents/skill-backups/feature-workflow/<backup-set>/$skill" \
      "$HOME/.agents/skills/$skill"
    diff -qr "$HOME/.agents/skill-backups/feature-workflow/<backup-set>/$skill" \
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
4. 행동 변경은 `$plan-feature`, `$save-approved-plan`, `$run-feature`로 계획·구현한다.
5. feature worktree의 후보 스킬을 최소 재현과 독립된 새 세션으로 검증한다. 전역
   설치본은 후보를 시험하기 위해 변경하지 않는다.
6. 검증된 변경만 `main`에 통합하고 소비 프로젝트에서 실패 단계를 다시 실행한다.

canonical 작업 디렉터리는 깨끗한 `main`으로 유지한다. 스킬 변경은 feature worktree에서
수행하며, Git 커밋 해시를 설치본의 버전 식별자로 사용한다. 활성 세션이 병합된 변경을
인식하지 못하면 해당 세션을 새로 열거나 resume한다.
