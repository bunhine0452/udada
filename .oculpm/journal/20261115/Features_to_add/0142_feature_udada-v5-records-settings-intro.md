---
schema_version: 1
type: feature
slug: "udada-v5-records-settings-intro"
status: done
difficulty: medium
created_at: "2026-11-15T01:42:09+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Records/RecordsView.swift"
    op: create
  - path: "udada/ios/Udada/Records/Stats.swift"
    op: create
  - path: "udada/ios/Udada/Settings/SettingsView.swift"
    op: create
  - path: "udada/ios/Udada/Settings/SettingsSystem.swift"
    op: create
  - path: "udada/ios/Udada/Settings/SettingsAbout.swift"
    op: create
  - path: "udada/ios/Udada/Intro/IntroView.swift"
    op: create
  - path: "udada/ios/Udada/Intro/IntroPages.swift"
    op: create
  - path: "udada/ios/UdadaTests/StatsTests.swift"
    op: create
related: []
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 기록·설정·첫 실행 소개 화면

## 추가 기능
하위 세션(Opus 5.5)이 만든 기록·설정·소개를 탭과 루트에 연결했다.
- 기록 탭: 이번 주 끝낸 일·끝낸 비율(견줄 거리: 플래너 앱 평균 49.5%, Halder 2026 — 목표가 아니라 맥락), 닫은 날·식힌 횟수(맑기 변화)·비운 고리(소음 변화), 예상 대 실제(집중 3번 이상일 때 중앙값), 띠별 막대, 12주 칸, 최근 14일 끝낸 일. `ReflectionCard` 는 지금은 통계로 만든 한 문장(AI 주간 돌아보기로 바꿀 자리).
- 설정(기본 Form 을 종이색으로): 하루 띠 시각·주 시작·기본 길이, 알림(허락 상태 구분, 묶음 3번·약속 미리·걱정 시간·하루 닫기), 기기 달력 연결·달력 고르기, 기기 안 AI, Siri와 단축어 + 숏폼 앞에 잠깐 자동화 안내, 촉감·소리, 화면(기기/밝게/어둡게), 데이터(JSON 내보내기·예시로 채우기·모두 지우기는 확인 창), 정보(근거 보기·소개 다시 보기·위기 연락처).
- 소개 4장: 하루를 세 칸에(진짜 부품 축소판) → 한 줄로 적으면(파서가 실제로 읽는 미리보기) → 비우고 식혀 → 필요한 것만 켜(알림·달력 선택, 예시로 둘러보기). 건너뛰기 가능.

## 검증
- 통계 하네스 `stats: 60 cases, 0 fail`, 우리 프로젝트 `xcodebuild test` 에서 StatsTests 통과, UI 테스트 testTabsAndSettings·testIntroToToday 통과.
- 데이터가 쌓인 기록 화면·큰 글자·어두운 화면은 다듬기 세션에서 확인 중.