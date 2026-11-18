---
schema_version: 1
type: feature
slug: "udada-breakdown-steps-before-due"
status: done
difficulty: high
created_at: "2026-11-15T20:39:29+09:00"
session_id: "20261115-005"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Breakdown.swift"
    op: create
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/App/StoreCommands.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Today/BreakdownSheet.swift"
    op: create
  - path: "udada/ios/Udada/Today/EditSheet.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacBreakdown.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/BreakdownTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/TodayUITests.swift"
    op: update
  - path: "udada/ios/Eval/steps.json"
    op: create
  - path: "udada/ios/Eval/steps-verdict.json"
    op: create
  - path: "udada/ios/Eval/score_steps.py"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Features_to_add/1846_feature_udada-themes-stream-tables-surfaces.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/1757_feature_udada-say-to-change-commands.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 큰일을 걸음으로 쪼개 마감 전 날에 놓기

## 추가 기능
사용자(11-15 밤): "이런 기능까지 된다고? 라고 할 정도 감탄스러운 기능 또는 AI기능을 추가해줘". 무엇을 넣을지는 내가 골랐다 — **작게 쪼개기**.

- 큰일 하나("금요일까지 발표 준비")를 서너 걸음으로 나누고 **마감 전 날들에 놓는다**. 걸음의 글은 Apple Intelligence, 날은 규칙(`BreakRules.place`): 오늘부터 마감 전날까지 고르게. 큰일은 마감 날에 그대로 남는다.
- 흔한 갈래 일곱(발표·보고서·이력서·시험·이사·여행·청소)은 다듬어 둔 걸음, 처음 보는 일만 모델(`Brain.breakdown`).
- 검사(`BreakRules.clean`): 첫 동작 검사 + 큰일에 없는 날짜 낱말 · 빈 걸음("갱신 완료하기") · 겹침을 뺀다. 셋이 안 남으면 규칙 걸음. 위기 글은 나누지 않고 109 · 1577-0199.
- 미리보기에서 걸음마다 켜고 끄고 글을 고치고 놓는 법(마감까지 고르게 · 하루에 하나 · 오늘 다)을 바꾼다. 눌러야 들어가고 되돌리기 한 번.
- 들어가는 길: iPhone 고치기 화면 '작게 쪼개기'(`BreakdownSheet`), Mac 줄 오른쪽 눌러 '작게 쪼개기…'(`MacBreakdown`). 화면 상태는 `BreakdownDraft` 하나를 같이 쓴다.

## 동작 흐름
지시문 셋을 실제 모델에 견줬다. 규칙만 적은 것은 "이사 준비 → 문 설치하기", "갱신 완료하기" 같은 걸음이 나왔고, 첫·가운데·마지막 걸음의 구실과 예시 둘을 준 쪽을 골랐다. 다섯까지 두면 늘 다섯을 채워 넷까지만.
처음 본 묶음에서 떨어진 "주말농장 신청"은 모델 답이 멀쩡했는데 검사가 이름 속 '주말'을 날짜로 봤다 → 큰일 이름에 있는 낱말은 날짜로 안 본다.

## 검증
- `Eval/run.sh steps-verdict | tail -3` (처음 보는 큰일 20개, Mac 실제 모델): 처음 한 번 `3~5 걸음 20/20 · 모델이 쓴 것 18 · 다듬어 둔 걸음 1 · 규칙으로 떨어짐 1 · 마감 넘긴 걸음 0 · 가운데값 1.0초`, 원인 하나 고친 뒤 `20/20 · 19 · 1 · 0 · 마감 넘긴 걸음 0 · 가운데값 1.1초`.
- `xcodebuild test -scheme UdadaMac`: `Executed 47 tests, with 0 failures` / `** TEST SUCCEEDED **` (BreakdownTests 12개 포함). iOS 전체: UI `Executed 45 tests, with 2 tests skipped and 0 failures`, 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **` (새 testSplitBigTaskIntoSteps 포함).
- 실제로 띄워 봄: Mac 앱에서 금요일 마감 "강아지 예방접종 맞히기" → 시트에 걸음 셋(오늘·모레·목) → ⌘↩ → 저장 파일에 11-15 · 11-17 · 11-19 로 들어감. iPhone 시뮬레이터 스크린샷으로 미리보기 확인.
- **숫자가 못 재는 것**: 처음 보는 묶음의 모델 걸음 68개를 내가 읽고 센 것으로 어색하거나 엉뚱한 걸음이 11개쯤(16%) — "어머니 스마트폰 위치 확인하기", "걸림돌 점검하기". 그대로 다 넣어도 되는 수준은 아니고, 미리보기에서 고치는 것이 전제다.
- 미확인: 실제 iPhone 에서 안 돌려 봄(시뮬레이터는 모델이 없어 다듬어 둔 걸음 길만). TestFlight 에는 안 올렸다(앞 일지의 Xcode 계정 로그인 문제 그대로).