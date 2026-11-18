---
schema_version: 1
type: feature
slug: "udada-capture-audio-stuck-calm"
status: done
difficulty: high
created_at: "2026-11-16T03:39:25+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Capture.swift"
    op: create
  - path: "udada/ios/Udada/AI/AudioNotes.swift"
    op: create
  - path: "udada/ios/Shared/Inbox.swift"
    op: create
  - path: "udada/ios/UdadaShare/ShareViewController.swift"
    op: create
  - path: "udada/ios/UdadaShare/Info.plist"
    op: create
  - path: "udada/ios/UdadaShare/UdadaShare.entitlements"
    op: create
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Shared/Model.swift"
    op: update
  - path: "udada/ios/Shared/DayLogic.swift"
    op: update
  - path: "udada/ios/Shared/Theme.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: update
  - path: "udada/ios/Udada/Mind/MindView.swift"
    op: update
  - path: "udada/ios/Udada/UI/Kit.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDump.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacKit.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/UdadaMac/Info.plist"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMac.entitlements"
    op: update
  - path: "udada/ios/UdadaMacTests/CaptureTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/TodayUITests.swift"
    op: update
  - path: "udada/ios/Eval/capture.json"
    op: create
  - path: "udada/ios/Eval/capture-verdict.json"
    op: create
  - path: "udada/ios/Eval/audio.json"
    op: create
  - path: "udada/ios/Eval/score_capture.py"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261116/Features_to_add/0234_feature_udada-meaning-find-precision.md"
    kind: "followup"
  - ref: "20261116/Chores/0241_chore_udada-testflight-mac-ios-1-1.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mac"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 밖에서 받기·녹음·넘어온 일·차분한 모션

## 추가 기능
사용자(11-16 새벽): 후보 셋을 "1~3 다 진행하고 마음 편하게 해주는 디자인을 더 … 모션들의 부드러움 이런것도 추가해줘".

- **밖에서 받기** (`Capture.swift` · `Brain.capture`): 남이 보낸 글에서 챙길 일정·할 일만 줄로 뽑아 비우기 적는 칸에 올린다. 뼈대는 규칙(때가 읽히거나 부탁하는 말이 든 문장), 모델은 놓친 것 중 때가 읽히는 것만 보태고 긴 글에서 거른다.
  - iPhone: 공유 확장 `UdadaShare`(글·링크와 같이 온 글·사진·녹음 → 앱 그룹 `Inbox`) → 오늘·비우기 탭의 '밖에서 받아 둔 게 N개 있어' 카드 → 비우기.
  - Mac: 서비스 메뉴 '우다다로 보내기', 비우기 창의 '밖에서 받기'(클립보드 · 녹음 파일), 끌어다 놓기.
- **녹음에서 할 일 찾기** (`AudioNotes.swift`): 녹음 파일을 기기 안에서 받아쓰고(SpeechAnalyzer 파일 입력) 밖에서 받기로.
- **여러 번 넘어온 일** (`Item.moves` · `AppData.stuck`): 세 번 넘게 넘어온 일 하나만 묻는다 — 작게 쪼개기 · 나중에 함 · 버리기 · 그냥 둘게(한 주 쉼).
- **차분한 화면**: 모션 토큰(`Motion` · `.calm`, 동작 줄이기 따름), 잉크가 그어지는 완료 줄(`InkStrike`), 숨 쉬는 먹점(`BreathDot`), 줄이 제자리로 미끄러짐, 다 끝낸 날 '오늘 한 장은 여기까지야.' 카드. 알림 카드는 한 번에 하나, 있으면 오늘 화면이 맨 위에서 열린다.

## 동작 흐름
- 밖에서 받기를 처음엔 모델 중심으로 짰다: 61% · 없는 일 12%. 같은 묶음에서 규칙만 83% → 뒤집었다.
- 녹음: 합성 음성 Flo 는 '견적→병역'으로 받아써 2/9, Yuna 로 바꾸니 9/9. 받아쓰기 품질이 전부를 가른다.
- iPhone 스크린샷에서 카드가 화면 밖(지금 띠로 자동 스크롤)인 것을 보고 고쳤다. 카드 둘이 겹쳐 하루가 밀리는 것도 하나만 보이게.

## 검증
- `Eval/run.sh capture-verdict | tail -2`(처음 한 번): `capture: 받은 것 15/18 (83%) · 날짜·시각 틀림 3 · 없는 일 1/22 (4%) · 규칙만 15/18 (83%), 없는 일 1/22`. 말끝 읽기를 고친 뒤 `18/18 (100%) · 없는 일 0/21`.
- `Eval/run.sh audio`: `받은 것 9/9 (100%) · 없는 일 0/9` (합성 음성 6개).
- `xcodebuild test -scheme UdadaMac`: `Executed 60 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- iOS: 전체 한 번 `Executed 47 tests, with 2 tests skipped and 1 failure`(내가 쓴 새 테스트의 식별자 오타) → 고친 뒤 오늘 묶음 `Executed 16 tests, with 1 test skipped and 0 failures` / `** TEST SUCCEEDED **`, 단위 `Executed 35 tests, with 0 failures`.
- 실제로 띄움: Mac 앱에서 녹음 파일 → '녹음에서 찾음' 두 줄, '메일 답장, 4번 넘어왔어' 카드 (창 스크린샷). iPhone 시뮬레이터에서 받아 둔 것 카드·넘어온 일 카드 (스크린샷).
- TestFlight: iPhone `Uploaded Udada` / `** EXPORT SUCCEEDED **`(아카이브에 UdadaShare.appex 포함), Mac `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`.
- **못 한 것**: 공유 확장을 실제 공유 시트에서 눌러 보지 못했다(받는 코드는 실행 검증 없음 — 보관함 뒤쪽만 UI 테스트). Mac 서비스 메뉴도 다른 앱에서 눌러 보지 못했다. 모션은 움직임을 눈으로 보지 못했다(정지 화면만). 달력·비우기·기록 UI 테스트는 마지막 고침(스크롤·카드 하나만) 뒤에 다시 돌리지 않았다. 밖에서 받기 묶음에서 모델이 보탠 것은 0건이고, 실제 회의 녹음·실제 iPhone 으로는 재지 않았다.