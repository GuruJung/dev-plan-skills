---
feature_id: 20260904-add-readme-skill-usage
title: README 스킬 사용법 추가
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

# README 스킬 사용법 추가

## 요약

README에 신규 사용자가 세 개발 계획 스킬을 올바른 모드와 순서로 사용할 수 있는 한글 빠른 시작 안내를 추가한다.

## 요구사항과 제외 사항

- 전역 설치 후 Plan mode에서 `$create-dev-plan`을 명시적으로 호출하는 기본 시작 절차를 설명한다.
- `$create-dev-plan`, `$save-dev-plan`, `$implement-dev-plan <feature-id>`의 역할과 호출 조건을 구분한다.
- 권장 자동 흐름인 “계획 확정 → Implement this plan → 저장 → 구현·평가·독립 리뷰·통합”을 예시로 보여 준다.
- 직접 호출한 `$save-dev-plan`은 저장 전용임을 밝히고, 자동 handoff가 시작되지 않을 때 Default mode에서 저장한 뒤 보고된 ID로 구현하는 수동 흐름을 설명한다.
- 저장 실패 시 구현이 시작되지 않으며, 구현은 자동 push나 feature branch·worktree 삭제를 하지 않는다는 주요 경계를 안내한다.
- 내부 schema, metadata 복구 절차와 구현 알고리즘까지 다루는 상세 운영 문서는 추가하지 않는다.
- 스킬의 호출 계약, 실행 동작, 공개 명령과 파일 형식은 변경하지 않는다.

## Current Spec Impact

- `add`: README가 세 스킬의 사용 전제, 역할, 권장 자동 흐름, 수동 대체 흐름과 주요 실행 경계를 사용자에게 안내해야 한다는 현재 의도를 추가한다.
- 기존 워크플로 의도와 한글 서술을 보존하고 이 기능 명세를 결정 근거에 연결한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 문서 추가 | README에 스킬 사용법을 추가한다. | 현재 README에 사용법 소개가 없기 때문이다. | 사용자용 README |
| 설명 깊이 | 빠른 시작과 전체 흐름을 함께 제공한다. | 별도 이유는 제시하지 않았다. | 신규 사용법 절 |

## 승인 기준

- README만 읽어도 설치 후 첫 호출부터 자동 구현 또는 수동 대체 흐름까지 실행할 수 있다.
- 세 스킬의 역할과 Plan/Default mode 경계가 실제 스킬 계약과 일치한다.
- 직접 저장과 자동 handoff를 혼동시키는 설명이 없다.
- 기존 설치·동기화·제거·개선 문서의 의미와 구조가 유지된다.
- 모든 eval이 통과하고 독립 리뷰에서 P0–P2 finding이 없다.
