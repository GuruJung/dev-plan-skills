---
name: save-dev-plan
description: 확정된 최신 지속 기능 명세와 로컬 구현 계획을 준비나 구현 없이 공유 Git metadata에 저장합니다. 사용자가 "$save-dev-plan"을 명시적으로 호출하거나 같은 대화의 승인된 `$create-dev-plan` save-only handoff가 저장을 위임한 경우에만 사용합니다.
---

# 개발 계획 저장

확정된 기능 하나의 tracked spec과 local plan만 저장하세요. 명시 호출과 handoff 호출 모두 저장 전용입니다. 저장을 구현 승인으로 취급하거나 `$implement-dev-plan`을 직접 호출하지 마세요.

사용자가 다른 언어를 요청하지 않는 한 질문, 상태 안내와 서술형 산출물에는 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값과 YAML/JSON 키는 원형을 유지하세요.

## 인계 확인

Plan 모드가 활성화되어 있으면 Default 모드로 전환하고 `$save-dev-plan`을 다시 호출하도록 요청한 뒤 파일을 쓰지 마세요.

다음 중 하나일 때만 허용하세요.

1. 사용자가 `$save-dev-plan`을 명시적으로 호출했습니다.
2. 같은 대화의 최신 확정 `$create-dev-plan` 계획에 아래 handoff가 있고 사용자가 host의 "Implement this plan" 동작을 선택한 뒤 Default 모드로 전환됐습니다.

```yaml
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
```

marker만으로 사용자 선택을 추정하지 마세요. handoff는 새 대화로 이어지지 않습니다.

## 확정 산출물 검증

가장 최근의 확정 `$create-dev-plan` 계획에서 다음을 요구하세요.

- 고유한 `feature_id`와 `standard` 또는 `goal-loop`인 `feature_type`
- `docs/dev-plans/specs/<id>/spec.md` 형식의 `spec_path`
- `docs/dev-plans/current-spec.md`인 `current_spec_path`
- `<git-common-dir>/dev-plan-workflow/plans/<id>/plan.md`인 `plan_path`
- 완전한 `Tracked Feature Spec`과 `Local Implementation Plan`
- tracked spec의 `Current Spec Impact`, 사용자 결정 사항과 의미 중심 승인 기준
- local plan의 구현 접근법, 성공 조건이 있는 실행 가능한 eval과 승인된 smoke threshold
- 모든 eval에 적용되는 자동 smoke 계약과 기준 시간 이내 실행이 예상되는 eval 하나 이상
- goal loop이면 tracked target·guardrail과 local plan의 완전한 `Goal Contract`

내용이 없거나 불완전하면 만들어내지 말고 Plan 모드에서 `$create-dev-plan`을 다시 호출하도록 요청하세요.

## 기능 저장

1. 확정 ID를 재사용합니다. Git metadata, 신규 `spec_path`, branch 또는 등록 worktree와 충돌하면 다음 숫자 suffix를 붙이고 모든 feature-ID-bearing 필드와 경로를 일관되게 갱신합니다. 무관한 서술은 바꾸지 않습니다.
2. `<git-common-dir>/dev-plan-workflow/plans/` 아래 destination과 같은 filesystem의 고유 staging 디렉터리를 만드세요. destination이 이미 있으면 명시적 overwrite 승인 없이 변경하지 마세요.
3. `Tracked Feature Spec`을 다음 frontmatter와 함께 독립된 `spec.md`로 저장하세요. 승인된 문장을 재해석하거나 local 실행 정보를 추가하지 마세요.

   ```yaml
   ---
   feature_id: <id>
   title: <title>
   feature_type: <standard-or-goal-loop>
   current_spec_path: docs/dev-plans/current-spec.md
   ---
   ```

4. `Local Implementation Plan`을 다음 실행 frontmatter와 함께 독립된 `plan.md`로 저장하세요. tracked spec을 복제하지 말고 `spec_path`를 가리키세요.

   ```yaml
   ---
   feature_id: <id>
   title: <title>
   feature_type: <standard-or-goal-loop>
   base_branch: main
   spec_path: docs/dev-plans/specs/<id>/spec.md
   current_spec_path: docs/dev-plans/current-spec.md
   smoke_threshold_seconds: 60
   ---
   ```

5. 다음 `state.json`을 staging 디렉터리에 작성하세요.

   ```json
   {
     "schema_version": 2,
     "id": "<id>",
     "title": "<title>",
     "feature_type": "<standard-or-goal-loop>",
     "status": "planned",
     "base_branch": "main",
     "branch": "feature/<id>",
     "worktree": null,
     "spec_path": "docs/dev-plans/specs/<id>/spec.md",
     "current_spec_path": "docs/dev-plans/current-spec.md",
     "created_at": "<ISO-8601>",
     "updated_at": "<ISO-8601>",
     "last_checkpoint": null,
     "validated_feature_head": null,
     "validated_main_sha": null,
     "integrated_main_sha": null,
     "last_failure": null,
     "remaining_p3": [],
     "goal": null
   }
   ```

6. goal loop이면 `goal: null`을 다음 객체로 바꾸고 승인된 objective, budget과 baseline을 채우세요. 선택하지 않은 budget 차원은 `null`로 둡니다.

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

7. staging의 세 파일이 plain file이고 저장 내용과 일치하는지 확인한 뒤 staging 디렉터리를 destination으로 atomic rename하세요. 실패하면 destination을 만들거나 부분 산출물을 남기지 말고 agent 소유 staging만 정리하세요.
8. main worktree, branch와 index를 변경하거나 구현, 테스트, commit, push하지 마세요.
9. 저장된 ID, 임시 spec·plan 경로와 eventual `spec_path`를 보고하고 다음 수동 명령으로 `$implement-dev-plan <id>`를 보여 주세요. 직접 실행하지 마세요.

명시적인 사용자 승인 없이 기존 기능 저장물을 덮어쓰지 마세요.
