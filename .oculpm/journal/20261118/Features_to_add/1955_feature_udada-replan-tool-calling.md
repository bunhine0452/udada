---
schema_version: 1
type: feature
slug: "udada-replan-tool-calling"
status: done
difficulty: high
created_at: "2026-11-18T19:55:32+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Replan.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/Find/ReplanView.swift"
    op: create
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/Udada/Today/AIPanel.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/App/DeepLink.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/ReplanTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/Eval/replan.json"
    op: create
  - path: "udada/ios/Eval/replan-verdict.json"
    op: create
  - path: "udada/ios/Eval/score_replan.py"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/design/AI.md"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20261118/Features_to_add/1934_feature_udada-notarized-nightly-film-v2.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/1757_feature_udada-say-to-change-commands.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 도구 호출로 한 주 풀기

## 추가 기능
사용자(11-18): "1번부터 제대로 매우매우 고퀄리티로 만들어" (1번 = "이번 주 너무 빡빡해, 어떻게 하지?"에 답하는 도구 호출 비서).

- **한 주 풀기** (iPhone): 말하면 → 무엇을 봤는지 한 줄씩 → 한 주의 짐 그림이 '지금 ↔ 옮긴 뒤'로 → 옮길 일을 고르고 눌러야 적용(되돌리기 한 번).
- **도구 호출**: 모델에 `seeWeek` · `seeTodos` 를 쥐여 준다. 모델은 미룰 일과 그 자리에서 할 일의 **번호**만 가르고, 어디에 넣을지와 모든 숫자는 `ReplanRules` 가 실제 빈 시간으로 센다. 도구를 안 부르거나 빈손이면 같은 사실을 글로 넣어 주고 다시 묻는다. 모델이 없으면 규칙만으로 같은 화면.
- 모델이 '그 자리에서 해야 한다'고 본 일까지 옮겨야 풀리는 넘침은 풀지 않고, 그 옮김을 꺼 둔 선택지로 보여 준다.
- 입구: 넣기 줄에 "빡빡해 · 넘쳐 · 비워 줘 …" → '풀기' · 말로 하기 · AI 판 맨 위 · 넘치는 칸의 "N분 넘쳐 · 빈 칸으로 풀기" 버튼 · `udada://replan?q=`.

## 동작 흐름
처음 설계(모델이 무엇을 어디로 옮길지까지 정함)는 실제 모델에서 채택 0/17 — 낸 안이 전부 "지금 있는 칸으로" 한 건씩이었다. 맡기는 일을 '가르기'로 줄였더니 도구를 안 부르는 묶음이 5/10. 사실을 넣어 주는 두 번째 길을 붙여서 모델이 낸 옮김 15/19 가 됐다. 자세한 표는 `design/AI.md` 12절.

## 검증
- `Eval/run.sh replan-verdict`(처음 보는 12개, 한 번): `replan 판정: 넘침 풀림 7/9 (77%) · 모델만으로 6/9 · 비우기 2/2 · 지키라는 일 건드림 0 · 필요 없는 옮김 0 · 때가 걸린 일을 미룸 3` — **목표 80% 에 못 닿았다.**
- 같은 묶음 규칙만(`EVAL_NOAI=1`): `넘침 풀림 8/9 (88%) · 때가 걸린 일을 미룸 3`. **모델이 규칙보다 잘 고르지 않았다.**
- `xcodebuild test -scheme UdadaMac`: `Executed 68 tests, with 0 failures` / `** TEST SUCCEEDED **` (새 규칙 테스트 8개).
- iPhone: 단위 `Executed 41 tests, with 0 failures`, UI 5개(한 주 풀기 · AI 판 · 나눠 넣기 · 말로 시키기 · 오늘 흐름) `0 failures` / `** TEST SUCCEEDED **`. 전체 UI 묶음은 다시 안 돌렸다.
- 화면: 시뮬레이터에서 실제 모델로 "오늘 낮이 넘쳐"(1개 옮기면 넘치는 칸이 없어져)와 "오늘은 비워 줘. 메일 답장은 꼭 해야 해"(3개 옮김, 메일 답장 남음)를 띄워 봤다.
- 안 한 것: Mac 화면(규칙·도구는 같이 쓰지만 볼 곳이 없다), Siri 로 부르기, 사용법 장면, 실제 iPhone 에서의 속도. 판정 묶음을 본 뒤 '지난 칸은 넘침으로 안 센다'와 문구를 고쳤고 그 뒤로 평가를 다시 안 돌렸다(평가의 시각은 아침이라 그 고침이 닿지 않는다).