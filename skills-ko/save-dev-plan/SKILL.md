---
name: save-dev-plan
description: 확정된 최신 표준 또는 목표 루프 개발 계획을 준비나 구현 없이 공유 Git 메타데이터에 저장합니다. 사용자가 "$save-dev-plan"을 명시적으로 호출하거나 같은 대화의 승인된 `$create-dev-plan` save-only handoff가 저장을 위임한 경우에만 사용합니다.
---

# 개발 계획 저장

확정된 개발 계획 하나만 저장하세요. 명시 호출과 handoff 호출 모두 저장 전용입니다. 저장을 구현 승인으로 취급하거나 `$implement-dev-plan`을 직접 호출하지 마세요.

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, 기계 판독용 스키마 키는 원형을 정확히 유지하세요.

## 인계 확인

Plan 모드가 활성화되어 있으면 사용자에게 Default 모드로 전환하고 `$save-dev-plan`을 다시 호출하도록 요청하세요. 파일을 쓰지 마세요.

다음 중 하나일 때만 호출을 허용하세요.

1. 사용자가 `$save-dev-plan`을 명시적으로 호출했습니다.
2. 같은 대화의 최신 확정 `$create-dev-plan` 계획에 아래 handoff가 있고, 사용자가 host의
   "Implement this plan" 동작을 선택한 뒤 Default 모드로 전환됐습니다.

   ```yaml
   execution_handoff:
     skill: save-dev-plan
     authorization: explicit-user-selection
     automatic_trigger: implement-this-plan
     continuation: save-only
   ```

handoff marker만으로 사용자 선택을 추정하지 마세요. handoff는 새 대화로 이어지지 않으며,
그 경우 명시 호출을 요구하세요. 조건이 부족하면 파일을 쓰지 마세요.

대화에서 가장 최근에 확정된 `$create-dev-plan` 계획을 사용하세요. 다음을 요구하세요.

- 고유한 `feature_id`
- `standard` 또는 `goal-loop`인 `feature_type`
- `docs/superpowers/plans/<id>/plan.md` 형식의 `plan_path`
- 범위, 승인 기준, 구현 접근법
- 성공 조건이 있는 실행 가능한 평가 명령
- 모든 eval에 적용되는 자동 smoke 계약과 기준 시간 이내 실행이 예상되는 eval 하나 이상
- 승인된 smoke 기준 시간
- 현재 대화 언어의 `사용자 결정 사항` 또는 `User Decisions` 섹션
- `goal-loop`인 경우 완전한 `Goal Contract`

계획이 없거나, 불완전하거나, 지원되는 기능 유형 밖이면 내용을 만들어내지 마세요. 사용자에게 Plan 모드로 돌아가 `$create-dev-plan`을 호출하도록 요청하세요.

## 기능 저장

1. 저장소를 확인한 뒤 이 SKILL.md를 기준으로 bundled
   `scripts/migrate-workflow-metadata.sh`를 찾아 절대 경로로 `--repo <repository-path>`와 함께
   호출합니다. helper가 반환한 `<git-common-dir>/dev-plan-workflow/`만 사용하세요. legacy와
   canonical 디렉터리가 모두 있거나 legacy pending integration이 있으면 내용을 합치거나
   삭제하지 말고 중단하세요.
2. 확정된 `YYYYMMDD-<slug>` ID를 재사용합니다. 그 사이 Git 메타데이터나 main worktree의
   `docs/superpowers/plans/<id>/plan.md`와 충돌이 생겼다면 다음 숫자 suffix를 붙이고
   frontmatter, `plan_path`, goal objective의 저장 계획 경로를 포함해 feature ID를 나타내는
   모든 필드와 경로에서 canonical ID를 일관되게 갱신합니다. 우연히 같은 문자열을 포함한
   무관한 서술은 바꾸지 않습니다.
3. `<git-common-dir>/dev-plan-workflow/features/<id>/`를 생성합니다.
4. 승인된 결정을 바꾸지 않고 전체 계획을 임시 `plan.md`로 저장합니다.
5. 다음 내용으로 `state.json`을 원자적으로 생성합니다.

   ```json
   {
     "schema_version": 1,
     "id": "<id>",
     "title": "<title>",
     "feature_type": "<standard-or-goal-loop>",
     "status": "planned",
     "base_branch": "main",
     "branch": "feature/<id>",
     "worktree": null,
     "created_at": "<ISO-8601>",
     "updated_at": "<ISO-8601>",
     "last_checkpoint": null,
     "validated_feature_head": null,
     "validated_main_sha": null,
     "last_failure": null,
     "remaining_p3": [],
     "goal": null
   }
   ```

6. `goal-loop`에서는 `goal: null`을 다음 내용으로 교체합니다.

   ```json
   {
     "objective": "<approved-native-objective>",
     "native_status": "not-started",
     "budgets": {
       "max_iterations": null,
       "max_wall_time_seconds": null,
       "token_budget": null
     },
     "iterations_used": 0,
     "elapsed_seconds": 0,
     "baseline_metric": null,
     "best_metric": null,
     "best_checkpoint": null,
     "last_measurement": null,
     "stop_reason": null
   }
   ```

   승인된 budget과 baseline을 계획에서 가져와 채우세요. 선택하지 않은 budget 차원은 `null`로 두세요.

7. 상태 파일을 쓸 때 destination 디렉터리의 임시 파일을 사용한 뒤 atomic rename하세요.
8. main worktree, branch 또는 index를 변경하거나, 구현, 테스트, commit, push하지 마세요.
9. 호출 방식과 관계없이 저장된 ID, 임시 경로와 eventual
   `docs/superpowers/plans/<id>/plan.md` 경로를 보고한 뒤 다음 수동 명령으로
   `$implement-dev-plan <id>`를 보여 주세요. `$implement-dev-plan`을 호출하거나 branch, worktree, 구현,
   평가 또는 통합을 시작하지 마세요.

명시적인 사용자 승인 없이 기존 기능 계획을 덮어쓰지 마세요.
