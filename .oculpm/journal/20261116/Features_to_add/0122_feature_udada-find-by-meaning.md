---
schema_version: 1
type: feature
slug: "udada-find-by-meaning"
status: done
difficulty: medium
created_at: "2026-11-16T01:22:33+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Finder.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacFind.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/Udada/Intents/UdadaIntents.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/FinderTests.swift"
    op: update
  - path: "udada/ios/Eval/sense-records.json"
    op: create
  - path: "udada/ios/Eval/sense.json"
    op: create
  - path: "udada/ios/Eval/sense-verdict.json"
    op: create
  - path: "udada/ios/Eval/score_sense.py"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/scripts/archive.sh"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Features_to_add/1846_feature_udada-themes-stream-tables-surfaces.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 낱말이 달라도 뜻으로 찾는다

## 추가 기능
사용자(11-16): "애플 인텔리전스를 1000% 활용하여 내 앱이 개쩔게", 이어서 "맥북용 앱도 테스트에 넣어줘 · 내가 설치해보고 피드백줄수있게". 무엇을 넣을지는 내가 골랐다 — **뜻으로 찾기**.

- "병원 가는 거 뭐 있어" → 치과 · 내과 검진. 때·상태·종류는 규칙이 먼저 거르고, 모델은 남은 **실제 기록 이름 목록에서 글자 그대로 베껴** 고른다(`FindRules.candidates` → `Brain.aiPick` → `FindRules.trusted`). 목록에 없는 이름은 버린다.
- 목록을 세 가지 순서로 놓고 세 번 물어 두 번 넘게 고른 것만 남긴다.
- 낱말로 찾은 답이 먼저 뜨고, 뜻으로 찾은 줄은 뒤에 '뜻' 표시 + "Apple Intelligence가 뜻으로 찾음". iPhone `FindView` · Mac `MacFind` · Siri 찾기 인텐트.
- 같이 고친 규칙 버그: 한 글자 군말·조사를 낱말 한가운데서 지우던 것(가족→족, 거래처→래처). 한 글자 이름씨(돈·차·책)도 낱말로 받는다.
- `scripts/archive.sh --mac` 추가.

## 동작 흐름
시도한 것과 숫자(조정용 22물음, 찾음 · 잘못 고른 것): 번호로 고르기 74% · 많음 → 이름 베끼기 83% · 27% → 고른 것 다시 묻는 검사 53% · 13% → 뒤집어 두 번 모두 67% · 5% → **세 번 중 두 번 79% · 13~17%(채택)** → 갈래 낱말 먼저 쓰기 81% · 37%(예시가 샘, 버림).

## 막힌 곳
- **TestFlight 업로드 실패(Mac)**: `** ARCHIVE SUCCEEDED **` 뒤 `error: exportArchive Failed to Use Accounts — App Store Connect access for "BP57Z7L498" is required`. Xcode 에 로그인된 Apple 계정이 0개. 어제와 같은 원인이고 내가 풀 수 없다. iOS 는 같은 이유로 다시 시도하지 않았다.
- 대신 아카이브에서 개발 서명된 Mac 앱을 `udada/ios/build/mac/Udada.app` 로 꺼냈다(`codesign --verify` 통과). 이 Mac 에서만 실행된다.

## 검증
- `Eval/run.sh sense-verdict | tail -2` (처음 보는 22물음): `sense: 찾아야 할 것 33/34 (97%) · 잘못 고른 것 9/45 (20%) · 규칙만 10/34 (29%), 잘못 0`. 지시문의 '병원' 예시를 뺀 뒤 `34/34 (100%) · 9/45 (20%)`, 가운데값 2.5초. **잘못 10% 이하 목표는 못 닿음.**
- 기존 묶음 그대로: `find 22/24 (91%)`, `find-verdict 16/20 (80%)`(규칙만 83% · 85%).
- `xcodebuild test -scheme UdadaMac`: `Executed 51 tests, with 0 failures` / `** TEST SUCCEEDED **` (새 4개 포함). iOS 시뮬레이터 빌드 `** BUILD SUCCEEDED **`.
- 실제로 띄움: Mac 앱(예시 하루)에서 "병원 가는 거 뭐 있어" → `‘병원’ — ‘치과’ 오늘 15:00` + 뜻 표시, 창 스크린샷으로 확인.
- 미확인: iOS 단위·UI 테스트는 안 돌렸다. iPhone 화면은 눈으로 못 봄(시뮬레이터에 모델 없음). 실제 iPhone 속도 모름.