---
schema_version: 1
type: feature
slug: "udada-meaning-find-precision"
status: done
difficulty: high
created_at: "2026-11-16T02:34:20+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/Finder.swift"
    op: update
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacFind.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/Eval/sense-verdict2.json"
    op: create
  - path: "udada/ios/Eval/sense-verdict3.json"
    op: create
  - path: "udada/ios/Eval/sense-verdict4.json"
    op: create
  - path: "udada/ios/Eval/study_votes.py"
    op: create
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261116/Features_to_add/0122_feature_udada-find-by-meaning.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 뜻으로 찾기 잘못 고름을 5% 아래로

## 추가 기능
사용자(11-16): "목표는 5프로야. 무조건 가능하도록해." — 뜻으로 찾기의 잘못 고른 비율을 20% → 5% 이하로.

- 채택한 기준: **낱말로 하나도 못 찾았을 때만** 넓힌다 · 목록 순서 다섯 가지로 물어 **세 번 넘게** 고른 이름 · 그 이름 하나만 놓고 따로 묻는 검사 둘(`Prompt.fits` 참·거짓, `Prompt.unrelated` same·kind·other)을 모두 넘은 것. 갈릴 이름이 없으면 세 번에서 멈춘다. 시계 6초 → 10초.
- 규칙 버그 하나 더: 두세 글자 낱말이 띄어쓰기를 넘어 걸리던 것("제주" ↔ "영양제 주문").
- `-udEvalVotes`(표 수와 검사 답을 적는 연구용 실행) + `Eval/study_votes.py`(기준을 밖에서 견줌).

## 동작 흐름
1. 표 5번 + 검사 하나, 낱말이 맞으면 4표: 조정용 4% · verdict 2% 였으나 새 묶음 verdict2 에서 12%(4/33), verdict3 에서 12%(3/25) — 본 묶음에 맞춘 기준이 새 묶음에서 안 버텼다.
2. 거꾸로 묻는 참·거짓 검사("상관없는 일인가"): 거의 전부 '상관없다' → 못 씀. 셋 중 고르기로 바꾸니 쓸 만함.
3. 낱말이 맞은 물음에서 넓힌 것은 네 묶음 합쳐 틀림 8 · 맞음 4 → 그 경우는 안 넓힌다.

## 검증
- `Eval/run.sh sense-verdict4 | tail -2` (이 기준으로 처음 한 번, 30물음): `상태 ready · 물음 30 · 모델이 고른 물음 15 · 가운데값 3.2초 · 가장 긴 것 8.2초` / `sense: 찾아야 할 것 23/31 (74%) · 잘못 고른 것 0/26 (0%) · 규칙만 7/31 (22%), 잘못 0`.
- 본 묶음: sense `31/43 (72%) · 0/34`, verdict `27/34 (79%) · 0/29`, verdict2 `21/28 (75%) · 3/26 (11%)`(3개 중 2개는 낱말 규칙의 글자 맞음), verdict3 `19/26 (73%) · 1/21 (4%)`. 합치면 4/136 (2.9%).
- 기존 찾기 그대로: `find 22/24 (91%)`, `find-verdict 16/20 (80%)`.
- `xcodebuild test -scheme UdadaMac`: `Executed 51 tests, with 0 failures` / `** TEST SUCCEEDED **`. iOS 시뮬레이터 빌드 `** BUILD SUCCEEDED **`. Mac 아카이브 `** ARCHIVE SUCCEEDED **` → `build/mac/Udada.app` 서명 검증 통과.
- **값을 치렀다**: 찾음 97~100% → 72~79%. 낱말이 맞는 기록이 하나라도 있으면 뜻으로는 안 넓힌다. 가장 긴 것 8초.
- **보장 아님**: 묶음마다 고른 것이 20~30개라 하나 틀리면 4%. verdict2 는 여전히 11%.
- 미확인: 이 마지막 기준으로 앱을 다시 띄워 눈으로 보지는 않았다(앞 기준에서는 확인). iOS 테스트·실제 iPhone 은 안 돌림. TestFlight 는 Xcode 계정 로그인 문제로 여전히 못 올림.