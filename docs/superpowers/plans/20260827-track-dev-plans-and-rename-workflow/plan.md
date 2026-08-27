---
feature_id: 20260827-track-dev-plans-and-rename-workflow
title: 개발 계획 문서 추적 및 workflow namespace 개편
feature_type: standard
base_branch: main
plan_path: docs/superpowers/plans/20260827-track-dev-plans-and-rename-workflow/plan.md
smoke_threshold_seconds: 60
execution_handoff:
  skill: save-dev-plan
  authorization: explicit-user-selection
  automatic_trigger: implement-this-plan
  continuation: save-only
---

# 개발 계획 문서 추적 및 workflow namespace 개편

## 요약

- 계획은 Git 공용 메타데이터에 임시 저장한 뒤 feature worktree에서 tracked 문서로 승격한다.
- Git 메타데이터와 전역 설치 namespace를 `dev-plan-workflow` 이름으로 통일한다.
- 모든 신규 계획에 과거 기능 계획에서 참고할 수 있는 사용자 결정 사항을 기록한다.

## 사용자 결정 사항

| 주제 | 사용자 결정 | 이유·tradeoff | 적용 범위 |
|---|---|---|---|
| 계획 추적 시점 | `$save-dev-plan`은 임시 저장만 하고 `$implement-dev-plan`이 feature branch에서 계획을 commit한다. | main을 dirty하게 만들지 않고 save-only 계약을 유지한다. | 신규 계획 |
| main 노출 | 통합된 기능의 계획만 main에 남긴다. | 명시되지 않음 | 신규 계획 |
| 기존 계획 | 기존 `20260827-rename-dev-plan-skills` 계획은 tracked 문서로 이관하지 않는다. | 명시되지 않음 | 기존 자료 |
| Git 메타데이터 | `<git-common-dir>/feature-workflow/`를 `dev-plan-workflow/`로 원자적으로 이전한다. | 명시되지 않음 | 기존·신규 상태 |
| 설치 namespace | 백업 경로, 환경변수, marker와 lock도 `dev-plan-workflow` 이름으로 변경한다. | 전체 내부 이름을 일관되게 만든다. | 설치·제거 워크플로 |
| 레거시 호환 | 이전 설치 namespace에 대한 alias, fallback과 백업 이관을 제공하지 않는다. | 명시되지 않음 | 설치 인터페이스 |

## 구현

- `create-dev-plan`은 관련 과거 계획의 사용자 결정을 조사하고, 모든 신규 계획에 localized
  사용자 결정 섹션과 `plan_path`를 포함한다.
- `save-dev-plan`은 계획과 상태를 `<git-common-dir>/dev-plan-workflow/features/<id>/`에
  원자적으로 저장하되 worktree, index와 branch는 변경하지 않는다.
- `implement-dev-plan`은 feature worktree를 만든 뒤 계획을
  `docs/superpowers/plans/<id>/plan.md`로 승격하고 계획 파일만 포함하는
  `docs(plan): add <id>` commit을 만든다. commit 검증 후에만 임시 계획을 제거한다.
- legacy Git 메타데이터는 두 namespace 충돌이나 pending integration이 없을 때만 전체
  디렉터리를 원자적으로 이동한다. 가변 상태와 integration recovery 자료는 새 Git 공용
  디렉터리에 계속 보관한다.
- 설치 기본 백업 경로, 환경변수, marker, transaction과 lock을 각각
  `~/.agents/skill-backups/dev-plan-workflow/`, `DEV_PLAN_WORKFLOW_*`,
  `.dev-plan-workflow-*`로 변경한다. 이전 설치 namespace는 지원하거나 이전하지 않으며,
  이전 환경변수는 의도치 않은 기본 경로 사용을 막기 위해 오류로 거부한다.
- 한글 스킬 원본을 먼저 변경하고 영어 ASCII 설치본을 같은 의미와 강도로 동기화한다.

## 승인 기준

- save 단계 후 main이 깨끗하고 계획과 상태가 새 Git 공용 경로에만 임시 저장된다.
- implement 준비 후 계획 전용 commit이 생성되고 임시 계획이 제거되며, 통합 전에는 main에
  계획이 나타나지 않는다.
- 계획 승격과 메타데이터 migration은 충돌, symlink, unrelated worktree change와 pending
  integration을 덮어쓰지 않는다.
- 모든 신규 계획에 사용자 결정 사항이 기록되고 이후 계획 조사 계약에 포함된다.
- 설치·제거, rollback, concurrency와 백업 보존이 새 namespace에서 동작한다.

## 평가 계약

다음 명령은 모두 exit status 0이어야 한다. 모든 명령은 60초 이내 실행되는 자동 smoke
후보다.

```bash
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/create-dev-plan
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/save-dev-plan
python ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/implement-dev-plan
scripts/check-skill-sync.sh
tests/test-skill-sync.sh
tests/test-dev-plan-workflow.sh
tests/test-global-skills-install.sh
```

`scripts/record-skill-sync.sh`는 한글·영문 스킬을 대조한 뒤 평가 전에 한 번 실행한다.
