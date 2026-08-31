# 현재 개발 의도

## 적용 범위

이 문서는 2026-08-30 이후 `docs/dev-plans/specs/` 아래의 기능 명세가 도입하거나 수정한
현재 의도에 대해서만 기준이 된다. 이 문서에 없다는 이유로 적용 범위 밖의 제약이
취소되지는 않는다.

## 개발 계획 산출물

- 기능 계획은 지속되는 `Tracked Feature Spec` 내용과 폐기 가능한
  `Local Implementation Plan`을 분리한다.
- 기능 명세는 `docs/dev-plans/specs/<id>/spec.md`에서 추적하며 변경 의도, 사용자 결정,
  결정 이유와 의미 중심 승인 기준을 보존한다.
- 이 파일은 현재 유효한 의도만 담는다. 시간순 기록을 누적하지 않고 폐기된 문장을
  교체하거나 제거한다.
- 로컬 계획은 `<git-common-dir>/dev-plan-workflow/plans/<id>/plan.md`에 추적되지 않은
  상태로 유지하며 성공적인 통합 smoke 뒤에만 삭제한다.
- source code와 tests는 실제 동작의 source of truth이다. 이 문서는 명시된 적용 범위
  안에서 의도의 기준이다.

## 워크플로

- `$create-dev-plan`은 이 파일을 먼저 읽고 코드를 조사하며, 결정 이유가 필요할 때만
  이 파일에서 연결한 관련 기능 명세를 읽는다.
- `$save-dev-plan`은 독립된 `spec.md`, `plan.md`와 schema-v2 `state.json`을 worktree나
  branch를 변경하지 않고 Git 공용 metadata에 원자적으로 저장한다.
- host의 "Implement this plan" 선택은 같은 대화의 최신 확정 계획을 `$save-dev-plan`으로
  저장하고, 저장에 성공한 확정 ID를 `$implement-dev-plan`에 넘겨 추가 확인 없이 구현을
  이어가도록 승인한다. 직접 호출한 `$save-dev-plan`과 `continuation: save-only` 계획은
  저장 전용으로 유지되며, 저장 실패나 불일치 뒤에는 구현을 시작하지 않는다.
- `$implement-dev-plan`은 기능 명세만 승격하고 `Current Spec Impact`를 적용하며 로컬
  계획은 실행 산출물로만 사용한다.
- current spec에 의미 변경을 적용할 때는 기존 내용을 포함한 전체 서술 언어를 해당
  기능 명세의 주된 서술 언어와 맞춘다. `No change`인 기능은 언어 차이만을 이유로 이
  파일을 수정하지 않는다.
- 독립 리뷰와 재검증을 통과한 기능은 검증된 main을 유일한 부모로 하고 검증된 feature
  tree를 그대로 담는 단일 squash commit으로 main에 통합한다. commit 제목은
  `<기능 제목> (<feature-id>)`이며 feature HEAD와 통합된 main SHA를 별도로 기록한다.
- 성공적인 smoke는 로컬 계획을 삭제하기 전에 지속 completion marker를 기록한다.
  state를 terminal로 갱신한 뒤에만 marker를 제거한다.
- 현재 의도가 바뀌지 않는 기능도 보존할 불변조건과 승인 기준을 기능 명세에 기록하지만,
  provenance나 timestamp만을 위해 이 파일을 수정하지 않는다.

이 절의 결정 근거는
[`20260830-separate-specs-and-local-plans`](specs/20260830-separate-specs-and-local-plans/spec.md)와
[`20260830-squash-merge-to-main`](specs/20260830-squash-merge-to-main/spec.md),
[`20260831-chain-save-and-implement`](specs/20260831-chain-save-and-implement/spec.md)이다.
