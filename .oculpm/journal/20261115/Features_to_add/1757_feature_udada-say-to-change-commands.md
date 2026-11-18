---
schema_version: 1
type: feature
slug: "udada-say-to-change-commands"
status: done
difficulty: high
created_at: "2026-11-15T17:57:30+09:00"
session_id: "20261115-004"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Commander.swift"
    op: create
  - path: "udada/ios/Udada/App/StoreCommands.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacFind.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/CommanderTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/Eval/cmd.json"
    op: create
  - path: "udada/ios/Eval/cmd-verdict.json"
    op: create
  - path: "udada/ios/Eval/score_cmd.py"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Features_to_add/1429_feature_udada-ai-eval-blend-find.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/1615_feature_udada-photo-vision-keep-lines.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 말 한마디로 여러 일을 바꾸는 말로 시키기

## 추가 기능
사용자(11-15): "애플 인텔리전스 활용하는 방법에 대해서 공부해보고 감탄스러운 기능을 추가해줘".

- 공부: iOS/macOS 27.2 SDK 인터페이스를 훑었다 — FoundationModels(도구 호출 `Tool`, 스트리밍, 동적 지시문, 추론 단계, 그림 첨부), AppIntents(`SnippetIntent`, `IntentValueQuery`, 화면 인식 `appEntityIdentifier`), Vision(`RecognizeDocumentsRequest`), VisualIntelligence · RelevanceKit · AlarmKit 프레임워크. 고른 기준: 이 Mac 의 실제 모델로 잴 수 있고, 앞에서 배운 짜임(뼈대는 규칙 · 모델은 읽기만 · 사실은 기록에서)이 맞는 것.
- **말로 시키기** (`Commander.swift` · `Brain.plan`): "치과 내일로 미루고 보고서 초안은 끝냈어, 금요일 3시에 미팅 추가해 줘" → 옮기기·끝내기·넣기·지우기를 한 번에. 조각은 규칙이 자르고, 모델은 줄마다 동작과 가리킨 이름만 읽는다(@Generable — 도구 호출로 모델이 직접 바꾸게 하지 않음). 가리킨 일은 실제 기록에서 찾고(없으면 '못 찾았어'로만), 옮길 곳은 '(으)로'가 붙은 때 낱말만 읽는다. "…은 그대로 둬"는 뺀다.
- **바로 바꾸지 않는다**: '이렇게 할게' 미리보기에서 줄마다 켜고 끄고, 눌러야 한 번에 적용(`Store.apply`, 되돌리기 한 번).
- 화면: '말로 하기'로 합침 — 물음이면 찾기, 시키는 말이면 계획. iPhone `FindView`(달력 탭 돋보기 · `udada://find?q=`), Mac `MacFind`(⌘F · ⌘K · 오른쪽 칸). 넣기 줄(iPhone `QuickAddBar` · Mac `AddField`)에 이미 있는 일을 바꾸라는 말을 쓰면 새 할 일로 넣지 않고 여기로 보낸다.

## 막힌 곳
- Parser 가 "내일로 · 4시로"의 '로'를 못 읽음 → `untagWhen`. 쏟아내기용 '-기' 끊기가 "장보기 | 지워 줘"로 끊음 → 동작·때만 남은 조각은 앞에 다시 붙임. "오늘 저녁으로 당겨 줘"의 '저녁'이 '저녁 약속'을 가리킴(잘못 건드림) → 이름 찾기에서 때 낱말을 뺌.
- 처음 보는 묶음에서 기존 일을 잘못 건드린 2건: "…은 그대로 둬"를 모델이 '끝냄'으로, 문장에 날짜가 둘("오늘 … 수요일 11시로")일 때 앞의 것을 읽음 → keep 낱말 · `destination`.
- 이전 세션이 끝나며 iOS 전체 테스트가 결과 없이 죽어 있었다 → 다시 돌림.

## 검증
- `Eval/run.sh cmd-verdict`(처음 한 번, Mac 실제 모델): `cmd: 문장 통째로 맞음 16/20 (80%) · 동작 맞음 22/25 (88%) · 기존 일을 잘못 건드림 2`, 규칙만 `10/20 (50%) · 16/25 (64%) · 1`. 두 원인을 고친 뒤 `18/20 (90%) · 23/25 (92%) · 0`, 규칙만 `12/20 (60%) · 17/25 (68%) · 0`. 조정용 cmd: 83%→`24/24 (100%) · 34/34 (100%) · 0`. 가운데값 0.7~0.9초.
- `xcodebuild test -scheme UdadaMac`: `** TEST SUCCEEDED **` (CommanderTests 7개 포함).
- `xcodebuild test -scheme Udada`(iPhone 18 Pro 시뮬, 전체): `Executed 43 tests, with 2 tests skipped and 0 failures` + 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **` — 새 `testCommandPreviewThenApply`(미리보기 → 적용 → '2가지를 바꿨어' → 치과가 오늘에서 빠짐) 포함.
- Mac 실제 화면(실제 모델): 네 줄 문장 → 옮기기·끝내기·넣기는 체크, 없는 일 '수영 강습'은 흐리게 '못 찾았어' (스크린샷).
- 못 한 것: 실제 iPhone 의 모델로는 안 쟀다. Siri 로 시키는 인텐트는 안 만들었다(App Shortcut 10개가 다 찼다). 스트리밍·시각 지능·Siri 결과 안 버튼은 공부만 하고 안 실었다. 평가 묶음이 작다(20문장). TestFlight 에 안 올렸다.