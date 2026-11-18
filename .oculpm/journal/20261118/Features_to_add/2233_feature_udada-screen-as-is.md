---
schema_version: 1
type: feature
slug: "udada-screen-as-is"
status: done
created_at: "2026-11-18T22:33:43+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Screen.swift"
    op: create
  - path: "udada/ios/Udada/Intents/ScreenIntents.swift"
    op: create
  - path: "udada/ios/Udada/Today/ScreenEntry.swift"
    op: create
  - path: "udada/ios/UdadaMacTests/ScreenTests.swift"
    op: create
  - path: "udada/ios/UdadaTests/ScreenIntentTests.swift"
    op: create
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/Today/AIPanel.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/project.yml"
    op: update
related:
  - ref: "20261118/Chores/2205_chore_udada-wonder-design-probe.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 화면 그대로와 복사 알아보기를 넣었다

## 추가 기능
사용자 결정: "화면 그대로"를 대표 기능으로, 부르는 길은 사용자가 고르게, 문자뿐 아니라 카톡 등도, 시뮬레이터에서 확인.

- `Udada/AI/Screen.swift`(Foundation 만): 글자 조각의 자리로 받은 말과 내가 한 말을 가르고(오른쪽에 붙은 말풍선은 내 말), 보낸 시각 도장·날짜 가름줄·입력칸을 빼고, 가장 최근 제안을 `ReplyRules.offer` 에 넘긴다. 날과 시각이 두 말풍선에 나뉘면 이어 읽는다. 대화가 아니면 `CaptureRules.lines`. 자동으로 넘어온 글의 인증번호·광고·카드 승인·배송 알림은 `isJunk` 로 버린다. 겹침 알림 한 줄 `notice`.
- `Udada/Intents/ScreenIntents.swift`: `ScreenIntent`(화면 그대로 — 그림 또는 글, 결과 카드에 답장 버튼), `CopyReplyIntent`(복사 + 약속 넣기), `ReceiveIntent`(우다다로 받기 — 단축어 자동화용, 받아 두고 알림), `ScreenSnippet`.
- `Udada/Today/ScreenEntry.swift`: 복사한 글 알아보기(`detectedPatterns(for: [\.calendarEvents])` — 붙여넣기 허락 없이), 넣기 줄 위 `ClipChip`, `ScreenSetupView`(스크린샷 골라 해 보기 · 단축어로 거는 법 · 자동화로 받는 법), 확인용 `-udScreen <그림>`.
- Apple Intelligence 판에 "화면 그대로" 줄(`ai.screen`).

## 동작 흐름
단축어 「스크린샷 찍기 → 화면 그대로」를 사용자가 만들고 뒷면 탭·동작 버튼·제어 센터·홈 화면·Siri 이름 가운데 원하는 데 건다. 카톡은 iOS 가 자동으로 글을 넘겨주는 길이 없어 화면 그대로·공유·복사로 받는다. 문자·메일은 단축어 자동화 + 우다다로 받기.

## 시뮬레이터에서 본 것 (iPhone 18 Pro, iOS 27.2)
- 카톡 모양으로 그린 화면 3장을 `-udScreen` 으로: 1:1 대화 → "금요일 19:00 — 비어 있어" 답장 화면, 단체방 꼴 → "내일 15:00 — 비어 있어", 알림톡 꼴 → "11월 20일 오후 2시 스케일링 예약입니다" 가 받아 둔 글로.
- 복사 알아보기: 한국어 약속 글 2개와 영어 1개에서 칩이 뜨고, "ㅋㅋㅋ 진짜? 대박이다" 에서는 안 뜬다.
- 인텐트를 테스트에서 직접 실행(실제 글자 인식): 그림 → 답장 문장, 답장 버튼 → 클립보드 + 약속 1건.
- 시뮬레이터에 단축어 앱이 없다(`ShortcutsActions` 만 있음). 단축어가 스크린샷을 넘기는 것, 결과 카드 버튼, 메시지 자동화는 못 돌렸다.
- PCC: 앱 안에서 부르면 `Fatal error: Missing entitlement: com.apple.developer.private-cloud-compute`. 권한 파일에 임시로 넣고 임시 서명으로 다시 돌리면 죽지는 않고 `LanguageModelError -1` 로 실패. 권한 파일은 되돌렸다.
- 첫 실행에서 찾은 것: 인증번호 문자가 챙길 줄로 잡혔다 → `isJunk` 추가.

## 검증
- `xcodebuild test -scheme UdadaMac`: `Executed 86 tests, with 0 failures` / `** TEST SUCCEEDED **`
- `xcodebuild test -scheme Udada -only-testing:UdadaTests`(시뮬레이터): `Executed 44 tests, with 0 failures` / `** TEST SUCCEEDED **`
- 안 본 것: `ScreenSetupView` 화면 모양, UI 테스트 전체, 실제 카톡 스크린샷(그림은 전부 내가 그린 것).