---
schema_version: 1
type: feature
slug: "udada-share-auto-add"
status: done
created_at: "2026-11-18T23:06:17+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Screen.swift"
    op: update
  - path: "udada/ios/UdadaShare/ShareViewController.swift"
    op: update
  - path: "udada/ios/Udada/AI/TextScan.swift"
    op: update
  - path: "udada/ios/Udada/Intents/ScreenIntents.swift"
    op: update
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/ScreenTests.swift"
    op: update
  - path: "udada/ios/project.yml"
    op: update
related:
  - ref: "20261118/Features_to_add/2233_feature_udada-screen-as-is.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 공유하면 일정이 바로 들어가고 알린다

## 추가 기능
사용자가 원한 흐름: 화면 그림을 우다다에 공유하면 알아서 일정을 만들고 알림을 보낸다. 그리고 쓸데없는 것까지 일정으로 만든다는 신고(나와의 채팅 스크린샷).

## 재현 (사용자가 준 그림, 시뮬레이터의 실제 글자 인식과 모델)
- 앱의 받은 사진 길(`Brain.readPhoto`, 모델): 맞는 세 줄 + `용량 7.7 MB` + `2026년 11월 18일 수요일>`.
- 지난 턴의 화면 그대로 길: `용량 7.7 MB` 하나만(오른쪽 말풍선을 '내 말'이라고 버려서 정작 일정 세 줄을 놓쳤다).
- 원인: "7.7"이 날짜로 읽힘 · 날짜 가름줄이 이름 없는 일정이 됨 · 나와의 채팅은 전부 오른쪽 말풍선.

## 고친 것
- `ScreenRules.keep`: 화면 껍데기(용량·MB/KB·유효기간·파일 이름·날짜 가름줄), 인증번호·광고, 지난 날, 이름 글자가 둘 미만인 줄을 버리고 같은 날·시각·이름은 한 번만. `strict: false` 면 때가 없는 줄은 둔다(손으로 쓴 목록).
- `ScreenRules.read`: 받은 제안이 없으면 내 말풍선까지 모두 일정 후보로. `events` · `items`(이미 있는 것은 빼고) · `summary`.
- 공유 확장(`UdadaShare`)을 다시 지음: 그림·글에서 일정을 찾아 `DataFile` 에 바로 넣고, 위젯을 새로 고치고, "일정 N개를 넣었어" 알림과 약속 미리 알림을 건다. 받은 약속("금요일 7시 어때?")은 넣지 않고 받아 두고 답장 알림. 못 읽은 사진·녹음은 예전처럼 받아 둔다. 확장에서는 모델을 쓰지 않는다(글자 인식 + 규칙).
- 앱의 받은 사진 길(`DumpFlow`)에도 같은 거르기.
- `TextScan.pieces(in:)` 로 자리 비율 변환을 옮김. 확장 타깃에 Shared 와 규칙 파일 넷 + TextScan 을 넣음.

## 검증
- 사용자가 준 그림을 시뮬레이터에서 새 길로: `["내일 밥먹기", "11월 20일 계획1", "11월21일 오후3시에 강남역에서 만나"]` → 11-19 밥먹기 · 11-20 계획1 · 11-21 15:00 강남역에서 만나. 모델 길도 거른 뒤 같은 세 줄.
- `xcodebuild test -scheme UdadaMac`: `Executed 88 tests, with 0 failures` / `** TEST SUCCEEDED **` (그 화면의 글자 조각을 그대로 옮긴 `testSelfChatWithFileCards` 포함)
- `xcodebuild test -scheme Udada -only-testing:UdadaTests`: `Executed 44 tests, with 0 failures` / `** TEST SUCCEEDED **`
- 못 돌린 것: 공유 확장 자체(공유 시트에서 실행 · 파일 쓰기 · 확장에서 보내는 알림). 빌드만 통과했다. 그림 한 장으로 맞춘 거르기라 다른 화면에서는 모른다.