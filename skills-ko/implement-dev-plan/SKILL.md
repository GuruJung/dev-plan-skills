---
name: implement-dev-plan
description: 저장된 신규 형식의 지속 기능 명세와 로컬 구현 계획을 준비, 구현, 평가, 독립 리뷰, 통합하거나 중단된 구현을 진단하고 재개합니다. 사용자가 기능 ID를 선택적으로 포함해 "$implement-dev-plan"을 명시적으로 호출한 경우에만 사용합니다.
---

# 개발 계획 구현

구현 책임은 foreground 대화에 두세요. 독립 리뷰에만 subagent 하나를 생성하고 별도의 구현 agent를 만들지 마세요.

사용자가 다른 언어를 요청하지 않는 한 질문, 상태 안내와 서술형 산출물에는 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값과 YAML/JSON 키는 원형을 유지하세요.

## 기능 확인

`$implement-dev-plan [<feature-id>]`를 명시적으로 호출한 경우에만 실행하세요. 절대 공용 Git 디렉터리를 확인하고 `<git-common-dir>/dev-plan-workflow/plans/`에서 다음 순서로 ID를 찾으세요.

1. 명시적인 ID
2. 대화에서 가장 최근에 계획, 저장 또는 실행한 기능
3. 현재 등록된 worktree와 연결된 기능
4. terminal 상태가 아닌 유일한 기능
5. 그 외에는 후보를 보여 주고 사용자에게 선택 요청

알 수 없는 ID는 거부하세요. `state.json`에서 `schema_version`이 정확히 `2`이고 `feature_type`이 `standard` 또는 `goal-loop`인지 요구하세요. terminal 상태가 아니면 plain local `plan.md`를 요구하되, plain `integration.complete` marker가 있으면 아래 통합 복구를 위해 plan 부재를 허용하세요. 임시 `spec.md` 또는 state의 `spec_path`에 commit된 tracked spec 중 하나를 요구하세요. 필수 신규 산출물이 없거나 유효하지 않으면 내용을 추정하거나 다른 경로를 찾지 말고 무변경 중단하세요.

## 계획된 기능 준비

상태가 `planned`이면 다음을 수행하세요.

1. 절대 공용 Git 디렉터리와 등록 worktree를 확인합니다.
2. `refs/heads/main` worktree가 정확히 하나인지 찾습니다.
3. `<git-common-dir>/info/exclude`에 `/.worktrees/`를 한 번만 추가합니다.
4. main에 commit이 있고 ignored되지 않은 untracked 파일까지 clean인지 요구합니다.
5. 설정되어 있으면 `origin/main`을 fetch하고, local main이 뒤처졌으면 fast-forward하며 diverge하면 중단합니다.
6. branch는 `feature/<id>`, worktree는 `<main-worktree>/.worktrees/<id>`를 사용합니다.
7. 둘 다 존재하고 일관되게 연결되면 재사용하고, 하나만 있거나 충돌하면 삭제·이동·reset·overwrite하지 않고 중단합니다.
8. 없으면 `git worktree add -b`로 생성합니다.
9. 아래 feature spec 승격을 완료합니다.
10. 상태를 `prepared`로 원자적으로 갱신하고 canonical worktree, branch, spec commit checkpoint와 timestamp를 기록합니다.

준비 후 추가 확인 없이 구현으로 계속하세요.

## Feature Spec 승격

이 SKILL.md 기준 bundled `scripts/promote-spec.sh`를 절대 경로로 호출하세요.

```text
scripts/promote-spec.sh \
  --metadata-dir <git-common-dir>/dev-plan-workflow \
  --feature-worktree <feature-path> \
  --feature-id <id>
```

helper는 Git 공용 metadata와 `plans/<id>`까지 모든 경로 구성요소가 plain directory인지 검증합니다. 임시 `spec.md`를 state의 `docs/dev-plans/specs/<id>/spec.md` 계약 경로로 원자적으로 복사하고, 그 경로만 stage해 `docs(spec): add <id>` commit을 만듭니다. commit과 clean worktree를 검증한 뒤 임시 spec만 제거하고 local `plan.md`는 보존합니다. 다른 change, 충돌 destination, symlink, 누락된 local plan 또는 commit 실패에는 어느 산출물도 덮어쓰거나 삭제하지 않습니다.

재진입 시 tracked spec만 남아 있으면 HEAD에 commit됐는지 확인해 authoritative intent로 사용하세요. 임시·tracked spec이 모두 있으면 helper로 동일성을 확인해 승격을 끝내고, 다르면 중단하세요. 구현과 checkpoint는 spec commit에서 시작합니다.

모든 저장소 읽기, 편집, 명령, 테스트와 commit은 canonical feature worktree에서 수행하고 예상 branch인지 확인하세요.

## Current Spec 적용

구현 전에 tracked feature spec의 `Current Spec Impact`를 읽으세요.

- current spec이 없으면 `docs/dev-plans/current-spec.md`를 만들고 새 체계 이후의 결정만 authoritative하다는 coverage와 승인된 현재 의도를 기록합니다.
- `add`, `replace`, `remove`를 현재 상태 문장으로 적용하고 연대기나 superseded 문장을 남기지 않습니다. 현재 문맥에서 결정 이유가 필요하면 관련 feature spec을 연결합니다.
- `No change`이면 명시된 불변조건을 보존하고 current spec을 수정하지 않습니다.
- 최신 main의 current spec과 의미 충돌이 있으면 어느 의도도 임의로 선택하지 말고 재계획합니다.

## 재진입 진단

새로 준비되고 구현·eval·review 증거가 없으면 첫 실행으로 취급합니다. 그 외에는 다음을 조사하세요.

- local plan, tracked feature spec, current spec과 state
- worktree, branch, HEAD, main과 merge-base
- staged, unstaged, untracked 변경과 merge-base 이후 commit
- authoritative eval·review HEAD
- goal loop native goal 상태
- integration과 rollback 증거

Git을 source of truth로 취급하세요. metadata가 불일치하면 보여 주고 사용자가 복구 동작을 선택한 뒤에만 고치세요. 사용자 승인 없이 feature 작업을 버리거나 reset·제거하지 마세요.

`<git-common-dir>/dev-plan-workflow/integration.pending`이 있으면 다른 통합을 차단하고 matching 기능에는 smoke 재실행 또는 main rollback 선택을 요구하세요.

## 표준 기능 구현

local plan의 실행 범위 안에서 자율적으로 구현하되 feature spec과 current spec을 authoritative intent로 사용하세요. 요구사항 재해석이나 안전하지 않은 결정이 필요하거나 실제로 막히면 질문하세요.

전체 eval을 실행하고 command, result, duration, feature HEAD와 timestamp를 `eval-results.json`에 기록하세요. authoritative review 전에 worktree가 clean이고 commit이 논리적으로 구성되어야 합니다.

## 네이티브 목표 루프

코드를 변경하기 전에 local plan의 완전한 `Goal Contract`와 tracked spec의 target·guardrail을 읽으세요.

goal 도구가 있으면 활성 goal을 확인해 같은 feature ID와 objective이면 채택하고, 완료되지 않은 다른 goal이 있으면 교체하지 말고 pause·clear 또는 중단 선택을 요구하세요. goal이 없으면 승인된 objective로 생성하고 승인된 token 수가 있을 때만 token budget을 전달하세요. 도구가 없으면 정확한 `/goal <objective>`를 출력하고 사용자가 시작할 때까지 기다리세요.

각 실험은 clean baseline 또는 current best checkpoint에서 시작하고 승인된 search space만 바꾸세요. measurement와 guardrail, parameters, metric, duration, budget usage와 HEAD를 기록하세요. 유효한 개선만 best commit으로 보존하고 실패하거나 더 나쁜 agent 소유 변경은 best checkpoint로 복원하세요. 예기치 않은 사용자·동시 변경은 덮어쓰지 마세요.

모든 budget을 강제하세요. target에 도달하지 못한 채 소진되면 complete로 표시하지 말고 재계획 또는 goal pause·edit·clear를 요청하세요. target과 guardrail이 재현 가능하게 검증되면 goal을 complete로 표시하고, token budget이 있으면 goal 도구가 반환한 최종 token usage를 보고한 뒤 전체 feature eval, 독립 리뷰와 통합을 계속하세요.

## Authoritative 결과와 독립 리뷰

eval과 review 결과를 clean feature HEAD에 연결하고 변경이 생기면 stale로 표시하세요. goal loop는 verified best checkpoint에 전체 eval을 다시 실행합니다.

전체 eval 통과 후 구현 context가 격리된 reviewer subagent 하나를 생성하고 다음만 제공하세요.

- tracked feature spec, 관련 current spec과 승인 기준
- comparison ref와 feature HEAD
- 전체 merge diff target
- eval results

reviewer는 read-only로 작업하고 파일 수정, commit, push, comment 게시 또는 위임을 하지 않습니다. 적용되는 `AGENTS.md`, spec, current spec, eval results를 읽고 merge-base부터 feature HEAD까지 전체 diff와 모든 changed path 주변 코드, 관련 테스트와 call site를 조사하세요. 첫 finding을 찾은 뒤에도 전체 diff를 끝까지 확인하고 인용 line은 reviewed diff와 겹치는 최소 범위로 제한하세요.

meaningful correctness·security·performance·maintainability 영향이 있고, 분리 가능하며, 이번 변경이 만들었고, 실제 scenario로 입증되며, 작성자가 고칠 가능성이 높은 문제만 finding으로 보고하세요. 추측, 기존 문제, 의도된 변경과 사소한 style nit는 제외하세요.

finding은 심각도순으로 `[P1] <명령형 제목> - path/to/file:line`과 짧은 근거를 사용하세요. findings 뒤에는 전체 평가, 중요한 test gap이나 residual risk와 명시적인 acceptance decision을 반환하세요. P0는 universal blocker, P1은 urgent, P2는 ordinary defect, P3는 low-impact issue입니다. P0-P2가 없을 때만 accept하세요. P0-P2를 수정한 뒤 영향 eval과 중단 없이 이어지는 같은 review 단계에서는 같은 reviewer recheck를 수행하고, P3는 `review.md`와 state에 기록하되 통합을 막지 않습니다. reviewer를 사용할 수 없으면 통합 전에 중단하세요.

## 최신 main 재검증과 smoke

유일하고 clean인 main worktree를 찾아 설정된 경우 `origin/main`을 fetch하세요. behind면 fast-forward하고 diverge하면 `integration-blocked`로 중단하세요. main이 feature HEAD의 ancestor가 아니면 rebase하고, intent가 바뀌는 conflict는 재계획하세요.

authoritative eval 이후 main이 바뀌면 전체 eval을 재실행하고 effective merge diff가 바뀌면 새 reviewer를 생성하세요. clean하고 평가·승인된 HEAD에만 `integration-ready`, `validated_feature_head`, `validated_main_sha`를 설정하세요.

최신 성공 eval duration과 계획 threshold, 기본 60초를 사용해 threshold 이내의 모든 eval을 자동 smoke로 포함하세요. 적어도 하나가 필요하며 local에서 반복 가능하고 deployment나 되돌릴 수 없는 외부 side effect가 없어야 합니다.

## 통합

bundled helper를 다음과 같이 호출하세요.

```text
scripts/integrate-feature.sh \
  --metadata-dir <git-common-dir>/dev-plan-workflow \
  --feature-id <id> \
  --main-worktree <main-path> \
  --feature-worktree <feature-path> \
  --expected-main <validated-main-sha> \
  --expected-feature <validated-feature-head> \
  --main-branch main \
  --smoke '<command>' [--smoke '<command>' ...]
```

helper는 Git 공용 metadata부터 feature metadata directory까지 모든 경로 구성요소와 local plan이 plain인지 확인합니다. smoke가 모두 통과하면 `integration.complete` marker를 원자적으로 기록한 뒤 local plan과 pending marker를 제거하고 `integrated`를 반환합니다. marker는 validated main·feature HEAD와 worktree를 담아 helper 반환 뒤 state 갱신 전 중단된 경우 같은 인자로 안전하게 `integrated`를 재현합니다. smoke rollback과 marker 작성 전 recovery-required에는 local plan을 보존합니다. 중단된 integration은 같은 인자와 `--recover-pending smoke` 또는 `--recover-pending rollback`을 사용하세요.

`integrated`이면 state를 원자적으로 갱신한 뒤에만 `integration.complete` marker를 제거하고 종료하세요. marker가 남은 재진입은 Git과 marker가 일치할 때 같은 helper call로 결과를 복구하세요. `stale-main` 또는 `not-fast-forward`면 재검증으로 돌아가고, `smoke-rolled-back`이면 `needs-replan`, `recovery-required`이면 main 복구 전 추가 통합 중단으로 처리하세요. terminal 상태에서는 local plan이 없어도 됩니다.

자동으로 push하거나 feature branch·worktree를 삭제하지 마세요. 공유 state는 원자적으로 갱신하세요.
