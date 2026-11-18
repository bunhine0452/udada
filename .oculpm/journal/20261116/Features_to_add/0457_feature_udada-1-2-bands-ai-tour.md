---
schema_version: 1
type: feature
slug: "udada-1-2-bands-ai-tour"
status: done
difficulty: high
created_at: "2026-11-16T04:57:00+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/AITour.swift"
    op: create
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroPages.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: update
  - path: "udada/ios/Udada/Mind/MindView.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/Eval/study_votes.py"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261116/Chores/0403_chore_udada-release-1-0-prepare-1-1-mac.md"
    kind: "followup"
  - ref: "20261116/Features_to_add/0234_feature_udada-meaning-find-precision.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mac"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 1.1 제출, 세 칸 카드와 움직이는 둘러보기

## 추가 기능
사용자(11-16): "응 제출해도되지않을까? 그리고 1.2로 낼테니까 구현시작해" + 앞선 피드백 둘(세 칸이 와닿지 않는다 · 튜토리얼에 모션 그래픽이 없다).

- **심사 제출**: iOS 1.1(빌드 2)과 macOS 1.1(빌드 2)을 App Store Connect 에서 제출. 업데이트 문구의 '치과도 찾아' 줄은 일반 표현으로 바꿨다.
- **세 칸 (iPhone)**: 칸마다 카드 + 큰 가로 제목, 지금 칸은 코발트 테두리·'지금' 표시, 화면 위 하루 띠(`DayRuler` — 찬 정도 막대와 지금 눈금, 누르면 그 칸으로), 남은 일 없는 지난 칸은 한 줄로 접힘.
- **Apple Intelligence 둘러보기** (`AITour.swift`, iPhone·Mac 공용): 일곱 장면이 되풀이되는 모션 그래픽 + 장면마다 'AI 가 하는 일 / 규칙이 지키는 일' + 직접 해 보기. 입구: 소개 4쪽 · 설정 · 비우기 탭 · Mac 메뉴.
- **뜻으로 찾기**: 다섯 번 다 고른 이름은 검사 없이 받는다 — 예시 하루의 '병원 → 치과'가 다시 된다.
- 버전 1.2.

## 검증
- App Store Connect 화면: iOS `1.1 심사 대기 중`, macOS `1.1 심사 대기 중`, 두 번 모두 '1개의 항목 제출됨'.
- `xcodebuild test -scheme UdadaMac`: `Executed 60 tests, with 0 failures` / `** TEST SUCCEEDED **`. iOS 전체: `Executed 47 tests, with 2 tests skipped and 0 failures` + 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **` (새 세 칸·둘러보기 포함한 뒤).
- 뜻으로 찾기(기준 바꾼 뒤): verdict4 `27/31 (87%) · 잘못 0/30`, sense `32/43 (74%) · 0/35`, verdict `27/34 (79%) · 0/29`, verdict2 `21/28 (75%) · 3/26 (11%)`, verdict3 `23/26 (88%) · 1/25 (4%)`. 전부 이미 본 묶음이다 — 새 묶음으로는 안 쟀다.
- 화면: 시뮬레이터에서 새 오늘 화면, 둘러보기 일곱 장면(한 장은 카드가 칸으로 날아가는 도중). Mac 앱에서 '병원 가는 거 뭐 있어' → `‘병원’ — ‘치과’ 오늘 15:00` + 뜻 표시.
- TestFlight 1.2: iPhone `Uploaded Udada` / `** EXPORT SUCCEEDED **`, Mac `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`. 뜻으로 찾기 기준을 바꾼 뒤에는 테스트를 다시 돌리지 않았다(바뀐 파일은 모델 호출부 하나).
- 미확인: 접힌 지난 칸의 모습, 둘러보기 입구 버튼을 눌러 여는 것, Mac 에서 둘러보기가 뜨는 모습, 실제 기기의 움직임 속도. Mac 세 칸은 손대지 않았다.