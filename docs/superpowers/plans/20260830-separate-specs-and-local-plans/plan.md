---
feature_id: 20260830-separate-specs-and-local-plans
title: 지속 명세와 로컬 구현 계획 분리
feature_type: standard
base_branch: main
plan_path: docs/superpowers/plans/20260830-separate-specs-and-local-plans/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---

# 지속 명세와 로컬 구현 계획 분리

## 요약

개발 계획을 Git에 남길 지속 명세와 로컬 실행 계획으로 분리한다. 새 기능별 spec은 변경 의도를 기록하고, 단일 current spec은 현재 유효한 의도를 누적한다. 구현 세부 plan은 Git 공용 metadata에만 보관하고 통합 성공 후 삭제한다.

기존 `docs/superpowers/plans/**`는 변경하지 않는다. 이전 저장 규격의 마이그레이션, 호환, 식별, 전용 오류 처리 및 테스트는 범위에 포함하지 않는다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 문서 역할 | 기능 spec은 변경 의도, current spec은 현재 의도, 코드는 실제 동작, plan은 임시 실행 자료로 구분한다. | 코드에서 복원할 수 없는 장기 의도만 Git에 보존한다. | 신규 계획 |
| plan 보관 | 세부 plan은 로컬 Git 공용 metadata에만 저장한다. | 다른 clone·머신으로의 이관은 지원하지 않는다. | 신규 계획 |
| current spec | `docs/dev-plans/current-spec.md` 단일 파일을 유지한다. | 현재 의도를 조사하는 시작점을 단순화한다. | 신규 명세 |
| 기능 spec | `docs/dev-plans/specs/<id>/spec.md`에 기능별 변경과 결정 이유를 보존한다. | 과거 결정의 맥락을 current spec과 분리한다. | 신규 명세 |
| 초기 범위 | 기존 계획을 옮기지 않고 새 체계 도입 이후의 변경부터 current spec에 누적한다. | 기존 자료를 마이그레이션하지 않는다. | current spec coverage |
| 의도 불변 작업 | 순수 리팩터는 기능 spec에 보존할 불변조건을 기록하되 current spec을 억지로 수정하지 않는다. | 의미 없는 문서 변경을 피한다. | 신규 기능 |
| 이전 규격 | 이전 저장 형식은 식별하거나 별도로 처리하지 않는다. | 지난 규격과 마이그레이션을 고려하지 않는다. | 신규 워크플로 |

## 산출물과 인터페이스

- `$create-dev-plan`의 최종 문서는 `Tracked Feature Spec`과 `Local Implementation Plan`을 구분한다.
  - spec: 요구사항, 비범위, 공개 계약, 제약, 실패 기대, 사용자 결정, 의미 중심 승인 기준
  - plan: 파일·심볼, 내부 구조, 작업 순서, 실행 명령, checkpoint, 실행 budget
- 신규 frontmatter는 `spec_path: docs/dev-plans/specs/<id>/spec.md`, `current_spec_path: docs/dev-plans/current-spec.md`, 로컬 `plan_path`, 기존 handoff와 smoke threshold를 포함한다.
- `$save-dev-plan`은 `<git-common-dir>/dev-plan-workflow/plans/<id>/`에 `spec.md`, `plan.md`, `state.json`을 하나의 staging 디렉터리에서 원자적으로 저장한다.
- `state.json`은 `schema_version: 2`와 `spec_path`, `current_spec_path`를 포함한다. 구현 단계에서는 이 신규 schema와 필수 파일의 존재만 검증하며, 맞지 않으면 일반적인 유효성 오류로 무변경 중단한다.
- 기능 spec에는 current spec에서 추가·교체·제거할 조항을 명시한다. current spec은 연대기가 아니라 현재 유효한 규칙만 유지하고, 최초 생성 시 새 체계 이후의 결정만 다룬다는 coverage를 밝힌다.

## 구현 변경

- `create-dev-plan`은 current spec을 조사 시작점으로 삼고 코드·테스트로 실제 상태를 확인한다. 필요한 결정 근거만 연결된 신규 기능 spec에서 읽는다.
- `save-dev-plan`은 확정 문서에서 tracked spec과 local plan을 분리해 저장하고 worktree·branch·index는 변경하지 않는다. durable/temporary 경계나 current-spec 영향이 불명확하면 내용을 추정하지 않고 재계획을 요구한다.
- 기존 promotion helper는 spec 승격 helper로 교체한다. 임시 `spec.md`만 feature worktree의 신규 경로로 복사해 `docs(spec): add <id>` commit을 만들고, 동일성을 검증한 뒤 임시 spec을 제거한다. 로컬 `plan.md`는 구현·재개를 위해 보존한다.
- `implement-dev-plan`은 schema v2, local plan, 임시 또는 tracked feature spec을 요구한다. plan은 실행 자료로만 사용하고 승인·리뷰 기준은 feature spec과 current spec에서 읽는다.
- 기능 spec의 `Current Spec Impact`에 따라 current spec을 갱신한다. 최신 main과 의미 충돌이 있으면 자동으로 의도를 선택하지 않고 재계획한다.
- 순수 리팩터처럼 current intent가 불변인 경우 feature spec의 명시적 “변경 없음”을 허용한다.
- 통합 성공 후에만 local plan을 삭제한다. 실패·rollback·중단 상태에서는 보존하며, plan이 유실되면 자동 복원하지 않고 명시적인 재계획을 요구한다.
- 이번 기능의 신규 feature spec과 최초 current spec을 추가해 새 계약을 시작한다. 기존 `docs/superpowers/plans/**`는 수정하지 않는다.
- README, 설치 검증, 회귀 검사를 새 경로·schema·helper 이름과 lifecycle에 맞춘다.
- 세 한·영 `SKILL.md` 쌍은 이번 변경에서 한글 파일에 계약을 먼저 반영한 뒤 번역 직전 Git 상태와 mtime을 스냅샷한다. 한글 `M` 파일을 해당 작업의 고정 원본으로 선정해 영어 ASCII 대응본을 동기화하고, 예상 밖 상태가 있으면 중단한다.

## 테스트 및 승인 기준

- 승격 테스트는 spec 전용 commit, 임시 spec 제거, local plan 보존 및 재실행 idempotence를 검증한다.
- destination 충돌, symlink, unrelated worktree 변경, 누락된 신규 필수 파일에서는 tracked·temporary 자료를 덮어쓰거나 삭제하지 않는다.
- 유효하지 않은 schema 또는 신규 필수 파일 누락은 일반적인 저장 기능 유효성 오류로 처리한다. 이전 형식의 명칭·분기·fixture·전용 안내는 추가하지 않는다.
- current spec 갱신이 필요한 기능과 의도 불변 리팩터를 각각 검사한다.
- reviewer가 feature spec의 승인 기준과 `Current Spec Impact`를 실제 diff 및 current spec과 대조하도록 검증한다.
- 통합 성공 때만 local plan이 제거되고 smoke 실패·rollback·중단 시에는 유지되는지 확인한다.
- 기존 `docs/superpowers/plans/**` 파일에 diff가 없고, `skills/` 설치 산출물이 영어 ASCII만 포함하는지 확인한다.
- 번역 대조 후 `scripts/record-skill-sync.sh`를 한 번 실행하고 다음 명령이 모두 exit status 0이어야 한다.

```bash
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/create-dev-plan
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/save-dev-plan
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/implement-dev-plan
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
tests/test-dev-plan-workflow.sh
tests/test-global-skills-install.sh
git diff --check
```

> 호스트의 “Implement this plan” 동작은 Default mode로 전환한 뒤 `<git-common-dir>/dev-plan-workflow/` 아래 임시 저장만 `$save-dev-plan`에 위임합니다. 이 선택은 구현, branch·worktree 생성 또는 `$implement-dev-plan` 실행을 허가하지 않습니다. 사용자가 `$implement-dev-plan 20260830-separate-specs-and-local-plans`를 명시적으로 호출한 뒤에만 구현을 시작합니다. 자동 handoff가 시작되지 않으면 Default mode로 전환해 `$save-dev-plan`을 명시적으로 호출해야 합니다. 계속 계획하는 동안에는 아무것도 저장하지 않습니다.
