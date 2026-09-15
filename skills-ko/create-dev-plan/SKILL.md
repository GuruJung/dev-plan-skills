---
name: create-dev-plan
description: 지속 기능 명세와 로컬 구현 계획을 분리한 표준 또는 네이티브 목표 루프 개발 계획을 인터뷰하고 승인된 저장 후 구현 handoff와 함께 작성합니다. 사용자가 Plan 모드에서 "$create-dev-plan"을 명시적으로 호출한 경우에만 사용합니다.
---

# 개발 계획 만들기

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, YAML/JSON 키는 원형을 유지하세요.

## Plan 모드 요구

Plan 모드가 활성화되어 있지 않으면 사용자에게 Plan 모드로 전환한 뒤 `$create-dev-plan`을 다시 호출하도록 요청하세요. 저장소 상태를 변경하지 말고 중단하세요.

## 인터뷰의 근거 확보

`docs/dev-plans/current-spec.md`가 있으면 현재 제품 의도를 확인하는 첫 문서로 읽으세요. 현재 작업과 관련되고 current spec에서 연결한 `docs/dev-plans/specs/*/spec.md`만 결정 이유를 확인할 때 읽으세요. current spec의 coverage 밖인 의도는 코드에서 추정하지 말고 필요한 경우 사용자에게 확인하세요.

두 기능 유형 모두 일반적인 조사와 인터뷰는 native Plan 모드에 따르세요. 아래 유형별 지시는 추가로 확정해야 할 사항이며, 질문 범위를 해당 항목으로 제한하지 않습니다.

조사 후 기능 유형을 판별하세요.

- `standard`: 의미 중심 승인 기준이 있는 한정된 구현
- `goal-loop`: 측정 가능한 목표를 향해 구현 또는 튜닝을 반복

유형이 명확하면 직접 선택하고 짧게 알린 뒤 해당 인터뷰로 진행하세요. 조사 후에도 불명확할 때만 `standard`와 `goal-loop` 중 하나를 선택하게 하세요. 표시 레이블은 대화 언어로 현지화하되 내부 값은 유지하고, 가능한 경우 구조화된 사용자 입력 도구를 사용하세요. 다른 유형을 제시하지 마세요.

## 지속 의도와 실행 정보 분리

각 요구사항과 결정을 다음 기준으로 분류하세요.

- 구현을 전부 교체해도 지켜야 하는 목표, 관찰 가능한 동작, 공개 계약, 비범위, 제약, 실패·복구 기대, 결정 이유와 의미 중심 승인 기준은 `Tracked Feature Spec`에 둡니다.
- 현재 코드에서 조사한 파일·심볼·내부 흐름, 구현 순서, 실행 명령, checkpoint, 일회성 budget과 운영 절차는 `Local Implementation Plan`에 둡니다.
- 장기 의도가 아닌 실행 결정을 tracked spec에 넣지 말고, 구현 세부를 현재 의도처럼 표현하지 마세요.

## 표준 기능 인터뷰

확정한 의도를 두 산출물로 분리하고 아래의 검증 필요성을 판단하세요.

## 목표 루프 기능 인터뷰

지속 기능 명세에는 결과, metric과 unit, optimization direction, 수치 target과 tolerance, correctness·performance·quality guardrail, 허용·금지 변경과 호환성 제약을 확정하세요.

로컬 계획에는 재현 가능한 baseline과 measurement 명령, 성공 해석, 최대 iterations·wall-clock duration·token budget 중 적어도 하나, best-so-far 비교와 checkpoint 규칙, 동률 tie-breaker, 보고·중단·재계획 조건을 확정하세요. 별도의 최종 eval과 통합 후 smoke는 아래 기준으로 필요성을 각각 판단하되 목표·guardrail 측정은 유지하세요.

예상 평가 비용을 조사해 구체적인 budget 선택지를 추천하세요. 사용자가 응답하지 않았을 때 기본값을 임의로 고르지 말고 적어도 하나의 수치 budget을 명시적으로 승인받으세요. 사용자가 token 수를 승인한 경우에만 네이티브 token budget을 포함하세요.

4,000자 이하의 native goal objective를 작성하세요. 결과, metric target, 제약, 검증과 앞으로 저장될 로컬 plan 경로를 포함하되 상세 실험 지침은 계획에 두세요.

다음 checkpoint 정책을 사용하세요.

- 깨끗한 baseline commit에서 시작
- guardrail을 통과한 개선만 best-so-far commit으로 보존
- 모든 실험 결과 기록
- 실패하거나 더 나쁜 agent 소유 실험은 best checkpoint로 복원
- 예기치 않은 사용자 또는 동시 변경은 버리지 않고 중단

native goal은 target과 guardrail이 검증되면 끝납니다. 독립 리뷰와 통합은 이후 `$implement-dev-plan` 단계입니다.

## 검증 계약과 리뷰 준비

eval과 통합 후 smoke의 필요성을 각각 판단하세요. 적용되는 저장소 필수 검사, 변경의 실제 위험과 실행 가능한 검증의 유용성을 근거로 local plan에 `eval_required`와 `smoke_required`를 boolean으로 명시하고 필요성·생략 이유를 짧게 기록하세요. 중요한 불확실성만 사용자에게 질문하세요.

- `eval_required: true`이면 실행 가능한 명령과 성공 조건을 확정합니다. `false`이면 별도 eval 계약을 요구하지 않되 의미 중심 승인 기준과 적절한 수동·의미 검증 방법을 남깁니다. 형식적인 명령을 만들지 않습니다.
- `smoke_required: true`이면 local에서 안전하게 반복할 수 있고 deployment나 되돌릴 수 없는 외부 side effect가 없는 명령과 기준 시간(기본 60초)을 확정합니다. eval 명령을 재사용하거나 별도 명령을 정하고, 기준 시간 내 실행을 검증하거나 합리적으로 예상합니다. 빠른 eval의 존재만으로 smoke를 의무화하지 않습니다.
- `smoke_required: false`이면 `smoke_threshold_seconds`와 smoke 계약을 생략합니다. 적용되는 검증과 독립 리뷰 후 추가 사용자 확인 없이 통합·완료합니다.

계약 생략은 저장소 필수 검사를 면제하지 않습니다. 검사 실패나 환경 부족을 불필요한 계약으로 바꾸어 통과시키지 마세요. 실행 중 중요한 위험이 발견되면 필요성을 다시 판단하세요.

두 기능 유형 모두 적용되는 `AGENTS.md`, override와 연결된 리뷰 문서를 확인하세요. 정확성·보안·성능·유지보수성, 기존 동작의 회귀, 관련 호출부와 경계 사례 중 이번 변경에 관련된 제약·불변조건·위험을 spec 승인 기준과 local 검증 방법에 연결하세요. 내장 리뷰의 출력 JSON, finding 작성법이나 우선순위 표기 규칙을 계획에 복사하지 마세요. 구현 후 독립 리뷰는 계획 체크리스트에 한정하지 않고 전체 변경을 검토합니다.

## Current Spec 영향 확정

`Tracked Feature Spec`의 `Current Spec Impact`에 `docs/dev-plans/current-spec.md`에서 추가, 교체 또는 제거할 현재 의도를 정확히 기록하세요. current spec이 없으면 새 체계 이후의 결정만 다룬다는 coverage와 이번 기능의 현재 의도로 최초 파일을 만드는 내용을 포함하세요.

`Current Spec Impact`가 `add`, `replace`, `remove` 중 하나이면 current spec의 기존 내용을 포함한 전체 서술 언어를 tracked feature spec의 주된 서술 언어와 맞추도록 계획하세요. frontmatter, code block, 명령, 경로, 식별자, enum 값과 YAML/JSON 키는 언어 판별에서 제외하고 번역하지 마세요. 주된 서술 언어가 명확하지 않으면 current spec 언어를 사용자에게 확인하세요. 기존 current intent, coverage와 결정 근거의 의미를 보존하고 일부만 번역한 혼합 언어 문서를 만들지 마세요.

순수 리팩터처럼 현재 의도가 변하지 않으면 `No change`와 보존할 불변조건을 명시하세요. 이 경우 feature spec과 current spec의 언어가 달라도 번역하지 말고, 내용이 달라지지 않는데 provenance나 timestamp만 갱신하도록 계획하지 마세요.

## 계획 확정

기능 제목으로 `YYYYMMDD-<slug>`를 생성하세요. `<git-common-dir>/dev-plan-workflow/plans/`, main worktree의 `docs/dev-plans/specs/<id>/spec.md`, branch와 등록된 worktree를 읽기 전용으로 조사하고 충돌하면 `-2`, `-3` 등을 붙이세요.

최종 frontmatter에서는 `standard` 또는 `goal-loop`만 허용하세요.

```yaml
---
feature_id: <id>
title: <title>
feature_type: <standard-or-goal-loop>
base_branch: main
spec_path: docs/dev-plans/specs/<id>/spec.md
current_spec_path: docs/dev-plans/current-spec.md
plan_path: <git-common-dir>/dev-plan-workflow/plans/<id>/plan.md
eval_required: true
smoke_required: true
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: implement-dev-plan
---
```

위 boolean은 예시이므로 각각 판단한 값으로 대체하고 smoke가 불필요하면 threshold를 빼세요. 신규 계획에는 두 boolean을 모두 명시하세요.

계획에 다음 두 최상위 섹션을 포함하세요.

1. `Tracked Feature Spec`: 요약, 요구사항과 비범위, `Current Spec Impact`, 사용자 결정 사항, 승인 기준
2. `Local Implementation Plan`: 구현 접근법, 작업 순서, 검증 필요성·방법, 필요한 계약과 실행 관련 결정

모든 계획의 tracked spec에 현재 대화 언어로 `사용자 결정 사항` 또는 `User Decisions`를 포함하세요. 결정 주제, 사용자가 선택한 내용, 사용자가 밝힌 이유나 tradeoff와 적용 범위를 기록하세요. 이유가 없으면 만들어내지 말고 `명시되지 않음`에 해당하는 표현을 사용하세요. 저장소 사실과 agent 기본값은 사용자 결정으로 기록하지 마세요.

goal loop의 지속 target과 guardrail은 tracked spec에, native objective와 budget을 포함한 완전한 `Goal Contract`는 local plan에 포함하세요.

요구되는 Plan 모드 형식으로 의사결정 완료 계획을 작성하세요.

마지막 인용문에서 host의 "Implement this plan" 동작은 Default 모드로 전환한 뒤 `$save-dev-plan`에 Git 공용 metadata 임시 저장을 위임하고, 저장에 성공하면 확정된 feature ID로 `$implement-dev-plan`까지 추가 확인 없이 이어서 실행한다고 안내하세요. 이 선택은 같은 대화의 최신 확정 계획에 대해서만 저장, branch·worktree 생성, 구현, 평가, 독립 리뷰와 통합을 승인합니다. 자동 handoff가 시작되지 않으면 Default 모드에서 `$save-dev-plan`을 명시적으로 호출한 뒤 보고된 ID로 `$implement-dev-plan <id>`를 호출하도록 안내하세요.
