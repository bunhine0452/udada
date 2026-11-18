---
oculpm_plan: v1
id: udada-breakdown
title: "우다다: 큰일 쪼개서 마감 전 날에 놓기"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

큰일 하나를 Apple Intelligence 가 3~5 걸음으로 쓰고, 규칙이 마감에서 거꾸로 날에 놓는다. 미리 보고 눌러야 들어간다.

**완료 조건:** 처음 보는 큰일 20개에서 실제 Mac 모델이 모두 3~5 걸음을 내고 규칙으로 떨어진 것 2개 이하·가운데값 3초 이하이며, iPhone·Mac 에서 고른 걸음이 마감 전 날짜에 실제로 들어간다
**확인 명령:** cd udada/ios && Eval/run.sh steps-verdict | tail -3

## 쪼개기 {#split}
- [x] 걸음 품질 재는 하네스(steps 묶음·채점) {#harness}
- [x] 걸음 검사·날에 놓기 규칙과 모델 호출 {#rules}
- [x] iPhone 고치기 화면에서 쪼개기 {#iphone}
- [x] Mac 줄 메뉴에서 쪼개기 {#mac}
- [x] 처음 보는 묶음으로 판정 {#verdict}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-15T20:39:34+09:00 | #harness | claude-code | ☐→x | journal/20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md | Eval/run.sh steps · steps-verdict · score_steps.py |
| 2026-11-15T20:39:38+09:00 | #rules | claude-code | ☐→x | journal/20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md | Mac 테스트 Executed 47 tests, with 0 failures |
| 2026-11-15T20:39:42+09:00 | #iphone | claude-code | ☐→x | journal/20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md | 시뮬레이터 UI 테스트 통과 — 실제 iPhone(모델 길)은 안 돌려 봄 |
| 2026-11-15T20:39:46+09:00 | #mac | claude-code | ☐→x | journal/20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md | 실제 앱에서 ⌘↩ 로 넣어 저장 파일에 마감 전 날짜로 들어간 것 확인 |
| 2026-11-15T20:39:50+09:00 | #verdict | claude-code | ☐→x | journal/20261115/Features_to_add/2039_feature_udada-breakdown-steps-before-due.md | 판정 ✓ steps: 3~5 걸음 20/20 · 모델이 쓴 것 19 · 다듬어 둔 걸음 1 · 규칙으로 떨어짐 0 · 마감 넘긴 걸음 0 · 가운데값 1.1초 (처음 한 번은 18·1·1, 글의 질은 읽어서 16% 어색) · mac |
<!-- oculpm:plan-log end -->
