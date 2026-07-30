# Feature Workflow Skills

사용자와 함께 계획을 확정한 뒤 구현·평가·독립 리뷰·통합을 수행하는 Codex 스킬
모음이다. `skills/`가 유일한 원본이며, 모든 스킬은 `$plan-feature`,
`$save-approved-plan`, `$run-feature`처럼 명시적으로 호출해야 한다.

## 전역 설치

```bash
scripts/install-global-skills.sh
scripts/install-global-skills.sh --check
```

설치 스크립트는 `~/.agents/skills/` 아래에 `skills/`의 각 스킬을 가리키는 절대경로
심볼릭 링크를 만든다. 기존 파일이나 다른 링크는 덮어쓰지 않는다. 저장소를 이동했다면
설치 스크립트를 다시 실행해야 한다.

격리된 설치 검증처럼 별도 목적지가 필요할 때만 `FEATURE_WORKFLOW_TARGET_ROOT` 환경
변수로 대상 디렉터리를 지정할 수 있다.

## 스킬 개선

다른 프로젝트에서 문제를 발견하더라도 해당 프로젝트의 세션에서 전역 스킬을 직접
수정하지 않는다.

1. 소비 프로젝트의 작업을 안전한 체크포인트에 보존한다.
2. 아래 항목을 포함한 개선 보고서를 만든다.
   - 스킬 이름과 이 저장소의 Git 커밋
   - 호출 명령과 feature 유형
   - 기대 동작과 실제 동작
   - 최소 재현 절차
   - 관련 출력과 diff
   - 작업을 막는 문제인지 여부
3. 이 저장소에서 새 Codex 세션을 열고 보고서를 전달한다.
4. 행동 변경은 `$plan-feature`, `$save-approved-plan`, `$run-feature`로 계획·구현한다.
5. feature worktree의 후보 스킬을 최소 재현과 독립된 새 세션으로 검증한다. 전역 링크는
   후보를 시험하기 위해 변경하지 않는다.
6. 검증된 변경만 `main`에 통합하고 소비 프로젝트에서 실패 단계를 다시 실행한다.

canonical 작업 디렉터리는 깨끗한 `main`으로 유지한다. 스킬 변경은 feature worktree에서
수행하며, Git 커밋 해시를 설치본의 버전 식별자로 사용한다. 활성 세션이 병합된 변경을
인식하지 못하면 해당 세션을 새로 열거나 resume한다.
