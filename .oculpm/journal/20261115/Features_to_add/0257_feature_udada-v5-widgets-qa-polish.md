---
schema_version: 1
type: feature
slug: "udada-v5-widgets-qa-polish"
status: done
difficulty: high
created_at: "2026-11-15T02:57:58+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/UdadaWidgets/TodayWidget.swift"
    op: update
  - path: "udada/ios/UdadaWidgets/NowWidget.swift"
    op: update
  - path: "udada/ios/UdadaWidgets/WidgetParts.swift"
    op: update
  - path: "udada/ios/UdadaWidgets/DayProvider.swift"
    op: update
  - path: "udada/ios/UdadaWidgets/ActivityWidget.swift"
    op: update
  - path: "udada/ios/Shared/DayLogic.swift"
    op: update
  - path: "udada/ios/UdadaTests/DayLogicTests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-widgets-live-controls.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 위젯을 실제 WidgetKit 에서 다듬음

## 추가 기능
하위 세션(Opus 5.5)이 위젯·라이브 액티비티를 실제로 그려 보고 다듬었다. ImageRenderer 하네스(실제 크기·시드 데이터·09:20/14:20/20:30/23:50·빈 날·긴 제목 날) + 시뮬레이터 Springboard UI 테스트(한국어 위젯 갤러리에서 '오늘' 위젯 추가, 네모 누르기, 다이내믹 아일랜드 열기).
- 실제 WidgetKit 에서만 나던 결함: 살아 있는 시간 글자가 HStack 너비를 다 가져가 옆 약속 이름이 사라짐("· 까지 7시간 29분") → 카운트다운과 라벨을 이어 붙인 Text 하나로.
- 카운트다운이 초 단위로 똑딱이던 것(39:50) → 앱과 같은 길이 표기("40분", "1시간 10분"), 분 단위 갱신, 한국어 로캘 고정.
- 틴트 모드에서 꽉 찬 코발트 '적기'·'+'가 글자 없는 덩어리 → 테두리로. 끝낸 줄·보조 글자는 투명도로 위계 유지.
- 작은: "이 틈에" + 다음 약속 전에 들어가는 할 일 네모(바로 누름), 닫기 시각 뒤 "오늘 약속 끝 · N 할 일 남음" + 하루 닫기. 중간: 띠당 3줄, 머리에 "치과까지 40분"/"저녁 약속 끝까지 30분". 큰: 줄 배분(띠마다 1줄 → 다가올 약속 → 지금 띠 → 다가올 띠 → 지난 띠), 8줄(SE 6줄), 빈 날은 세 띠와 "한 줄 적어 봐", 하루 닫기는 20:00(닫기 시각−60)부터.
- 잠금 화면: 직사각 3줄(이름 / "15:00 · 40분 뒤" / "할 일 4개 남음"), 원형은 진행 고리 + 남은 수(다 끝나면 체크), 한 줄은 이름을 줄여 개수가 안 잘리게. 라이브 액티비티: 펼친 아일랜드에 진행 막대, 쉼 카드 설명 2줄, 끝난 쉼은 체크.
- 이어서 내가 고침: 위젯 세션이 짚은 23:50 의 "남은 일이 10분보다 길어. 조금만 해도 돼." → `DayLogic` 에 늦은 밤 갈래(하루 닫기 시각 뒤 + 남은 약속 없음이면 새 일을 권하지 않고 "늦었어. 남은 건 하루 닫기로 자리만 정하자." / 비면 "오늘은 여기까지. 푹 쉬어.").

## 검증
- 하네스 `intent-check: all pass` (네모 → 파일 저장 → 다시 읽기 → 타임라인 반영, 두 번 누르면 되돌림, 반복 하루치는 떼어 내 끝냄, 모르는 id 는 파일 그대로).
- 실제 시뮬레이터: 작은 위젯의 '물 한 잔'을 누르자 앱 그룹 JSON 에 끝낸 하루치가 써지고 모든 위젯이 다시 그려짐(스크린샷 sb/tapm.png), 실제 다이내믹 아일랜드 확인(sb/islm.png).
- `xcodebuild build -scheme Udada -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`. 늦은 밤 갈래: `scratchpad/logic/h/run.sh` → `logic: 68 cases, 0 fail`.
- 미확인: 실제 잠금 화면(simctl 로 못 잠금)의 액세서리 위젯·라이브 액티비티 카드, 실제 틴트·흐림 모드, 큰 위젯의 실제 홈 화면, 제어 센터.