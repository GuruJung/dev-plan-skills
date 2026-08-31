---
feature_id: 20260831-chain-save-and-implement
title: 계획 저장 후 구현 연속 인계
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

# 계획 저장 후 구현 연속 인계

## 요약

`$create-dev-plan`의 확정 계획에서 사용자가 호스트의 “Implement this plan”을 선택하면 같은 대화에서 `$save-dev-plan`으로 계획을 저장한 뒤, 저장된 최종 feature ID를 사용해 `$implement-dev-plan`까지 추가 승인 없이 연속 실행한다.

## 요구사항과 비범위

- 새 handoff 공개 계약은 `execution_handoff.continuation: implement-dev-plan`을 사용한다.
- handoff는 같은 대화의 최신 확정 계획과 실제 “Implement this plan” 선택에만 유효하다.
- 저장이 완전히 성공한 뒤에만 구현을 시작하며, 충돌 suffix가 적용됐으면 확정된 새 ID를 구현 단계에 전달한다.
- 저장 실패, 산출물 불일치, 복구 선택 대기 또는 안전 중단 시 구현을 호출하지 않는다.
- 동일 대화에서 저장 후 continuation이 중단된 재시도는 저장 산출물과 확정 계획의 동일성을 확인한 경우에만 기존 ID를 재사용한다.
- `$save-dev-plan` 직접 호출은 계속 저장 전용이며, `$implement-dev-plan [<feature-id>]` 직접 호출도 계속 지원한다.
- `implement-dev-plan`의 일반 암시적 호출은 허용하지 않고, 검증된 handoff delegation만 명시 호출의 대체 승인 경로로 인정한다.
- 기존 구현 단계의 안전 중단, 복구, 평가, 독립 리뷰, 통합 계약은 변경하지 않는다.
- 이전에 생성된 `continuation: save-only` 계획이나 과거 계획 문서는 migration하지 않는다.

## Current Spec Impact

- `add`: “Implement this plan” 선택이 같은 대화에서 계획 저장과 구현 전체를 승인하고 두 스킬을 순차 실행한다는 현재 workflow 의도를 추가한다.
- 저장 성공 전 구현 금지와 직접 `$save-dev-plan` 호출의 저장 전용 성격을 함께 명시한다.
- 기존 current-spec 내용과 한글 서술을 보존하고 이 feature spec을 결정 근거에 추가한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 자동 continuation | “Implement this plan” 선택 시 `$save-dev-plan` 다음 `$implement-dev-plan`까지 연속 발동한다. | 별도 이유는 제시하지 않았다. | `$create-dev-plan`에서 생성한 같은 대화의 최신 확정 계획 |
| 실행 순서 | 계획을 먼저 저장하고 저장 성공 후 구현한다. | 별도 이유는 제시하지 않았다. | 자동 continuation |

## 승인 기준

- 새 계획의 handoff marker와 세 스킬의 승인 검사가 동일한 연속 실행 계약을 사용한다.
- “Implement this plan” 선택 한 번으로 저장과 구현이 순서대로 시작되며 중간 확인을 요구하지 않는다.
- 구현 단계는 저장된 최종 ID와 schema-v2 산출물을 사용한다.
- 직접 `$save-dev-plan` 호출, 이전 save-only 계획, 새 대화, 실패한 저장은 구현을 자동 시작하지 않는다.
- 재시도는 검증된 기존 저장물을 재사용하거나 안전하게 중단하며 중복 feature를 만들지 않는다.
- 한글·영문 스킬 쌍이 의미와 강도 면에서 일치하고 설치본에는 영어 ASCII만 포함된다.
- 독립 리뷰에서 P0–P2 finding이 없고 모든 eval이 통과한다.
