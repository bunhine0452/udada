---
schema_version: 1
type: feature
slug: "udada-v5-notify-calendar-siri"
status: done
difficulty: high
created_at: "2026-11-15T01:42:09+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/NotifyPlan.swift"
    op: create
  - path: "udada/ios/Udada/Services/Notifier.swift"
    op: create
  - path: "udada/ios/Udada/Services/NotificationRouter.swift"
    op: create
  - path: "udada/ios/Udada/Services/CalendarService.swift"
    op: create
  - path: "udada/ios/Udada/Intents/UdadaIntents.swift"
    op: create
  - path: "udada/ios/Udada/Intents/TaskEntity.swift"
    op: create
  - path: "udada/ios/Udada/Intents/UdadaShortcuts.swift"
    op: create
  - path: "udada/ios/Udada/Intents/FocusFilter.swift"
    op: create
  - path: "udada/ios/Udada/Intents/GatePass.swift"
    op: create
  - path: "udada/ios/Udada/Intents/IntentData.swift"
    op: create
  - path: "udada/ios/Udada/Intents/SiriTips.swift"
    op: create
  - path: "udada/ios/UdadaTests/NotifyPlanTests.swift"
    op: create
  - path: "udada/ios/UdadaTests/IntentsTests.swift"
    op: create
related: []
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 알림·기기 달력·Siri 단축어 연결

## 추가 기능
하위 세션(Opus 5.5)이 만든 서비스·App Intents 를 앱에 연결했다.
- 알림 `Shared/NotifyPlan.swift`(순수 계산) + `Udada/Services/Notifier.swift`: 띠마다 묶음 알림(하루 3번, Fitz 2019 — 그 띠에 할 일이 있을 때만), 약속 미리 알림(7일), 걱정 시간(상자가 비지 않았을 때), 하루 닫기 알림(선택). id 접두 `ud5.`, 최대 60개, 저장할 때마다 0.8초 몰아서 다시 건다. 알림 권한은 처음 약속을 넣거나 날짜를 정할 때 묻는다.
- `NotificationRouter`: 앱이 떠 있을 땐 약속만 배너, 누르면 딥링크로 그 화면.
- 기기 달력 `CalendarService`(EventKit, 읽기 전용): 종일·여러 날 일정, 달력별 숨기기, 바뀌면 자동 새로 고침. 띠에는 옅은 바탕 + 달력 색 줄.
- Siri·단축어 9개(`Udada/Intents/`): 우다다에 적어 줘(파서로 읽어 넣고 "내일 15:00에 넣었어 · 치과"), 지금 뭐 해, 오늘 할 일, 끝냈다고 표시(TaskEntity), 숨 고르기·멀리 보기·걷기, 쏟아내기(말로 포함), 하루 닫기, 숏폼 앞에 잠깐(GatePass 15분 통과, gateOn 꺼짐이면 조용히 끝).
- TaskEntity = AppEntity + IndexedEntity, Spotlight 색인(`Store.afterPersist` 훅으로 저장마다 갱신, Spotlight 결과를 누르면 그 날짜로). 집중 모드 필터(걱정 알림 끄기·묶음만·나중에 숨기기) — 오늘 화면이 따른다.

## 검증
- 알림 계획 하네스 `notify: 26 cases, 0 fail`. 우리 프로젝트 `xcodebuild test` 에서 NotifyPlanTests·IntentsTests(7) 통과. App Shortcuts 메타데이터 추출 통과(하위 세션 스크래치 빌드).
- 실제 Siri 음성 인식, Spotlight 탭, 집중 모드 필터, 실제 달력 데이터는 실기기에서 미확인.