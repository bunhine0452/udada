---
oculpm_plan: v1
id: udada-day-sheet
title: "우다다: 하루 한 장 (일정·할 일·식히기)"
status: active
created: 2026-11-14
updated: 2026-11-14
owner: claude-code
---

**완료 조건:** 한 줄로 일정·할 일을 넣고, 식히고, 하루를 닫는 흐름이 실제 아이폰 앱에서 끝까지 돌고 기기 달력의 약속이 띠에 보인다
**확인 명령:** cd udada/design && PW=<playwright-core 경로> node tests/day.test.js | tail -1

## 동작판 {#proto}
- [x] 일정·할 일 논문 읽고 설계 근거 정리 {#research}
- [x] day.html 동작판과 흐름·레이아웃 검사 {#html}
- [x] 사용자가 폰에서 써 보고 방향 확정 {#direction}

## 네이티브 {#native}
- [>] SwiftUI로 옮기기 (세 띠·한 줄 넣기) {#swiftui}
- [>] 기기 달력 약속 읽어 띠에 표시 {#eventkit}
- [>] 알림: 약속 제시각, 할 일 하루 3번 {#notify}
- [>] 끌어 옮기기와 반복 일정 {#drag}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-14T14:00:37+09:00 | #research | claude-code | ☐→x | journal/20261114/Features_to_add/1400_feature_udada-day-sheet-proto.md | DAY.md, 초록 원문 확인 6편 |
| 2026-11-14T14:00:42+09:00 | #html | claude-code | ☐→x | journal/20261114/Features_to_add/1400_feature_udada-day-sheet-proto.md | 판정 ✓ day: 0 fail — 실폰 키보드·진동은 미확인 · mac |
| 2026-11-15T04:06:11+09:00 | #direction | claude-code | ☐→x |  | 사용자 11-15: 가장 편안한 UI로 재탄생 + 많은 기능 + Siri·AI → udada-v5-comfort |
| 2026-11-15T04:06:19+09:00 | #swiftui | claude-code | ☐→> | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | udada-v5-comfort 로 이월 — 거기서 #bands·#quickadd 로 완료 |
| 2026-11-15T04:06:27+09:00 | #eventkit | claude-code | ☐→> | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | udada-v5-comfort #eventkit 로 이월·완료 |
| 2026-11-15T04:06:33+09:00 | #notify | claude-code | ☐→> | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | udada-v5-comfort #notify 로 이월·완료 |
| 2026-11-15T04:06:40+09:00 | #drag | claude-code | ☐→> | .oculpm/journal/20261115/Features_to_add/0352_feature_udada-v5-today-calendar-polish.md | udada-v5-comfort #drag·#repeat 로 이월·완료 |
<!-- oculpm:plan-log end -->
