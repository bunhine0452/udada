---
schema_version: 1
type: feature
slug: "udada-v5-widgets-live-controls"
status: done
difficulty: high
created_at: "2026-11-15T01:42:08+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/UdadaWidgets/UdadaWidgetsBundle.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/DayProvider.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/WidgetParts.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/TodayWidget.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/NowWidget.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/ActivityWidget.swift"
    op: create
  - path: "udada/ios/UdadaWidgets/Controls.swift"
    op: create
  - path: "udada/ios/Shared/WidgetIntents.swift"
    op: create
  - path: "udada/ios/Shared/UdadaActivity.swift"
    op: create
  - path: "udada/ios/Udada/Services/LiveActivity.swift"
    op: create
related: []
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 위젯·라이브 액티비티·제어 센터

## 추가 기능
하위 세션(Opus 5.5)이 만든 위젯 확장 `UdadaWidgets` 를 앱에 연결했다.
- 홈 위젯 `udada.today`: 작은(지금 줄 + 다음 약속 실시간 카운트다운), 중간(세 띠 2줄씩, 누르면 끝나는 네모), 큰(하루 전체, 저녁엔 하루 닫기 링크). 빈 날은 "비어 있어. 한 줄 적어 봐."
- 잠금 화면 `udada.now`: 직사각(다음 약속·카운트다운), 원형(끝낸 비율 게이지), 한 줄("치과 15:00 · 할 일 3"). 강조·흐린 렌더링 모드에선 약속 덩어리를 테두리로.
- 대화형: `Shared/WidgetIntents.swift` 의 ToggleEntryIntent 가 파일을 읽어 끝냄을 바꾸고, 바뀐 것이 있을 때만 저장(못 읽는 파일을 빈 데이터로 덮지 않음). 앱은 활성화될 때 다시 읽는다.
- 라이브 액티비티 `Shared/UdadaActivity.swift`: 식히기는 밤색 카운트다운, 집중은 종이색 위로 세기. 다이내믹 아일랜드 3가지 모양. 앱 쪽 `Udada/Services/LiveActivity.swift` 는 시작 전에 기존 것을 모두 끝낸다.
- 제어 센터(iOS 18): 1분 숨·적기·쏟아내기 → OpenURLIntent 로 udada:// 딥링크.
- 타임라인: 띠 경계·약속 시작/끝/20분 전·자정에 항목(최대 20개).

## 검증
- 하위 세션: 스크래치 프로젝트 `-scheme UdadaWidgets` → BUILD SUCCEEDED, 하네스로 id↔Source 왕복·반복 하루치 끝내기·타임라인 날짜(정렬·24시간·≤20) 확인.
- 통합 후 전체 앱(위젯 포함) 시뮬레이터 빌드 성공.
- 위젯이 실제로 그려진 모습·OpenURLIntent 가 사용자 정의 스킴으로 앱을 여는지는 미확인 → 위젯 QA 세션 진행 중.