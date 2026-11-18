---
schema_version: 1
type: feature
slug: "udada-v5-day-sheet-app"
status: done
difficulty: superhigh
created_at: "2026-11-15T01:42:07+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/ios/Shared/Model.swift"
    op: create
  - path: "udada/ios/Shared/DayLogic.swift"
    op: create
  - path: "udada/ios/Shared/Theme.swift"
    op: create
  - path: "udada/ios/Shared/DataFile.swift"
    op: create
  - path: "udada/ios/Udada/App/Store.swift"
    op: create
  - path: "udada/ios/Udada/App/DeepLink.swift"
    op: create
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: create
  - path: "udada/ios/Udada/UI/Kit.swift"
    op: create
  - path: "udada/ios/Udada/UI/SwipeRow.swift"
    op: create
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: create
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: create
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: create
  - path: "udada/ios/Udada/Today/EditSheet.swift"
    op: create
  - path: "udada/ios/Udada/Today/LaterSheet.swift"
    op: create
  - path: "udada/ios/Udada/Calendar/CalendarTab.swift"
    op: create
  - path: "udada/ios/Udada/Mind/MindView.swift"
    op: create
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: create
  - path: "udada/ios/Udada/Mind/WorryFlow.swift"
    op: create
  - path: "udada/ios/Udada/Rest/RestView.swift"
    op: create
  - path: "udada/ios/Udada/Rest/FocusView.swift"
    op: create
  - path: "udada/ios/Udada/Rest/CloseDayView.swift"
    op: create
  - path: "udada/ios/Udada/Rest/GateView.swift"
    op: create
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: create
  - path: "udada/ios/Udada/Info.plist"
    op: update
related:
  - ref: "20261114/Features_to_add/1400_feature_udada-day-sheet-proto.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/0059_feature_udada-v5-korean-parser.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: v5를 하루 한 장 구조로 새로 지음

## 추가 기능
사용자 요청(11-15, /loop): 디자인·기능·아주 많은 기능으로 앱스토어 1위, 이어서 "사람들이 가장 편안하게 쓰는 UI로 재탄생, 언제나 UX", "iOS 특화 + 내장 Siri·AI", "아이폰 내장 AI를 가장 잘 활용", "2시간 동안 병렬 세션 제한 없이 최고 품질". v4(기계 디자인) 코드는 `udada/ios/legacy-v4/` 와 `udada/ios-v4-backup-20261115.tgz` 로 보관하고 SwiftUI 앱을 새로 지었다. 최소 iOS 18, Foundation Models 는 약한 링크.

- 디자인 「차분한 종이 시간표」: 연한 회녹색 종이·먹색 글자·코발트 하나(지금·주 동작)·박하(쉼). 고운바탕(2,350자로 잘라 8MB→1.36MB)은 앱이 쓰는 제목·세로쓰기 띠 이름에만, 시각은 SF 좁은 숫자, 본문은 시스템(다이내믹 타입). 그라데이션·그림자·글래스 없음, 층은 톤 차이로.
- 데이터 `Shared/Model.swift`(DayKey·띠·반복 규칙·항목·기록, 새 필드에도 안 깨지는 디코딩), `Shared/DayLogic.swift`(반복 펼치기·떼어 내기·조용히 옮기기·띠 용량·지금 줄), `Shared/DataFile.swift`(앱 그룹 JSON, 못 읽는 파일은 덮지 않고 옆에 보관), `Udada/App/Store.swift`(되돌리기 토스트·딥링크·테스트 시계 `-udNow`·`-udSeed`·`-udOpen`).
- 탭 4개: 오늘(위에 고정된 날짜·주 띠, 세 띠, 지금 줄+시작, 하루 요약, 아래 넣기 줄+식히기) · 달력(월 칸, 고른 날의 세 띠) · 비우기(쓰기·말·사진으로 쏟아내기, 걱정 상자, 나중에 함) · 기록.
- 상호작용: 네모로 끝내기, 오른쪽으로 밀어 끝/왼쪽으로 밀어 내일·나중에, 길게 눌러 메뉴, 끌어서 띠 옮기기, 확인 창 대신 되돌리기. 넣기 줄은 한 줄 읽기 미리보기와 날·때·길이 칩, 엔터 뒤에도 키보드 유지(연속 입력), 여러 줄 붙여넣기.
- 전체 화면 흐름: 고치기 시트(닫으면 저장, 반복은 이날만/전체), 나중에 함(10일 넘으면 묻기), 하루 닫기(내일/나중에/안 해 → 「오늘 끝」 도장), 식히기(1분 숨 진동 박자·3분·10분, 밤색, 맑기 전후, 끝 알림), 집중(위로 세는 시계, 예상 대 실제), 비우기(카드 한 장씩, 제안대로 한 번에, 파쇄, 지금 할 단 하나 꽂기), 걱정 시간(10분, 위기 연락처 109·1577-0199), 숏폼 앞에 잠깐(그냥 가면 15분 통과).
- 하위 세션(Opus 5.5) 병렬: 파서·위젯·서비스/Siri·AI 두뇌·음성/사진·기록/설정/소개 — 각각 따로 기록.

## 검증
- `xcodebuild build` 전체 앱 BUILD SUCCEEDED, iPhone 17 Pro Max(iOS 27.2) 시뮬레이터 `xcodebuild test` → 단위 19개 0 실패, UI 10개(넣기·체크·밀기·되돌리기·고치기·나중에·하루 닫기·식히기·집중·비우기·걱정·잠깐·탭·소개) 통과.
- 스크린샷으로 오늘·달력·비우기·기록·설정·쏟아내기·식히기·닫기·잠깐 확인. 실기기·SE·어두운 화면·큰 글자는 다듬기 세션에서 확인 중. AI 두뇌는 아직 대역(_PendingBrain.swift).