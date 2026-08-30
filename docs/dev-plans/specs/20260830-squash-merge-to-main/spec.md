---
feature_id: 20260830-squash-merge-to-main
title: main 단일 squash 커밋 통합
feature_type: standard
current_spec_path: docs/dev-plans/current-spec.md
---

# main 단일 squash 커밋 통합

## 요약

`$implement-dev-plan`이 feature 브랜치를 `main`에 통합할 때 검증된 최종 내용을 새 커밋 하나로 합치는 squash merge를 사용한다. `current-spec.md`에 의미 변경을 적용할 때는 문서 전체의 서술 언어를 해당 feature `spec.md`의 언어와 일치시킨다.

## 요구사항과 비범위

- `main`에는 기능 하나당 정확히 한 커밋만 추가한다.
- 새 커밋의 부모는 검증된 `main` SHA이고, tree는 검증된 feature HEAD의 tree와 같아야 한다.
- 커밋 제목은 정확히 `<기능 제목> (<feature-id>)` 형식으로 만든다.
- feature 브랜치의 spec·구현·checkpoint 커밋과 worktree는 수정하거나 삭제하지 않는다.
- 성공 상태에는 검증된 feature HEAD와 실제 squash 커밋 SHA를 구분해 기록한다.
- smoke 실패 시 `main`을 검증 전 SHA로 복원하고 local plan을 보존한다.
- 새 형식의 중단 marker는 smoke 재실행과 rollback을 지원한다. 기존 4필드 marker는 자동 변환하지 않고 무변경 중단한다.
- `Current Spec Impact`가 `add`, `replace`, `remove` 중 하나이면 기존 내용을 포함한 `current-spec.md` 전체 서술을 해당 feature spec의 언어로 통일한다.
- 언어를 맞출 때 기존 current intent, coverage와 결정 근거의 의미를 보존하며 명령, 경로, 식별자, enum 값과 YAML/JSON 키는 원형을 유지한다.
- feature spec의 주된 서술 언어가 명확하지 않으면 current spec을 수정하기 전에 사용자에게 언어를 확인한다.
- `Current Spec Impact: No change`이면 언어가 달라도 current spec을 번역하거나 수정하지 않는다.
- 기존 feature spec이나 과거 계획 문서는 번역하지 않는다.
- 기존 eval, 독립 리뷰, 최신 `main` 재검증, rebase, push 금지와 branch/worktree 보존 정책은 유지한다.

## Current Spec Impact

- 기존 영문 `docs/dev-plans/current-spec.md` 전체를 이번 한글 feature spec과 같은 한글 서술로 번역한다.
- Coverage, artifact 역할, lifecycle, source-of-truth 경계와 기존 feature-spec 링크의 의미는 보존한다.
- Workflow의 기존 fast-forward 통합 의도를 검증된 feature tree를 단일 squash 커밋으로 `main`에 기록하는 의도로 교체한다.
- 성공 상태가 feature HEAD와 squash된 main SHA를 별도로 보존한다는 의도를 추가한다.
- current spec에 의미 변경을 적용할 때 문서 전체 언어를 해당 feature spec과 맞추되 `No change`에서는 언어만을 이유로 수정하지 않는 정책을 추가한다.
- 새 feature spec을 squash 통합과 언어 정책의 결정 근거로 연결하고 기존 결정 근거도 유지한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 통합 topology | `main`에는 기능 전체를 한 커밋으로 squash merge한다. | `main` 이력을 기능당 한 커밋으로 유지하고 싶다고 명시했다. | 새로 시작하는 모든 통합 |
| 커밋 제목 | `<기능 제목> (<feature-id>)`를 사용한다. | 별도 이유는 제시하지 않았다. | squash 커밋 |
| 기존 marker | 신규 marker 형식만 지원한다. | 별도 이유는 제시하지 않았다. | 업데이트 전에 시작된 통합 복구 |
| current spec 언어 | 의미 변경 시 문서 전체를 해당 feature spec 언어로 맞춘다. | 현재 영문 current spec과 한글 feature spec이 불일치하는 문제를 제시했다. | current spec을 변경하는 기능 |
| `No change` 언어 처리 | 언어 차이만으로 current spec을 수정하지 않는다. | 별도 이유는 제시하지 않았다. | 의도 불변 작업 |

## 승인 기준

- 통합 뒤 `validated_main_sha..main`의 커밋 수가 정확히 1이다.
- squash 커밋의 유일한 부모는 `validated_main_sha`이고 tree는 `validated_feature_head`와 동일하다.
- 커밋 제목, feature ID와 `integrated_main_sha`가 승인된 계약과 일치한다.
- feature HEAD와 기존 feature 커밋 이력은 통합 전후 동일하다.
- smoke 실패·stale main·잘못된 marker·commit 실패는 승인되지 않은 `main` 변경이나 local-plan 삭제를 남기지 않는다.
- 새 pending/completion marker 재진입은 동일한 squash SHA를 검증해 완료하거나 안전하게 rollback한다.
- 기존 4필드 marker는 자동 복구하지 않고 저장소와 metadata를 그대로 보존한다.
- 이 기능이 만드는 `current-spec.md`는 한글 서술로 통일되고, 기존 영문 문서의 의미는 명시한 변경 외에 달라지지 않는다.
- 향후 의미 변경이 있는 current-spec 갱신은 feature spec 언어를 따르고, `No change` 작업은 current spec을 수정하지 않는다.
- 독립 리뷰에서 P0–P2 finding이 없고 관련 eval이 모두 통과한다.
