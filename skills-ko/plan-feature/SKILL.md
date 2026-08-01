---
name: plan-feature
description: 표준 기능 또는 네이티브 목표 루프 기능을 계획하기 위해 사용자를 인터뷰하고 의사결정이 완료된 구현 계획을 작성합니다. 사용자가 구현 또는 저장 전에 기능을 계획하려고 "$plan-feature"를 명시적으로 호출하거나 `$plan-run-feature`가 승인된 Plan 단계를 위임한 경우에만 사용합니다.
---

# 기능 계획

계획만 수행합니다. 파일을 쓰거나, 브랜치를 만들거나, 구현하거나, 변경을 일으키는 명령을 실행하지 마세요.

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, 기계 판독용 스키마 키는 원형을 정확히 유지하세요.

## Plan 모드 요구

Plan 모드가 활성화되어 있지 않으면 사용자에게 Plan 모드로 전환한 뒤 `$plan-feature`를 다시 호출하도록 요청하세요. `$plan-run-feature`가 위임한 호출도 Plan 모드여야 합니다.
저장소 상태를 변경하지 말고 중단하세요.

## 인터뷰의 근거 확보

질문하기 전에 저장소를 조사하세요. 적용되는 지침, 관련 코드, 설정, 테스트, 기존 관례를 읽으세요. 탐색으로 확인할 수 있는 사실은 직접 해결하세요.

조사가 끝나면 첫 번째 의도 질문으로 다음 중 하나를 반드시 선택하게 하세요.

- `standard`: 명시적인 승인 및 평가 기준이 있는 한정된 구현
- `goal-loop`: 측정 가능한 목표를 향해 구현 또는 튜닝을 반복
- `other`: 이 기능 워크플로 밖의 질문 또는 작업

표시되는 레이블은 현재 대화 언어로 현지화하되 위 내부 값은 그대로 유지하세요.

가능하면 구조화된 사용자 입력 도구를 사용하세요.

사용자가 `other`를 선택하면 이 워크플로 적용을 중단하세요. 기능 ID, 기능 산출물, 저장용 인계를 생성하지 마세요. 활성 모드의 기본 동작으로 사용자 요청을 계속 처리하세요.

## 표준 기능 인터뷰

계획에서 다음 사항이 확정될 때까지 중요한 질문을 계속하세요.

- 의도한 결과, 대상 사용자, 완료 정의
- 포함할 동작과 제외할 동작
- 호환성, 보안, 성능, 운영 제약
- 구현 접근법과 주요 인터페이스 또는 데이터 흐름
- 실패 방식과 복구 기대사항
- 실행 가능한 평가 명령과 성공 조건
- 독립 리뷰 승인 기준
- 각 평가의 병합 후 smoke 선택: `auto`, `always`, `never` 중 하나
- 기본값이 300초인 smoke 기준 시간
- 기능에 필요한 경우에만 rollout, migration, monitoring

병합 후 smoke 명령을 적어도 하나 요구하세요.

## 목표 루프 기능 인터뷰

다음 실험 계약 전체를 확정하세요.

- 결과
- metric, unit, optimization direction
- baseline 값과 재현 가능한 baseline 명령
- 수치 target과 tolerance
- measurement 명령과 성공 해석
- correctness, performance, quality guardrail
- 허용되는 코드, 설정, parameter, search space
- 금지되는 변경과 호환성 제약
- 최대 iterations, wall-clock duration, token budget 중 적어도 하나의 실행 budget
- best-so-far 비교 및 checkpoint 규칙
- primary metric이 같을 때의 tie-breaker
- 보고, 일시 중지, 재계획 조건
- 전체 최종 평가 및 병합 후 smoke 계약

예상 평가 비용을 조사한 뒤 구체적인 budget 선택지를 추천하세요. 사용자가 응답하지 않았을 때 기본값을 임의로 고르지 마세요. 적어도 하나의 수치 budget에 대한 명시적인 승인을 요구하세요. 사용자가 token 수를 명시적으로 승인한 경우에만 네이티브 token budget을 포함하세요.

4,000자 이하의 네이티브 goal objective를 작성하세요. guardrail을 보존하면서 target에 도달하는 구현을 찾고 검증하는 일만 포함해야 합니다. 결과, metric target, 제약, 검증, 앞으로 저장될 계획 경로를 포함하세요. 자세한 실험 지침은 objective를 과도하게 늘리지 말고 계획에 넣으세요.

다음 checkpoint 정책을 사용하세요.

- 깨끗한 baseline commit에서 시작
- guardrail을 통과한 개선만 best-so-far commit으로 보존
- 모든 실험 결과 기록
- 실패하거나 더 나쁜 agent 소유 실험은 best checkpoint로 복원
- 예기치 않은 사용자 또는 동시 변경을 버리지 말고 중단

네이티브 goal은 target과 guardrail이 검증되면 끝납니다. 독립 리뷰와 통합은 이후 `$run-feature` 단계이며 네이티브 goal 완료 범위 밖입니다.

## 계획 확정

기능 제목으로 `YYYYMMDD-<slug>`를 생성하세요. `<git-common-dir>/feature-workflow/features/`를 읽기 전용으로 조사하고 충돌하면 `-2`, `-3` 등을 붙이세요.

최종 frontmatter에서는 `standard` 또는 `goal-loop`만 허용하세요.

```yaml
---
feature_id: <id>
title: <title>
feature_type: <standard-or-goal-loop>
base_branch: main
smoke_threshold_seconds: 300
---
```

goal loop에는 네이티브 objective와 budget을 포함해 승인된 모든 실험 필드가 들어간 `Goal Contract` 섹션을 포함하세요.

요구되는 Plan 모드 형식으로 의사결정이 완료된 계획을 작성하세요.

일반 `$plan-feature` 호출의 마지막에는 계획을 저장하려면 Default 모드로 전환하고 `$save-approved-plan`을 명시적으로 호출해야 한다는 안내를 현재 대화 언어로 현지화한 인용문을 넣으세요.

`$plan-run-feature`가 위임한 호출에서는 frontmatter에 `execution_handoff: plan-run-feature`를 추가하세요. 마지막 인용문에는 "Implement this plan"을 선택하면 Default 모드에서 계획 저장과 실행을 계속하며, 자동 continuation이 시작되지 않으면 Default 모드에서 `$plan-run-feature`를 다시 호출할 수 있다고 안내하세요.
