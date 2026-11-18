---
oculpm_plan: v1
id: udada-v5-comfort
title: "우다다 v5: 편안한 UI로 재탄생"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

기계(v4) 디자인을 버리고 '하루 한 장' 구조로 앱 전체를 새로 짓는다. iOS 익숙한 패턴 + 부드러운 종이 시간표. 사용자 요청(11-15): 가장 편안한 UI, 언제나 UX, 아주 많은 기능, 앱스토어 1위.

**완료 조건:** 새 디자인 우다다에서 한 줄 넣기·끝내기·미루기·식히기·하루 닫기·비우기가 돌고, 위젯·기기 달력·알림이 붙은 빌드가 SE·Pro Max UI 테스트를 통과해 TestFlight에 올라간다
**확인 명령:** cd udada/ios && xcodebuild test -project Udada.xcodeproj -scheme Udada -destination "id=$SE" -destination "id=$PM" 2>&1 | tail -1

## 기반 {#base}
- [x] 디자인 시스템: 색·글꼴·부품 {#design}
- [x] 데이터 모델·저장 (앱 그룹 공유) {#model}
- [x] 한국어 한 줄 읽기와 테스트 {#parser}
- [x] 반복 일정 규칙 {#repeat}

## 오늘 {#today}
- [x] 세 띠·지금 줄·띠 용량 {#bands}
- [x] 한 줄 넣기: 미리보기·칩·연속 입력 {#quickadd}
- [x] 고치기 시트·밀어서 끝/미루기·메뉴 {#edit}
- [x] 끌어 옮기기 {#drag}
- [x] 나중에 함 (10일 넘으면 묻기) {#later}
- [x] 하루 닫기와 도장 {#close}

## 머리 {#mind}
- [x] 비우기: 쏟아내기→한 장씩→파쇄 {#dump}
- [x] 걱정 상자와 걱정 시간 {#worry}
- [x] 식히기: 숨·멀리 보기·걷기, 맑기 전후 {#rest}
- [x] 집중: 하는 중 시계, 예상 대 실제 {#focus}

## 연결 {#system}
- [x] 기기 달력 약속을 띠에 {#eventkit}
- [x] 알림: 약속·하루 3번·걱정 시간 {#notify}
- [x] 위젯: 홈·잠금 화면·대화형 {#widgets}
- [x] 라이브 액티비티: 식히기·집중 {#live}
- [x] 단축어·Siri (App Intents) {#intents}

## 달력·기록·설정 {#more}
- [x] 달력 탭: 월 보기와 날짜별 {#calendar}
- [x] 기록: 주간 돌아보기·예상 대 실제 {#insights}
- [x] 설정: 띠 시간·알림·달력·외관·내보내기 {#settings}
- [x] 첫 실행 소개, 권한은 필요할 때 {#intro}

## 출시 {#ship}
- [x] 새 앱 아이콘 {#icon}
- [x] 접근성: 글자 크기·VoiceOver {#a11y}
- [x] UI 테스트 SE·Pro Max {#uitest}
- [x] 스크린샷으로 디자인 점검 {#shots}
- [x] 앱스토어 문구·스크린샷 {#aso}
- [x] TestFlight 빌드 5 {#upload}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-15T00:49:23+09:00 | #parser | claude-code | ☐→~ |  | 하위 세션(Opus)에 위임 — Shared/Parser.swift + 하네스 |
| 2026-11-15T00:49:27+09:00 | #model | claude-code | ☐→~ |  |  |
| 2026-11-15T00:49:31+09:00 | #design | claude-code | ☐→~ |  |  |
| 2026-11-15T00:59:43+09:00 | #parser | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0059_feature_udada-v5-korean-parser.md | 판정 ✓ parser: 147 cases, 0 fail (하네스) — XCTest는 앱 빌드 후 · mac |
| 2026-11-15T01:06:52+09:00 | #bands | claude-code | ☐→~ |  | 위젯·서비스·AI 두뇌·음성/사진·기록/설정/소개는 하위 세션 5개에 병렬 위임 |
| 2026-11-15T01:42:25+09:00 | #design | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 차분한 종이 시간표 토큰·부품, 스크린샷 확인 |
| 2026-11-15T01:42:36+09:00 | #model | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 앱 그룹 JSON, 새 필드에도 안 깨지는 디코딩 |
| 2026-11-15T01:43:21+09:00 | #bands | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 판정 ✓ UI 10개 통과 (17 Pro Max) · mac |
| 2026-11-15T01:43:52+09:00 | #quickadd | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 미리보기·칩·연속 입력·키보드 내리기 |
| 2026-11-15T01:46:12+09:00 | #edit | claude-code | ☐→x | .oculpm/journal/20261115/Bugs/0142_bug_udada-v5-uitest-found-bugs.md | 밀기 덮개 결함 고친 뒤 UI 테스트 통과 |
| 2026-11-15T01:46:22+09:00 | #later | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 10일 넘으면 묻기, testLaterSheetAndWeek 통과 |
| 2026-11-15T01:46:30+09:00 | #close | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | testCloseDayStamp 통과 |
| 2026-11-15T01:46:40+09:00 | #dump | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | testDumpSortFinish 통과 (AI 정리는 두뇌 세션 대기, 규칙 대체로 동작) |
| 2026-11-15T01:46:50+09:00 | #worry | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | testWorryTime 통과, 위기 연락처 카드 |
| 2026-11-15T01:46:56+09:00 | #rest | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | testRestBreathFinishes 통과, 실폰 진동은 미확인 |
| 2026-11-15T01:47:01+09:00 | #focus | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | testFocusFromNowLine 통과 (예상 대 실제 토스트) |
| 2026-11-15T01:47:07+09:00 | #notify | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | 판정 ✓ notify: 26 cases, 0 fail · 실기기 도착 미확인 · mac |
| 2026-11-15T01:47:14+09:00 | #eventkit | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | EventKit 읽기·종일·달력 숨기기, 실제 달력 데이터는 실기기 미확인 |
| 2026-11-15T01:47:20+09:00 | #intents | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | 단축어 9개, IntentsTests 7개 통과, 메타데이터 추출 통과 |
| 2026-11-15T01:47:26+09:00 | #calendar | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | 월 칸·고른 날 세 띠, testTabsAndSettings 통과 |
| 2026-11-15T01:47:31+09:00 | #insights | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-records-settings-intro.md | 판정 ✓ stats: 60 cases, 0 fail · mac |
| 2026-11-15T01:47:39+09:00 | #settings | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-records-settings-intro.md | 띠 시각·알림·달력·AI·Siri·외관·내보내기 |
| 2026-11-15T01:47:45+09:00 | #intro | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-records-settings-intro.md | testIntroToToday 통과, 권한은 누를 때만 |
| 2026-11-15T02:12:20+09:00 | #icon | claude-code | ☐→x | .oculpm/journal/20261115/Chores/0212_chore_udada-v5-app-icon.md | 판정 ✓ actool exit 0 · 기본/다크/틴트 · mac |
| 2026-11-15T02:12:28+09:00 | #widgets | claude-code | ☐→~ |  | 빌드 통과, 렌더링 확인은 위젯 QA 세션 |
| 2026-11-15T02:12:43+09:00 | #live | claude-code | ☐→~ |  | 위젯 QA 세션이 렌더링 확인 중 |
| 2026-11-15T02:12:52+09:00 | #drag | claude-code | ☐→~ |  | 오늘 다듬기 세션이 끌어 옮기기 검증 중 |
| 2026-11-15T02:13:04+09:00 | #repeat | claude-code | ☐→~ |  | 로직 테스트 세션이 반복 펼치기·떼어 내기 검증 중 |
| 2026-11-15T02:13:13+09:00 | #aso | claude-code | ☐→~ |  | 앱스토어 패키지 세션 진행 중 |
| 2026-11-15T02:13:19+09:00 | #uitest | claude-code | ☐→~ |  | Pro Max 10개 통과, SE·영역별 UI 테스트는 다듬기 세션들 |
| 2026-11-15T02:19:01+09:00 | #repeat | claude-code | ~→x | .oculpm/journal/20261115/Bugs/0218_bug_udada-v5-daylogic-tests-bugs.md | 판정 ✓ logic: 67 cases, 0 fail · 반복 복제 버그 등 8개 고침 · mac |
| 2026-11-15T02:58:05+09:00 | #widgets | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0257_feature_udada-v5-widgets-qa-polish.md | 판정 ✓ intent-check: all pass · 실제 홈 화면 위젯 네모 누르기 확인 · 실제 잠금 화면 미확인 · mac |
| 2026-11-15T02:58:13+09:00 | #live | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0257_feature_udada-v5-widgets-qa-polish.md | 실제 다이내믹 아일랜드(걷기 10분) 확인, 잠금 화면 카드는 하네스만 |
| 2026-11-15T03:07:24+09:00 | #aso | claude-code | ~→x | .oculpm/journal/20261115/Chores/0257_chore_udada-v5-appstore-package.md | 이름·부제·키워드 100바이트·설명·개인정보·스크린샷 8장×3크기, 호스팅 URL은 사용자 |
| 2026-11-15T03:52:13+09:00 | #drag | claude-code | ~→x |  | 끌어 옮기기 유지 + '다른 띠로' 메뉴(테스트됨). 실제 손가락 끌기는 기기 확인 필요 |
| 2026-11-15T04:25:18+09:00 | #uitest | claude-code | ~→x | .oculpm/journal/20261115/Features_to_add/0406_feature_udada-v5-flows-polish.md | 판정 ✓ ** TEST SUCCEEDED ** — SE 74 통과·0 실패, Pro Max 74 통과·0 실패 (건너뜀 2는 스크린샷 전용) · mac |
| 2026-11-15T04:25:24+09:00 | #a11y | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0352_feature_udada-v5-today-calendar-polish.md | SE 큰 글자(접근성 L) 전 화면 재배치 확인, VoiceOver 라벨·동작·동작 줄이기는 코드로. 손 VoiceOver 점검은 미확인 |
| 2026-11-15T04:25:34+09:00 | #shots | claude-code | ☐→x | .oculpm/journal/20261115/Bugs/0142_bug_udada-v5-uitest-found-bugs.md | 전 화면 Pro Max·SE·어두운·큰 글자 스크린샷 점검(세션별 전후 비교), 앱스토어 스크린샷 8장 |
| 2026-11-15T04:28:00+09:00 | #upload | claude-code | ☐→x |  | 판정 ✓ ** TEST SUCCEEDED ** (SE·Pro Max 74/74) · Upload succeeded / ** EXPORT SUCCEEDED ** (0.5.0) · mac |
<!-- oculpm:plan-log end -->
