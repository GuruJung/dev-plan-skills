---
name: save-approved-plan
description: 확정된 최신 표준 또는 목표 루프 기능 계획을 준비나 구현 없이 공유 Git 메타데이터에 저장합니다. plan-feature로 계획을 완료한 뒤 사용자가 "$save-approved-plan"을 명시적으로 호출한 경우에만 사용합니다.
---

# 승인된 계획 저장

확정된 기능 계획 하나만 저장하세요. 저장을 구현 승인으로 취급하지 마세요.

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, 기계 판독용 스키마 키는 원형을 정확히 유지하세요.

## 인계 확인

Plan 모드가 활성화되어 있으면 사용자에게 Default 모드로 전환하고 `$save-approved-plan`을 다시 호출하도록 요청하세요. 파일을 쓰지 마세요.

대화에서 가장 최근에 확정된 `$plan-feature` 계획을 사용하세요. 다음을 요구하세요.

- 고유한 `feature_id`
- `standard` 또는 `goal-loop`인 `feature_type`
- 범위, 승인 기준, 구현 접근법
- 성공 조건이 있는 실행 가능한 평가 명령
- 평가별 병합 후 선택과 적어도 하나의 사용 가능한 smoke
- 승인된 smoke 기준 시간
- `goal-loop`인 경우 완전한 `Goal Contract`

계획이 없거나, 불완전하거나, 지원되는 기능 유형 밖이면 내용을 만들어내지 마세요. 사용자에게 Plan 모드로 돌아가 `$plan-feature`를 호출하도록 요청하세요.

## 기능 저장

1. 저장소와 절대 공용 Git 디렉터리를 확인합니다.
2. 확정된 `YYYYMMDD-<slug>` ID를 재사용합니다. 그 사이 충돌이 생겼다면 다음 숫자 suffix를 붙이고 저장되는 계획 전체에서 ID를 일관되게 갱신합니다.
3. `<git-common-dir>/feature-workflow/features/<id>/`를 생성합니다.
4. 승인된 결정을 바꾸지 않고 전체 계획을 `plan.md`로 저장합니다.
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
8. branch나 worktree를 만들거나, 구현, 테스트, commit, push하지 마세요.
9. 저장된 ID와 경로를 보고한 뒤 다음 명시적 명령으로 `$run-feature <id>`를 보여 주세요.

명시적인 사용자 승인 없이 기존 기능 계획을 덮어쓰지 마세요.
