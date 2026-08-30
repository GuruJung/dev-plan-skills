---
feature_id: 20260830-separate-specs-and-local-plans
title: 지속 명세와 로컬 구현 계획 분리
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

# 지속 명세와 로컬 구현 계획 분리

## 요약

개발 의도 중 장기 보존할 내용은 tracked feature spec과 current spec에 기록하고, 현재 코드
구조에 의존하는 구현 세부는 Git 공용 metadata의 local plan에만 보관한다.

## 요구사항과 비범위

- 모든 신규 개발 계획은 `Tracked Feature Spec`과 `Local Implementation Plan`을 분리한다.
- feature spec은 변경 의도, 사용자 결정과 이유, 공개 계약, 제약, 비범위와 의미 중심 승인
  기준을 보존한다.
- current spec은 새 workflow coverage 안에서 현재 유효한 의도의 기준이며 과거 spec을
  시간순으로 합친 문서가 아니다.
- local plan은 구현·재개에 필요한 동안만 보존하고 통합 smoke 성공 후 삭제한다.
- source code와 tests는 실제 동작의 source of truth로 유지한다.
- 순수 refactor는 보존할 불변조건을 feature spec에 기록하되 current spec을 의미 없이
  수정하지 않는다.
- 기존 `docs/superpowers/plans/**`의 수정·변환, 이전 저장 형식의 migration·호환·식별·전용
  오류 처리는 범위에 포함하지 않는다.

## Current Spec Impact

- `docs/dev-plans/current-spec.md`를 최초 생성한다.
- coverage는 2026-08-30 이후 `docs/dev-plans/specs/`에서 도입하거나 수정한 의도로 제한한다.
- 현재 유효한 artifact 역할, 저장·승격·삭제 lifecycle과 intent/truth 경계를 추가한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 문서 역할 | feature spec은 변경 의도, current spec은 현재 의도, 코드는 실제 동작, local plan은 임시 실행 자료로 구분한다. | 코드에서 복원할 수 없는 장기 의도만 Git에 보존한다. | 신규 계획 |
| plan 보관 | local plan은 Git 공용 metadata에만 저장한다. | 다른 clone·machine으로 이관하지 않는다. | 신규 계획 |
| current spec | `docs/dev-plans/current-spec.md` 단일 파일을 사용한다. | 조사 시작점을 단순화한다. | 신규 명세 |
| feature spec | `docs/dev-plans/specs/<id>/spec.md`에 기록한다. | 변경 이유를 현재 상태와 분리한다. | 신규 명세 |
| 초기 coverage | 기존 계획을 옮기지 않고 신규 변경부터 누적한다. | migration을 하지 않는다. | current spec |
| 의도 불변 작업 | feature spec만 기록하고 current spec은 수정하지 않는다. | 의미 없는 churn을 피한다. | 순수 refactor |
| 이전 형식 | 식별하거나 별도로 처리하지 않는다. | 지난 규격을 고려하지 않는다. | 신규 workflow |

## 승인 기준

- 신규 계획의 durable intent와 execution detail이 독립된 artifact로 저장된다.
- Git에는 feature spec과 필요한 current-spec 변경만 남고 local plan은 들어가지 않는다.
- current spec은 현재 상태만 설명하며 coverage와 결정 근거를 명확히 표시한다.
- spec 승격 실패나 integration 실패는 local plan을 보존하고 성공한 integration만 삭제한다.
- 신규 schema와 필수 artifact가 유효하지 않으면 다른 경로를 추정하지 않고 무변경 중단한다.
- 기존 `docs/superpowers/plans/**` 파일은 수정되지 않는다.
