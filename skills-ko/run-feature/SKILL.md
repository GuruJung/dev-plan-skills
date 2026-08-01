---
name: run-feature
description: 저장된 표준 또는 목표 루프 기능을 준비, 구현, 평가, 독립 리뷰, 통합하거나 중단된 기능을 진단하고 재개합니다. 사용자가 기능 ID를 선택적으로 포함해 "$run-feature"를 명시적으로 호출한 경우에만 사용합니다.
---

# 기능 실행

구현 책임은 foreground 대화에 두세요. 독립 리뷰에만 subagent 하나를 생성하고 별도의 구현 agent를 만들지 마세요.

사용자가 다른 언어를 명시적으로 요청하지 않는 한 질문, 상태 안내, 서술형 산출물에는 사용자의 현재 대화 언어를 사용하세요. 명령, 식별자, 경로, enum 값, 기계 판독용 스키마 키는 원형을 정확히 유지하세요.

## 기능 확인

`$run-feature [<feature-id>]`를 허용하세요. 다음 순서로 기능을 찾으세요.

1. 명시적인 ID
2. 대화에서 가장 최근에 계획, 저장, 실행한 기능
3. 현재 등록된 worktree와 연결된 기능
4. terminal 상태가 아닌 유일한 기능
5. 그 외에는 후보를 보여 주고 사용자에게 선택 요청

알 수 없는 ID는 거부하세요. `plan.md`와 `state.json`을 읽고 `standard` 또는 `goal-loop`인지 요구하세요.

## 계획된 기능 준비

상태가 `planned`이면 구현 전에 다음과 같이 준비하세요.

1. 절대 공용 Git 디렉터리를 확인하고 `git worktree list --porcelain`을 해석합니다.
2. `refs/heads/main`을 가진 worktree가 정확히 하나인지 찾습니다.
3. `<git-common-dir>/info/exclude`에 `/.worktrees/`를 한 번만 추가합니다.
4. main에 commit이 있고 ignored되지 않은 untracked 파일까지 포함해 깨끗한지 요구합니다.
5. 설정되어 있으면 `origin/main`을 fetch합니다.
6. local main이 뒤처졌으면 fast-forward하고, 같거나 앞서면 계속하며, refs가 diverge하면 중단합니다.
7. branch는 `feature/<id>`, worktree는 `<main-worktree>/.worktrees/<id>`를 사용합니다.
8. 둘 다 이미 있고 일관되게 연결되어 있으면 재사용합니다.
9. 하나만 존재하거나 어느 쪽이든 충돌하면 삭제, 이동, reset, overwrite하지 말고 중단합니다.
10. 그 외에는 `git worktree add -b`로 생성합니다.
11. 상태를 `prepared`로 원자적으로 변경하고 canonical worktree 경로, branch, checkpoint, timestamp를 기록합니다.

준비가 성공하면 추가 확인 없이 바로 구현으로 계속하세요.

저장소 읽기, 편집, 명령, 테스트, commit은 모두 canonical feature worktree를 작업 root로 사용하세요. 변경 전에 예상 branch인지 확인하세요. main은 문서화된 동기화 단계와 통합 helper를 통해서만 수정하세요.

## 재진입 진단

구현, 평가, 리뷰 증거가 없는 새로 준비된 기능은 첫 실행으로 취급하세요. 그 외에는 다음을 조사하세요.

- 계획과 상태
- 등록된 worktree, branch, HEAD, main과의 merge-base
- staged, unstaged, untracked 변경
- merge-base 이후 commit
- authoritative eval 및 review HEAD
- goal loop의 native goal 상태
- integration 및 rollback 증거

Git을 source of truth로 취급하세요. 메타데이터가 일치하지 않으면 불일치를 보여 주고 사용자가 복구 동작을 선택한 뒤에만 고치세요. 변경 보존, checkpoint 생성, eval 재실행, review 재시작, integration 재시도, 재계획 등 관련 선택지를 제시하세요.

명시적인 승인 없이 feature 작업을 버리거나 reset 또는 제거하지 마세요.

`<git-common-dir>/feature-workflow/integration.pending`이 있으면 다른 통합을 차단하세요. 해당 기능에는 다음을 제시하세요.

- `--recover-pending smoke`로 smoke 재실행
- `--recover-pending rollback`으로 main rollback

명시적인 선택을 요구하세요.

## 표준 기능 구현

승인된 계획을 범위 안에서 자율적으로 구현하세요. 요구사항을 재해석해야 하거나, 안전하지 않은 결정이 필요하거나, 진행이 실제로 막혔을 때 사용자에게 질문하세요.

전체 eval 계약을 실행하고 command, result, duration, feature HEAD, timestamp를 `eval-results.json`에 기록하세요. checkpoint commit을 허용합니다. authoritative review 전에 worktree가 깨끗하고 commit이 논리적으로 구성되어 있어야 합니다.

## 네이티브 목표 루프 실행

코드를 변경하기 전에 완전한 `Goal Contract`를 읽으세요.

### 네이티브 goal 설정

1. goal 도구가 있으면 활성 native goal을 조회합니다.
2. 이 기능 ID 및 objective와 일치하면 채택합니다.
3. 완료되지 않은 다른 goal이 있으면 교체하지 마세요. 사용자에게 해당 goal을 pause 또는 clear할지, 이 기능을 중단할지 물으세요. 사용 가능한 goal control을 사용하고, 그렇지 않으면 정확한 `/goal pause` 또는 `/goal clear` 명령을 제공하고 기다리세요.
4. goal이 없으면 승인된 objective로 생성합니다.
5. 계획에 사용자가 승인한 token 수가 있을 때만 token budget을 전달합니다.
6. goal 도구가 없으면 정확한 `/goal <objective>` 명령을 출력하고 사용자가 시작할 때까지 기다리세요.

objective는 비어 있지 않고 4,000자 이하여야 합니다. 자세한 실험 지침은 저장된 계획을 가리키게 하세요.

### 반복

1. 깨끗한 baseline을 측정하고 기록합니다.
2. 각 실험은 현재 best checkpoint에서 시작합니다.
3. 승인된 search space만 변경합니다.
4. measurement와 모든 guardrail을 실행합니다.
5. parameters, metric, guardrails, duration, budget usage, resulting HEAD를 기록합니다.
6. 결과가 유효하고 승인된 comparison 및 tie-breaker에 따라 더 좋으면 best-so-far checkpoint commit을 만들고 상태를 갱신합니다.
7. 그렇지 않으면 기록을 보존하고 agent 소유 실험 변경만 best checkpoint로 복원합니다.
8. 예기치 않은 사용자 또는 동시 변경을 overwrite하지 말고 중단합니다.

선택된 모든 budget을 강제하세요. budget이 소진됐는데 target에 도달하지 못했다면 goal을 complete로 표시하지 마세요. 사용자에게 재계획하거나 goal pause, edit, clear 중 하나를 선택하도록 요청하세요.

target과 guardrail이 재현 가능하게 검증되면 native goal을 complete로 표시하세요. token budget이 있는 goal이면 goal 도구가 반환한 최종 token usage를 보고하세요. 그런 다음 기능의 full eval, independent review, integration을 계속하세요. 이 단계들은 native goal 완료 범위에 포함되지 않습니다.

## Authoritative 결과 연결

authoritative eval과 review 결과를 깨끗한 feature HEAD에 연결하세요. 변경이 생기면 결과를 stale로 표시하세요. goal loop에서는 검증된 best checkpoint를 candidate HEAD로 사용하고 개별 measurement 명령이 이미 통과했어도 전체 feature eval 계약을 실행하세요.

## 독립 리뷰 실행

전체 eval이 통과하면 지원되는 경우 구현 context가 격리된 새로운 reviewer subagent 하나를 생성하고 아래 review 계약을 직접 수행하도록 지시하세요. 다음 정보만 제공하세요.

- `plan.md`와 acceptance criteria
- comparison ref와 feature HEAD
- 전체 merge diff target
- eval results

reviewer는 읽기 전용으로 작업해야 합니다. 파일을 수정하거나 commit, push, review comment 게시, 다른 agent로의 위임을 하지 마세요. 적용되는 `AGENTS.md`, 제공된 계획, acceptance criteria, eval results를 읽으세요.

제공된 feature HEAD와 comparison ref의 merge-base를 계산하고 `git diff <merge-base-sha> <feature-head>`로 실제 병합될 전체 diff를 조사하세요. 모든 changed path의 주변 코드를 충분히 읽고, 첫 문제를 찾은 뒤에도 전체 diff를 끝까지 확인하세요. 관련 테스트와 call site를 조사해 각 finding이 실제이고 actionable한지 검증하세요. acceptance criteria를 독립적으로 확인하고 correctness, security, performance, regression, unsafe behavior, missing tests, maintainability 문제를 찾으세요.

다음 조건을 모두 충족하는 문제만 finding으로 보고하세요.

- 의미 있는 correctness, security, performance 또는 maintainability 영향이 있습니다.
- 분리 가능하고 수정할 수 있습니다.
- 검토 대상 변경으로 인해 새로 발생했습니다.
- 영향받는 scenario나 call path를 코드에서 입증할 수 있습니다.
- 작성자가 알게 되면 고칠 가능성이 높습니다.

추측성 우려, 기존 문제, 의도된 동작 변경, 코드를 이해하기 어렵게 만들지 않는 style nit는 보고하지 마세요.

P0는 보편적인 release blocker 또는 critical failure, P1은 다음에 고쳐야 하는 urgent defect, P2는 고쳐야 하는 일반 defect, P3는 여전히 고칠 가치가 있는 low-impact 문제를 뜻합니다.

findings를 심각도순으로 먼저 제시하세요. 각 finding은 `[P1] <명령형 제목> - path/to/file:line` 형식과 영향받는 scenario 및 잘못된 이유를 설명하는 짧은 단락을 사용하세요. 인용 line은 가능한 한 작고 reviewed diff와 겹쳐야 합니다. qualifying finding이 없으면 만들지 말고 없다고 명시하세요. findings 뒤에는 전체 평가, 중요한 test gap이나 residual risk, 명시적인 acceptance decision을 반환하세요. P0-P2가 남아 있지 않을 때만 accept하고, 그렇지 않으면 reject하세요.

중단 없이 이어지는 한 review 단계에서는 같은 reviewer를 follow-up에 사용하세요. resume 후 사용할 수 없다면 새 reviewer를 만드세요.

- P0-P2를 수정하고 영향받는 eval을 다시 실행한 뒤 recheck를 요청합니다.
- P3는 `review.md`와 `state.json`에 기록하고 integration을 막지 않습니다.
- 남아 있는 P0-P2가 없어야 합니다.

reviewer 기능 자체를 사용할 수 없으면 integration 전에 중단하세요. foreground self-review로 대체하지 마세요.

## 최신 main 기준 재검증

유일하고 깨끗한 main worktree를 찾고 설정된 경우 `origin/main`을 fetch하세요.

- main이 뒤처졌으면 fast-forward
- main이 같거나 앞서면 허용
- local과 origin이 diverge하면 `integration-blocked` 설정

main이 feature HEAD의 ancestor가 아니면 feature를 main 위로 rebase하세요. 계획 범위 안에서 conflict를 해결하고 product intent가 바뀌는 경우 재계획하세요.

authoritative eval 이후 main이 변경됐으면 다음을 수행하세요.

1. 전체 eval 계약 재실행
2. effective merge diff 비교
3. diff가 바뀌었으면 새로운 reviewer 생성
4. diff가 같을 때만 이전 review 유지

깨끗하고 전체 평가와 승인을 받은 HEAD에만 `integration-ready`, `validated_feature_head`, `validated_main_sha`를 설정하세요.

## 병합 후 smoke 선택

최신 성공 eval duration과 계획의 threshold, 기본 300초를 사용하세요.

- `always`: duration과 관계없이 포함
- `never`: 제외
- `auto`: threshold 이내일 때만 포함

적어도 한 명령을 요구하세요. Smoke는 local에서 반복 가능해야 하며 deployment 또는 되돌릴 수 없는 외부 side effect가 없어야 합니다.

## 통합

이 SKILL.md를 기준으로 bundled helper를 찾아 절대 경로로 호출하세요.

```text
scripts/integrate-feature.sh \
  --main-worktree <main-path> \
  --feature-worktree <feature-path> \
  --expected-main <validated-main-sha> \
  --expected-feature <validated-feature-head> \
  --main-branch main \
  --smoke '<command>' [--smoke '<command>' ...]
```

중단된 integration에는 같은 식별 인자와 smoke 명령을 사용해 `--recover-pending smoke`를 지정하거나 `--recover-pending rollback`을 지정하세요.

결과를 다음과 같이 해석하세요.

- `integrated`: 상태 갱신 후 종료
- `stale-main` 또는 `not-fast-forward`: main 재검증으로 복귀
- `smoke-rolled-back`: `needs-replan` 설정, feature 보존, 변경 전에 아이디어 검토
- `recovery-required`: main 복구 전까지 추가 integration 중단

자동으로 push하거나 feature branch를 삭제하거나 worktree를 제거하지 마세요. 공유 상태 갱신은 모두 원자적으로 작성하세요.
