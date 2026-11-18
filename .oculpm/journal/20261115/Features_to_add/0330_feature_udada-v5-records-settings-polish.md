---
schema_version: 1
type: feature
slug: "udada-v5-records-settings-polish"
status: done
difficulty: high
created_at: "2026-11-15T03:30:03+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Records/RecordsView.swift"
    op: update
  - path: "udada/ios/Udada/Records/Stats.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroView.swift"
    op: update
  - path: "udada/ios/Udada/Intro/IntroPages.swift"
    op: update
  - path: "udada/ios/Udada/Intents/SiriTips.swift"
    op: update
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: create
  - path: "udada/ios/Udada/Info.plist"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-records-settings-intro.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 기록·설정·소개 다듬고 AI·Siri 연결

## 추가 기능
하위 세션(Opus 5.5)이 기록·설정·소개를 다듬고 연결했다.
- 기록: 한 주 카드(끝낸 일 큰 숫자 + 지난주, 끝냄/남음 막대와 %, "플래너 앱에서도 보통 절반쯤 끝내 (평균 49.5%, Halder 2026)", 닫은 날·식힌 횟수·비운 고리; 큰 글자에선 세로로), 띠별 끝낸 일(가장 많은 띠 강조), 예상 대 실제(비율 + 기본 길이 기준 "30분 → 39분" 막대 + 최근 3번; 3번 미만이면 얻는 법 안내), 12주 칸(월·요일 라벨, 오늘 코발트 테두리, 범례, VoiceOver 는 한 주씩). 이번 주 한 줄은 틀 문장(AI 배지 없음).
- 버그: 지난주 끝낸 비율이 늘 100% — settle 이 지난주 안 끝낸 일을 오늘로 옮기니 비교가 의미 없어 지움. `udada://settings` 첫 실행에서 시트가 가끔 안 뜸 → 기록이 뜬 0.35초 뒤 로컬 상태로. 소개 다시 보기는 설정 시트가 다 닫힌 뒤. 소개의 '예시로 채워서 둘러보기'가 사용자 항목을 덮어쓰던 것 → 항목이 없을 때만.
- 설정: AI 줄은 `Brain.shared.status`("✓ 켜져 있어 · 기기 안에서만 처리해"/꺼짐/한국어 이유), 모델이 하는 일(정리 제안·첫 동작·걱정 상자·한 줄 읽기)과 '말과 사진'(AI 스위치와 무관) 구분, 하루 요약·한 주 한 줄은 규칙이라고 각주. Siri 칸에 SiriTipCard(시스템 팁 + ShortcutsLink)와 UdadaShortcuts 와 맞춘 문구 4개. 동작 줄에 아이콘, 설정 시트 안에서도 토스트(예시로 채우기 되돌리기가 보이게).
- 소개: 1장 코발트 지금 줄이 할 일을 체크하면 바뀜, 3장 숨 막대(동작 줄이기 존중), 4장 권한 없는 Siri 줄, 권한은 누를 때만. 큰 글자에서 "10:0/0" 줄바꿈과 '켜짐'이 줄을 누르던 것 고침.
- 이어서 내가: 단축어 링크가 "Udada 단축어"로 보이던 것 → `CFBundleName` 을 우다다로. UI 테스트용 `-udNoAI`(시작 때 AI 끔) — SE 시뮬레이터에서 실제 모델이 돌아 정리가 10초를 넘겨 `testDumpSortFinish` 가 실패했기 때문.

## 검증
- 하위 세션 `xcodebuild test`: RecordsUITests 9/9(Pro Max·SE), FlowUITests Pro Max 10/10 · SE 9/10(testDumpSortFinish "안 보임: sort.card" — 위 -udNoAI 로 대응, 최종 전체 실행에서 다시 판정), 단위 35/35.
- 스크린샷: 전후 비교, 어두운 화면, SE 큰 글자(scratchpad/records/shots/). 시뮬레이터·파생 데이터는 하위 세션이 지움(남은 2.2MB).
- 미확인: ShortcutsLink·SiriTipView 실제 탭, 실기기 AI 상태 문구, VoiceOver 손 점검.