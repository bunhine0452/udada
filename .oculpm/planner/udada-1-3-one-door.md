---
oculpm_plan: v1
id: udada-1-3-one-door
title: "우다다 1.3: AI 한 입구 · Siri · 움직이는 사용법"
status: active
created: 2026-11-18
updated: 2026-11-18
owner: claude-code
---

**완료 조건:** 오늘 화면 아래 한 줄에서 Apple Intelligence 가 쏟아낸 말을 나눠 넣고·시키고·찾으며, Siri 한 문장으로 앱을 열지 않고 여러 일이 바뀌고, 처음 실행하면 아홉 장면의 움직이는 사용법이 전 기능을 보여 주며, iPhone 빌드와 Mac 테스트가 통과하고 사용자가 써 보고 좋다고 한다
**확인 명령:** cd udada/ios && xcodegen generate --quiet && xcodebuild test -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed [0-9]+ tests, |TEST (SUCCEEDED|FAILED)" | tail -2

## 움직이는 사용법 {#guide}
- [x] 시간축 장면 엔진과 아홉 장면 {#guide-engine}
- [x] 첫 실행·설정·빈 날에서 사용법 열기 {#guide-entry}

## 오늘 화면의 AI 입구 {#door}
- [x] 넣기 줄의 Apple Intelligence 버튼과 판 {#ai-panel}
- [x] 한 줄에 여러 일이면 나눠 넣기·물음은 찾기 {#smart-line}
- [ ] 할 일 메뉴에서 작게 쪼개기 {#split-menu}

## Siri 로 놀라게 {#siri}
- [~] Siri 한 문장으로 여러 일 바꾸기 {#siri-tell}
- [~] Siri 로 쏟아내면 나눠 넣기 {#siri-sort}

## 부드러운 화면 {#soft}
- [~] 오늘 화면 테두리·눌림·넣기 줄 다듬기 {#soft-today}
- [~] 시뮬레이터 확인과 테스트 통과 {#verify}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-18T18:14:53+09:00 | #guide-engine | claude-code | ☐→x | journal/20261118/Features_to_add/1814_feature_udada-1-3-guide-ai-door-siri.md | 판정 ✓ Executed 60 tests, with 0 failures / ** TEST SUCCEEDED ** · 아홉 장면 멈춘 프레임 확인 · mac |
| 2026-11-18T18:14:56+09:00 | #guide-entry | claude-code | ☐→x |  | 소개 UI 테스트 3개 통과 |
| 2026-11-18T18:14:58+09:00 | #ai-panel | claude-code | ☐→x |  | testAIPanelOpensAsk 통과 · 판 모습은 눈으로 안 봄 |
| 2026-11-18T18:15:01+09:00 | #smart-line | claude-code | ☐→x |  | 규칙 경로로 화면·UI 테스트 확인 · 실제 모델 경로는 미확인 |
| 2026-11-18T18:15:04+09:00 | #siri-tell | claude-code | ☐→~ |  | 계산은 단위 테스트 통과 · 실제 Siri 호출은 기기에서 확인 필요 |
| 2026-11-18T18:15:06+09:00 | #siri-sort | claude-code | ☐→~ |  | 계산은 단위 테스트 통과 · 실제 Siri 호출은 기기에서 확인 필요 |
| 2026-11-18T18:15:09+09:00 | #soft-today | claude-code | ☐→~ |  | 오늘 화면 첫 손질만 · 달력·기록·비우기 탭과 사용자 평가 남음 |
| 2026-11-18T18:49:55+09:00 | #verify | claude-code | ☐→~ | journal/20261118/Chores/1849_chore_udada-1-2-shots-submit.md | iOS 1.2 심사 대기 중 · Mac 1.1 심사 중(승인되면 자동 출시) · Mac 1.2 와 새 Mac 스크린샷은 1.1 이 나간 뒤 |
<!-- oculpm:plan-log end -->
