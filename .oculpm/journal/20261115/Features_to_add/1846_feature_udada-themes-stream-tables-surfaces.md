---
schema_version: 1
type: feature
slug: "udada-themes-stream-tables-surfaces"
status: done
difficulty: high
created_at: "2026-11-15T18:46:37+09:00"
session_id: "20261115-004"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/Theme.swift"
    op: update
  - path: "udada/ios/Shared/Model.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/UdadaWidgets/DayProvider.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacKit.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/MenuPanel.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDump.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainFallback.swift"
    op: update
  - path: "udada/ios/Udada/AI/TextScan.swift"
    op: update
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: update
  - path: "udada/ios/Udada/Intents/VisualPlan.swift"
    op: create
  - path: "udada/ios/Udada/Intents/Snippets.swift"
    op: update
  - path: "udada/ios/Udada/Intents/TaskEntity.swift"
    op: update
  - path: "udada/ios/Udada/Today/EditSheet.swift"
    op: update
  - path: "udada/ios/Udada/Info.plist"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/ios/Eval/make_photos3.swift"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/BrainFinishTests.swift"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Features_to_add/1757_feature_udada-say-to-change-commands.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/1615_feature_udada-photo-vision-keep-lines.md"
    kind: "followup"
  - ref: "20261115/Chores/1340_chore_udada-1-0-testflight-app-review.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mac"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 테마 다섯 벌과 AI 가 닿는 자리 여섯

## 추가 기능
사용자(11-15 저녁): 로컬 AI 후보 여섯을 "모두 다 넣어주고 앱 테마를 여러개 만들어", 이어서 "기능이 다 끝나고 테스트올려".

- **테마 다섯 벌** (`Palette` · `ThemeID` · `Ink.theme`): 종이(코발트) · 모래(주홍, 도장은 쪽빛) · 숲(솔잎 초록) · 자두 · 먹(무채색, 도장만 붉게). 테마마다 밝은·어두운 화면. 종이 · 먹 · 강조 하나 규칙은 그대로, 색만 바뀐다. 색 토큰을 정적 값에서 '지금 테마의 값'으로 바꾸고 뿌리 뷰에 `.id(theme)`. 앱 그룹 UserDefaults 에 적어 위젯도 같은 테마. iPhone 설정의 '테마' 칸(견본 + 고르면 설정이 열린 채 다시 그림), Mac 은 창 아래 줄·메뉴 막대 ⋯·보기 메뉴. 기기마다 따로(맞추지 않음). `-udTheme`.
- **흘려 받기** (`Brain.organizeStream`): 규칙 카드가 바로 뜨고 모델이 한 장씩 다듬는 대로 그 조각(`piece`)의 카드만 바뀐다. iPhone 은 '나누는 중' 기다림 화면 없이 바로 첫 장, 이미 넘긴 카드는 안 바꿈.
- **표 읽기** (`TextScan.tableLines` · `BrainRules.tableLines`): Vision 문서 인식의 칸 구조로 주간표(날짜가 머리줄에 가로)와 날짜 칸이 빈 줄을 푼다. 모델 없이도 됨.
- **iPhone 전용 넷**: 시각 지능(`VisualPlan.swift` — `IntentValueQuery` + `SemanticContentDescriptor`, 기기 SDK 에서만 컴파일) · Siri "지금 뭐 해?" 카드 안 끝냄/집중 버튼 · 화면 인식(`appEntityIdentifier`, `TaskEntity: Transferable`) · 위젯 관련도(`WDayEntry.relevance`).

## 막힌 곳
- 흘려 받는 길에 원문을 줘서 점수가 떨어짐(heldout 100% → 92%) → 규칙이 자른 줄을 주게 고침.
- 시뮬레이터 SDK 에 VisualIntelligence 가 없음 → `canImport` + 기기에서만 약하게 링크. `appEntityIdentifier` 는 iOS 18.2+.
- **TestFlight 업로드 실패**: 아카이브(1.1)는 됐으나 내보내기에서 `error: exportArchive Failed to Use Accounts — App Store Connect access for "BP57Z7L498" is required` (두 번). Xcode 의 Apple 계정 로그인이 풀린 것 — 내가 비밀번호를 넣을 수 없다.

## 검증
- `EVAL_STREAM=1 Eval/run.sh fresh`: `stream: 묶음 20 · 첫 카드까지 1ms · 모델이 다듬은 첫 카드 1.0초 · 끝 1.2초`. 흘려 받기와 기존 길의 점수가 다섯 묶음 모두 같음(heldout 50/50, verdict2 잃은 줄 5 · 51/55).
- `Eval/run.sh photos3`: 글자 인식만 `5/13 (38%)` → `13/13 (100%)`. photos 19/19 · photos2 13/15 그대로. (표 그림 3장은 규칙과 같이 그린 것 — 처음 보는 묶음 아님.)
- `xcodebuild test -scheme UdadaMac`: `** TEST SUCCEEDED **`. iOS 전체: `Executed 44 tests, with 2 tests skipped and 0 failures` + 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **` (새 testThemeSwitchKeepsSettingsOpen 포함).
- 빌드: iOS 시뮬 · iOS 기기(시각 지능 포함 — Metadata.appintents 에 SeenPlanValueQuery, VisualIntelligence 약한 링크 확인) · Mac `** BUILD SUCCEEDED **`.
- 화면: Mac 네 테마 스크린샷, iPhone 모래 테마 설정 스크린샷.
- `scripts/archive.sh`: `** ARCHIVE SUCCEEDED **` 뒤 `** EXPORT FAILED **` — **TestFlight 에 안 올라갔다.**
- 미확인: iPhone 전용 넷은 실기기에서 한 번도 안 돌려 봄. 위젯의 테마 적용도 눈으로 못 봄. 흘려 받기의 iPhone 화면(뒤 카드 바꿔 끼우기)은 모델 없는 시뮬이라 규칙 길만 테스트됨.