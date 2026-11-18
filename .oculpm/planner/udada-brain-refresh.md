---
oculpm_plan: v1
id: udada-brain-refresh
title: "우다다: 뇌 리프레시 설계와 동작판"
status: active
created: 2026-11-05
updated: 2026-11-05
owner: claude-code
---

"뇌가 안 돌아간다"를 상태별로 나눠 논문 근거가 있는 처방으로 잇는다. VALUE.md(식히기)의 후속.

**완료 조건:** 상태를 두 번 탭해 진단하면 근거 있는 화면 밖 처방 하나가 나오고, 전후 머리 맑음이 기록되는 동작판이 끝까지 돈다
**확인 명령:** cd udada/design && PW=/tmp/shtest/node_modules/playwright-core node tests/refresh.test.js

## 논문 {#research}
- [x] 뇌과학·심리 논문 초록 수집해 읽기 {#papers}
- [x] 근거 표와 한계 정리 (REFRESH.md) {#evidence}

## 설계 {#design}
- [x] 상태 진단 → 처방 매핑 설계 {#routing}
- [x] 측정과 판정 기준 {#measure}

## 동작판 {#build}
- [x] refresh.html 동작판 {#proto}
- [x] 브라우저 테스트 작성·통과 {#test}
- [x] 화면별 스크린샷으로 실제 확인 {#shots}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-05T21:12:55+09:00 | #papers | claude-code | ☐→x | .oculpm/journal/20261105/Chores/2112_chore_udada-refresh-research-design.md | OpenAlex+Europe PMC 초록 40편 |
| 2026-11-05T21:12:59+09:00 | #evidence | claude-code | ☐→x | .oculpm/journal/20261105/Chores/2112_chore_udada-refresh-research-design.md | REFRESH.md 근거 표·한계·참고문헌 |
| 2026-11-05T21:13:03+09:00 | #routing | claude-code | ☐→x | .oculpm/journal/20261105/Chores/2112_chore_udada-refresh-research-design.md | 4상태 × 2/10/20분 처방표, 기본 + 다른 거 |
| 2026-11-05T21:13:08+09:00 | #measure | claude-code | ☐→x | .oculpm/journal/20261105/Chores/2112_chore_udada-refresh-research-design.md | 맑기 0–10 전후, 1차 중앙값 +2, 개인 내 비교 |
| 2026-11-05T21:13:12+09:00 | #proto | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2112_feature_udada-refresh-prototype.md | refresh.html + machine.css/js, 식히기 왕복 |
| 2026-11-05T21:13:18+09:00 | #test | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2112_feature_udada-refresh-prototype.md | 판정 ✓ all checks passed / errors: none (37 체크) |
| 2026-11-05T21:13:24+09:00 | #shots | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2112_feature_udada-refresh-prototype.md | 판정 ✓ errors: none — 스크린샷 r1–r7·c0–c4 확인, 실폰 알람·진동은 미확인 |
<!-- oculpm:plan-log end -->
