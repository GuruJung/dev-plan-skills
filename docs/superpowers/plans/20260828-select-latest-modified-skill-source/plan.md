---
feature_id: 20260828-select-latest-modified-skill-source
title: 최신 수정 파일 기반 스킬 원본 선정
feature_type: standard
base_branch: main
plan_path: docs/superpowers/plans/20260828-select-latest-modified-skill-source/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---

# 최신 수정 파일 기반 스킬 원본 선정

## 요약

한글 스킬을 항상 원본으로 보던 정책을 폐기한다. 각 한·영 `SKILL.md` 쌍에서 Git 상태와 파일 mtime을 한 번 스냅샷하여 원본을 선정하고, 반대쪽 파일을 의미와 강도가 같게 동기화한다.

대상은 저장소 기여 지침과 회귀 검사다. 스킬 본문, 동기화 스크립트의 체크섬 계약, 전역 설치 동작은 변경하지 않는다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 원본 선정 범위 | 저장소 전체가 아니라 각 한·영 스킬 쌍별로 원본을 선정한다. | 명시되지 않음 | 기존 `SKILL.md` 쌍 |
| 원본 선정 기준 | Git에서 `M`인 파일만 후보로 삼는다. 한쪽만 `M`이면 그 파일, 양쪽 모두 `M`이면 mtime이 더 최신인 파일을 원본으로 삼는다. | 명시되지 않음 | staged·unstaged 수정 |
| 정책 집행 수준 | 별도 helper나 `record-skill-sync.sh` 자동 판별을 추가하지 않고 지침과 회귀 검사로 집행한다. | 명시되지 않음 | 저장소 작업 정책 |
| 판별 불가 처리 | mtime 동률 또는 판정 후 예상 밖 상태 변화가 있으면 fallback하지 않고 중단하여 사용자에게 원본 선택을 요청한다. | 명시되지 않음 | 원본 판정 실패 |
| 비-`M` 상태 | 추가·untracked·삭제·이름 변경·충돌은 자동 원본 판정에서 제외하고 사용자에게 명시적 선택을 요청한다. | 명시되지 않음 | `A`, `D`, `R`, `U`, untracked 등 |

## 정책 및 구현 변경

- `AGENTS.md`와 `README.md`에서 한글 고정 원본 및 “한글을 먼저 수정” 규칙을 제거한다. 두 경로를 언어별 대응본으로 설명하되, `skills/`가 영어 ASCII 전역 설치 산출물이라는 제약은 유지한다.
- 각 스킬 쌍에 다음 판정 절차를 명시한다.
  1. 번역 전에 `git status --short`와 파일시스템 mtime을 한 번 확인한다.
  2. 정상 후보는 기존 tracked 파일의 ` M`, `M `, `MM` 상태다.
  3. 한쪽만 후보이면 해당 파일을 원본으로 선정한다.
  4. 양쪽 모두 후보이면 스냅샷 시점의 정밀 mtime이 더 최신인 파일을 원본으로 선정한다.
  5. 깨끗한 쌍은 동기화 대상이 아니다. mtime 동률이나 비-`M` 변경은 판정을 중단하고 사용자 선택을 받는다.
- 선정 결과는 해당 동기화 작업이 끝날 때까지 고정한다. 대응본을 저장해 mtime과 Git 상태가 바뀌더라도 원본을 재선정하지 않는다. 원본 파일이나 관련 작업 상태에 예상 밖 변경이 생기면 덮어쓰지 않고 중단한다.
- 한글이 원본이면 영어로, 영어가 원본이면 한글로 의미와 강도를 보존해 번역한다. 명령, 경로, 식별자, enum 값, YAML/JSON 키 보존과 영어 ASCII 제약은 그대로 적용한다.
- 번역 후 양쪽을 대조하고 기존 순서대로 `scripts/record-skill-sync.sh`, `scripts/check-skill-sync.sh`, 관련 테스트를 수행한다. `record-skill-sync.sh`가 한쪽만 변경된 상태를 거부하는 기존 안전장치는 유지한다.
- `tests/test-skill-sync.sh`에 새 양방향 원본 선정 규칙, 스냅샷 고정, 동률·비-`M` 중단 규칙이 활성 지침에 존재하고 기존 한글 우선 문구가 제거됐는지 확인하는 회귀 검사를 추가한다.
- 과거 계획 문서는 당시 결정을 보존하는 기록이므로 수정하지 않는다. 이번 정책이 활성 저장소 지침에서 과거 한글 우선 결정을 대체한다.
- 실제 `SKILL.md`, `skills-ko/.sync-state.sha256`, 동기화·설치 스크립트에는 변경을 만들지 않는다. 따라서 이 정책 변경 자체에는 체크섬 재기록이 필요하지 않다.

## 승인 및 독립 리뷰 기준

- 한글 또는 영문 파일 어느 쪽도 고정 원본으로 취급되지 않는다.
- 영문만 `M`인 경우 영문, 한글만 `M`인 경우 한글이 원본이 된다는 점이 명확하다.
- 양쪽 `M`이면 쌍별 mtime으로 결정하며, 대응본 저장 후 판정을 뒤집지 않는다.
- 동률, 비-`M` 상태, 동시 변경에는 암묵적 언어 fallback이 없다.
- 기존 의미 동등성, 영어 ASCII, 체크섬 무결성 및 전역 설치 계약이 보존된다.
- 독립 리뷰어는 활성 문서 전체에 상충하는 한글 우선 지침이 남지 않았고, 회귀 검사가 위 정책과 기존 한쪽 변경 거부 동작을 함께 보호하는지 확인한다.
- 런타임 API, 보안 경계, 설치 성능, 데이터 마이그레이션에는 영향이 없다.

## 평가 계약

다음 명령은 모두 exit status 0이어야 한다. 현재 기준 실행 시간은 각각 약 0.03초, 0.69초, 0.00초로 확인되어 모두 60초 이내 자동 smoke 후보다.

```bash
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
git diff --check
```

구현 diff에는 `AGENTS.md`, `README.md`, `tests/test-skill-sync.sh`의 정책·검사 변경만 포함되어야 하며, 한·영 스킬 본문과 `skills-ko/.sync-state.sha256`에는 변경이 없어야 한다.

> 호스트의 “Implement this plan” 동작은 Default mode로 전환한 뒤 `<git-common-dir>/dev-plan-workflow/` 아래 임시 저장만 `$save-dev-plan`에 위임합니다. 이 선택은 구현, branch·worktree 생성 또는 `$implement-dev-plan` 실행을 허가하지 않습니다. 사용자가 `$implement-dev-plan 20260828-select-latest-modified-skill-source`를 명시적으로 호출한 뒤에만 feature worktree에서 계획을 `docs/superpowers/plans/20260828-select-latest-modified-skill-source/plan.md`로 승격하고 commit합니다. 자동 handoff가 시작되지 않거나 호스트에 해당 동작이 없다면 Default mode로 전환해 `$save-dev-plan`을 명시적으로 호출해야 합니다. 계속 계획하는 동안에는 아무것도 저장하지 않습니다.
