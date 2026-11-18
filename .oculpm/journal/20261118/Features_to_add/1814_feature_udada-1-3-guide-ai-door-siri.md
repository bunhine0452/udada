---
schema_version: 1
type: feature
slug: "udada-1-3-guide-ai-door-siri"
status: done
difficulty: high
created_at: "2026-11-18T18:14:47+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/AITour.swift"
    op: update
  - path: "udada/ios/Udada/AI/GuideKit.swift"
    op: create
  - path: "udada/ios/Udada/AI/GuideScenesA.swift"
    op: create
  - path: "udada/ios/Udada/AI/GuideScenesB.swift"
    op: create
  - path: "udada/ios/Udada/Intents/SiriWork.swift"
    op: create
  - path: "udada/ios/Udada/Intents/UdadaShortcuts.swift"
    op: update
  - path: "udada/ios/Udada/Today/AIPanel.swift"
    op: create
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroView.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroPages.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/UI/Kit.swift"
    op: update
  - path: "udada/ios/Shared/Theme.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaTests/SiriWorkTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
related:
  - ref: "20261116/Features_to_add/0457_feature_udada-1-2-bands-ai-tour.md"
    kind: "followup"
  - ref: "20261116/Bugs/0656_bug_udada-motion-nonsense-fixes.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "siri"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 움직이는 사용법·AI 입구·Siri 시키기

## 추가 기능
사용자(11-18): ① Apple 내장 AI 기능이 부족·부실 ② 디자인이 안 부드럽고 불편 ③ 어떻게 쓰는지 모르겠다(정교한 모션그래픽 설명 요구) + "Siri 가 이런 일까지 한다고?" 로 놀라게 하고 싶다.

시뮬레이터로 본 진단: AI 엔진(나누기·시키기·찾기·받기·쪼개기)은 있는데 오늘 화면에 입구가 없었다('말로 하기'는 달력 탭 버튼뿐). 옛 둘러보기는 장면이 작고 카드가 겹쳐 보였다. Siri 는 적기·묻기 수준.

- **움직이는 사용법** (`AITour.swift` 다시 씀 + `GuideKit`·`GuideScenesA/B`): 아홉 장면(적기 · 세 칸 · 끝내고 미루기 · 쏟아내기 · 말로 시키기 · 받은 글과 사진 · Siri · 식히고 닫기 · 기기 안). 장면은 시각 t 의 순수 함수(320×400 고정 좌표, `Beat`)라 손가락이 누르는 순간과 화면의 답이 초 단위로 맞고, 아래 세 줄 설명이 그 대목에서 켜진다. `-udTourPage n -udTourAt 초` 로 어느 순간이든 멈춰 찍는다. matchedGeometry 를 안 써서 겹침이 없다.
- **첫 실행**: 소개 다섯 쪽을 사용법 → '필요한 것만 켜기'로 바꿨다. 입구: 넣기 줄 AI 판 · 빈 날 카드 · 설정 · 비우기 탭.
- **오늘 화면의 AI 입구**: 넣기 줄 왼쪽 Apple Intelligence 버튼 → 판(말로 쏟아내기 · 사진에서 · 물어보거나 시키기 · 받은 글 붙여넣기 · Siri). 한 줄에 여러 일이면 `organizeStream` 으로 나눠 미리 보여 주고 넣는다('한 줄로'로 끌 수 있다). 물음은 찾기로. 할 일 메뉴에 '작게 쪼개기'.
- **Siri** (`SiriWork.swift`): `TellIntent`(한 문장으로 여러 일 — 지우기는 Siri 에서 안 한다) · `SortIntent`(쏟아낸 말을 나눠 넣기 — 버리기 제안은 나중에 함으로, 위기 낱말은 상담 전화만). 앱 단축어 10개 한도라 '쏟아내기'·'말로 쏟아내기'(앱 열기) 문장을 이 둘로 바꿨다.
- **부드럽게**: 카드·지난 칸 테두리를 톤 차이로, 머리 줄·'나중에' 버튼을 옅게, 눌림에 살짝 들어가는 스프링, 모서리 22/16.

## 동작 흐름
넣기 줄에 "엄마한테 전화하고 내일 은행 가야 되고 월세 오르면 어떡하지" → 판에 '3개로 나눠 넣을게'(지금 · 내일 아침 · 걱정 상자) → 넣기 → 되돌리기 토스트.

## 검증
- `xcodebuild test -scheme UdadaMac`: `Executed 60 tests, with 0 failures` / `** TEST SUCCEEDED **` (Mac 앱 빌드 `** BUILD SUCCEEDED **`).
- iPhone 전체 한 번: `Executed 50 tests, with 3 tests skipped and 4 failures` — 넷 다 소개 흐름(바깥 틀의 식별자가 안쪽 버튼 식별자를 덮음 + 옛 흐름을 보던 테스트). 고친 뒤 그 넷과 새 단위 테스트만 다시: 소개 UI 3개 `0 failures`, `testIntroToToday` 통과, 단위 `** TEST SUCCEEDED **`. 고친 뒤 전체를 다시 돌리지는 않았다.
- 화면: iPhone 18 Pro 시뮬레이터에서 아홉 장면을 멈춘 프레임 15장으로 확인, 실제 재생은 2.5초 간격 두 장이 다름. 나눠 넣기 판은 규칙 경로(-udNoAI)로 확인.
- 미확인: 실제 Siri 호출(시뮬레이터에서 안 해 봄), 실제 모델이 붙은 나눠 넣기, AI 판 화면 모습, Mac 에서 사용법 시트(520×760)의 모습, 실제 기기의 속도.