---
schema_version: 1
type: feature
slug: "udada-apple-intelligence-intro"
status: done
difficulty: medium
created_at: "2026-11-15T13:12:53+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Intro/IntroPages.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroView.swift"
    op: update
  - path: "udada/ios/Udada/AI/AIBadge.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacWelcome.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0330_feature_udada-v5-records-settings-polish.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: Apple Intelligence 를 드러내고 첫 안내 추가

## 추가 기능
사용자 요청(11-15): "애플 AI 를 활용한 기능을 더 넣고 내장 AI 를 쓴다는 것을 강조", "앱 처음 시작할 때 튜토리얼 UI". 이전 방침(AIBadge: 'AI 는 뽐내지 않는다', 회색 '기기 안 AI')을 사용자가 뒤집었다 — 이름을 붙여 알리되 코발트 한 색, 그라데이션·빛 번짐 없음은 유지.

- 표시: `AIBadge` → apple.intelligence 기호 + "Apple Intelligence"(코발트 캡슐). 설정 칸 이름·상태 문구도 Apple Intelligence 로. Mac 은 `AppleAIBadge`.
- iOS 소개 5쪽: 4쪽에 'Apple Intelligence가 대신 정리해'(쏟아낸 말 → 카드 3장이 차례로, 이 iPhone 에서 되는지 `Brain.modelStatus()` 한 줄, 없으면 규칙으로 같다고), 마지막 쪽에 'Mac 에서 이어서' 줄.
- Mac 첫 안내 4쪽(`MacWelcome`, seenIntro 가 false 일 때 시트 · ⋯ 메뉴 '쓰는 법 다시 보기'): 메뉴 막대 · ⌃⌥Space(그 자리에서 쳐 볼 수 있음) · Apple Intelligence · iPhone 과 맞추기.
- Mac 에서 새로 쓰는 곳: 쏟아내기 나누기, 집중 띠의 '첫 동작'(처음 보는 일만 모델), 걱정 상자 줄을 누르면 '내 손 안인지 + 한 걸음'(그 걸음을 오늘 할 일로).
- SDK(iOS/macOS 27.2) 에서 확인한 후보, 아직 안 실음: `_Vision_FoundationModels.OCRTool`·그림 입력(사진을 모델에 바로), `SnippetIntent`(Siri 결과 안 버튼), `_CoreSpotlight_FoundationModels`(모델이 내 항목을 검색), `PrivateCloudComputeLanguageModel`(서버 — '기기 안에서만' 약속과 어긋남). AssistantSchemas 에는 할 일 영역이 없다.

## 검증
- `xcodebuild test -scheme Udada -only-testing:…testIntroPagesFirstRun`: `Executed 1 test, with 0 failures` — 카드 '엄마한테 전화하기'가 보이는 것까지 단언, 스크린샷 확인.
- Mac: 안내 1·2·3쪽과 쏟아내기·집중 띠 스크린샷 확인. 이 Mac 은 '이 Mac 에서 바로 돼'.
- 미확인: 걱정 살피기 화면(코드만), 큰 글자·VoiceOver.