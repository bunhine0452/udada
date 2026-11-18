---
schema_version: 1
type: feature
slug: "udada-reply-with-my-schedule"
status: done
difficulty: medium
created_at: "2026-11-18T20:26:42+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Reply.swift"
    op: create
  - path: "udada/ios/Udada/Find/ReplyView.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/Today/AIPanel.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/App/DeepLink.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/ReplyTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/film/main.swift"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20261118/Features_to_add/2006_feature_udada-live-voice-cards.md"
    kind: "followup"
  - ref: "20261118/Errors/2011_error_udada-1-3-upload-blocked-login.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 받은 약속에 내 일정 보고 답장

## 추가 기능
사용자(11-18): "애플 인텔리전스 x 우다다 = 놀라운 기능, 신기한 어플 이걸 내새워야해 소개영상에도, 그리고 … 진짜 개쩌는 기능 만들어줘. 그리고 로그인해뒀어."

- **받은 약속에 답장**: "금요일 7시에 강남역에서 저녁 어때?"를 공유 · 붙여 넣으면 → 날과 시각을 읽고(만나는 약속의 7시는 저녁 7시) → 내 일정에 댄다(비었나 · 겹치는 약속 · 대신 되는 가장 가까운 때) → 그날의 띠 그림과 함께 답장 두세 개 → 고르면 답장을 복사하고 약속을 넣는다.
- 날 · 시각 · 겹침 · 대안은 전부 규칙(`ReplyRules`)이 실제 기록으로 정한다. Apple Intelligence 는 받은 글의 말투(반말/존댓말)에 맞춰 문장만 쓰고, `vet` 이 다시 본다 — 정해 준 시각 말고 다른 시각을 말하거나 말투가 어긋나거나 수락·거절이 뒤바뀌면 규칙 문장을 쓴다.
- 입구: 받아 둔 것 카드의 '약속을 묻는 글이 있어' · AI 판의 받은 글 붙여넣기 · 넣기 줄에 붙여 넣기('답장') · `udada://reply?text=`.
- 소개 영상의 여는 장면 · 닫는 장면을 'Apple Intelligence × 우다다'로.

## 동작 흐름
실제 모델이 쓴 거절이 "이번에는 어렵다." / "이번에는 어렵습니다."로 딱 잘랐다 — 규칙 문장("미안, 금요일은 어려울 것 같아. 다른 날 보자!")보다 못하다. 거절은 미안함·아쉬움이 있을 때만 모델 문장을 받게 조였다. 수락("금요일 7시 괜찮아.")과 대안("오늘 3시에는 일정이 있어서요, 4시는 어떠세요?")은 쓸 만했다.

## 검증
- `xcodebuild test -scheme UdadaMac`: `Executed 78 tests, with 0 failures` / `** TEST SUCCEEDED **` (ReplyTests 6개).
- iPhone: 단위 `Executed 41 tests, with 0 failures`. UI — `testReplyChecksMyDayThenAddsEvent` 포함 넷 통과, `testTodayAddCompleteSwipeEdit` 는 같이 돌릴 때 한 번 `XCTAssertTrue failed - 옮김 토스트`, 따로 두 번 돌리면 `Executed 1 test, with 0 failures` 두 번 — 밀기 동작이 흔들린다(이번 변경과 무관해 보이지만 원인은 안 팠다).
- 화면: 시뮬레이터에서 실제 모델로 비어 있는 경우 · 겹치는 경우(치과 15:00 → 16:00 제안) · 받아 둔 것 카드를 찍어 봤다.
- 안 한 것: 모델 문장이 검사를 얼마나 넘는지 묶음으로 재지 않았다(화면 두 번이 전부). 실제 공유 확장에서 들어오는 길, Mac 화면, 영상에 이 기능 장면 넣기.
- 걸리는 점: 'Apple Intelligence × 우다다'는 Apple 과 함께 만든 것처럼 읽힐 수 있다 — 스토어 스크린샷·설명에는 이 꼴을 쓰지 않았다.