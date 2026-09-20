---
feature_id: 20260920-expand-implementation-delegation
title: 구현 단계의 subagent 위임 범위 확대
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

`implement-dev-plan`에서 subagent를 독립 리뷰에만 사용하도록 한 제한을 완화한다. 메인 대화가 전체 작업을 책임지면서 필요한 하위 작업을 위임할 수 있도록 한다.

- 독립적인 탐색·분석·검증·구현 작업을 필요할 때 위임할 수 있다. 위임 자체를 의무화하거나 일반 작업용 agent 수·모델·추론 수준을 고정하지 않는다.
- 공유 실행 상태, Git 이력과 checkpoint, 최종 통합은 메인 대화가 관리한다.
- 최종 독립 리뷰는 구현에 참여하지 않은 reviewer 하나가 수행한다. 구현 agent의 자체 점검으로 대체하지 않는다.
- `create-dev-plan`에는 계획 단계의 위임 지시를 추가하지 않는다. `save-dev-plan`의 저장·인계 정책도 유지한다.

**Current Spec Impact:** `add`. 현재 명세의 워크플로에 선택적 구현 위임, 메인 대화의 상태·통합 책임, 구현 참여자와 최종 reviewer의 분리를 추가한다. 기존 coverage와 독립 리뷰·검증·복구 조건을 보존하고 이번 기능 명세를 근거로 연결한다.

**사용자 결정 사항**

| 주제 | 선택 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 위임 범위 | 구현 스킬의 명시적인 용도 제한 완화 | 네이티브 subagent 활용 범위 확대 | implement-dev-plan |
| 계획 단계 | 위임 허용 문구를 추가하지 않음 | 계획 스킬에 별도 위임 정책을 추가할 필요가 없음 | create-dev-plan |
| 최종 책임 | 메인 대화의 통합 책임과 독립 리뷰 유지 | 앞서 제안한 수정 방향 채택 | 구현·검증·통합 |

**승인 기준:** 리뷰 외 작업을 위임할 수 있고, 위임 작업의 동시 변경이 최종 검증·checkpoint·통합을 훼손하지 않으며, 최종 리뷰의 독립성과 한·영 의미·강도가 보존된다.
