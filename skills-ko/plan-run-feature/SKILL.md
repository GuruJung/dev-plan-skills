---
name: plan-run-feature
description: "기존 기능 계획 계약으로 의사결정이 완료된 계획을 만든 뒤 승인된 같은 대화의 구현 continuation에서 계획 저장과 기능 실행을 연결합니다. 사용자가 Plan 모드에서 '$plan-run-feature'를 명시적으로 호출하거나, 그 호출로 확정된 `execution_handoff: plan-run-feature` 계획을 Default 모드에서 구현하려는 경우에만 사용합니다."
---

# 기능 계획 후 실행

계획은 Plan 모드에서만 만들고 저장과 실행은 Default 모드에서만 수행하세요. 이 스킬은 sibling 스킬의 계약을 복제하지 않고 두 단계로 연결합니다.

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, 기계 판독용 스키마 키는 원형을 정확히 유지하세요.

## Sibling 계약 확인

이 `SKILL.md`의 디렉터리를 기준으로 다음 sibling 파일을 찾으세요.

- `../plan-feature/SKILL.md`
- `../save-approved-plan/SKILL.md`
- `../run-feature/SKILL.md`

현재 단계에 필요한 파일 전체를 읽고 frontmatter `name`이 예상 이름과 같은지 확인하세요. 필요한 sibling이 없거나 잘못됐으면 파일을 찾거나 설치하려고 다른 directory나 catalog를 검색하지 말고 변경 없이 중단하세요.

## Plan 단계

Plan 모드에서 사용자가 `$plan-run-feature`를 명시적으로 호출한 경우에만 이 단계를 시작하세요. 그렇지 않으면 Plan 모드로 전환해 명시적으로 호출하도록 안내하고 중단하세요.

`../plan-feature/SKILL.md`를 완전히 읽고 위임된 호출로 그 계약 전체를 적용하세요. 파일 쓰기, branch 또는 worktree 생성, 구현, 변경을 일으키는 명령을 하지 마세요.

확정 계획에는 기존 frontmatter 필드와 함께 다음 marker를 넣으세요.

```yaml
execution_handoff: plan-run-feature
```

마지막 인용문에서는 사용자가 "Implement this plan"을 선택하면 Default 모드에서 계획을 자동 저장하고 실행한다고 안내하세요. 자동 continuation이 시작되지 않을 때는 Default 모드에서 `$plan-run-feature`를 다시 명시적으로 호출하는 fallback을 함께 제공하세요. Plan 모드에서는 저장이나 실행을 시작하지 마세요.

## Default continuation 단계

다음 조건을 모두 만족할 때만 자동 continuation을 허용하세요.

- Plan 모드가 아닙니다.
- 같은 대화에서 사용자가 `$plan-run-feature`로 해당 계획을 시작했습니다.
- 최신 확정 계획에 `execution_handoff: plan-run-feature`가 있습니다.
- 사용자가 "Implement this plan" 같은 요청으로 그 계획의 구현을 승인했거나 `$plan-run-feature`를 다시 명시적으로 호출했습니다.

조건이 부족하면 계획을 저장하거나 실행하지 마세요. 최신 계획에 marker가 없으면 일반 `$plan-feature` 흐름으로 취급하고 기존 명시적 명령을 안내하세요.

조건을 모두 확인한 직후, metadata를 만들거나 바꾸기 전에 `../save-approved-plan/SKILL.md`와 `../run-feature/SKILL.md`를 각각 완전히 읽고 두 `name`을 검증하세요. 어느 하나라도 누락되거나 잘못됐으면 변경 없이 중단하세요. 아래 저장과 실행 단계에서는 이 사전 검증된 계약을 적용하세요.

## 저장 또는 재사용

먼저 같은 대화에서 이 계획에 대해 성공적으로 저장했다고 보고된 feature ID를 확인하세요. 없으면 계획의 제안 ID를 확인하세요.

기존 feature는 저장된 `plan.md`가 최신 승인 계획에 `save-approved-plan`의 동일한 canonical ID rewrite를 적용한 결과와 같고 handoff marker도 유지될 때만 동일 계획으로 취급하세요. proposed ID를 저장된 state ID로 바꿀 때 frontmatter뿐 아니라 goal objective의 저장 계획 경로처럼 feature ID를 나타내는 모든 필드와 경로를 일관되게 정규화하되, 우연히 같은 문자열을 포함한 무관한 서술은 바꾸지 마세요. 정규화 범위를 명확히 판단할 수 없으면 새 suffix나 metadata를 만들지 말고 불일치를 보여 준 뒤 사용자 선택을 기다리세요. 동일 계획이면 새 suffix나 metadata를 만들지 말고 그 ID를 재사용하세요.

재사용할 feature가 없으면 사전 검증한 `save-approved-plan` 계약을 승인된 handoff의 위임 호출로 적용하세요. collision으로 ID가 바뀌면 저장 결과의 resolved ID를 이후 단계에 사용하세요. 저장이 실패하거나 사용자 선택을 기다리면 실행 단계로 넘어가지 마세요.

## 실행

새로 저장하거나 동일 계획으로 재사용한 feature ID가 있을 때만 사전 검증한 `run-feature` 계약을 승인된 handoff의 위임 호출로 해당 ID에 적용하세요. 재사용한 state가 `integrated`여도 직접 완료라고 보고하지 말고 `run-feature`의 재진입 진단과 Git-source-of-truth 검증을 적용한 뒤 일치할 때만 완료를 보고하세요. 불일치하면 기존 복구 선택 규칙에 따라 중단하세요. 저장과 실행 사이에 추가 확인을 요구하지 마세요.

`save-approved-plan`과 `run-feature`의 안전 중단, 복구 선택, 상태 결속, 독립 리뷰 및 integration 규칙을 그대로 유지하세요. 이 orchestration을 충돌, 불일치, 위험한 결정 또는 명시적 승인 요구를 우회하는 권한으로 취급하지 마세요.
