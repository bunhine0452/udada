---
oculpm_plan: v1
id: udada-find-by-meaning
title: "우다다: 뜻으로 찾기"
status: active
created: 2026-11-16
updated: 2026-11-16
owner: claude-code
---

낱말이 안 겹쳐도("병원 가는 거" → 치과·내과 검진) Apple Intelligence 가 실제 기록 안에서 골라 준다. 모델은 번호만 고르고 답은 기록에서.

**완료 조건:** 처음 보는 물음 묶음에서 실제 Mac 모델이 찾아야 할 기록의 80% 이상을 찾고 잘못 고른 것이 찾은 것의 10% 이하이며, iPhone·Mac 찾기 화면에 뜻으로 찾은 줄이 실제로 뜬다
**확인 명령:** cd udada/ios && Eval/run.sh sense-verdict | tail -2

## 재기 {#measure}
- [x] 기록 50개·물음 두 묶음과 채점 {#sense-eval}
- [x] 규칙만의 숫자 재기 {#sense-baseline}

## 만들기 {#build}
- [x] 모델이 실제 기록에서 번호 고르기 {#sense-pick}
- [~] iPhone·Mac 찾기 화면과 Siri 답 {#sense-ui}
- [x] 처음 보는 묶음으로 판정 {#sense-verdict}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-16T01:22:37+09:00 | #sense-eval | claude-code | ☐→x | journal/20261116/Features_to_add/0122_feature_udada-find-by-meaning.md |  |
| 2026-11-16T01:22:41+09:00 | #sense-baseline | claude-code | ☐→x |  | 규칙만 조정용 11~23% · 처음 보는 묶음 29% |
| 2026-11-16T01:22:45+09:00 | #sense-pick | claude-code | ☐→x |  | 번호 대신 이름 베끼기, 세 번 중 두 번 |
| 2026-11-16T01:22:50+09:00 | #sense-ui | claude-code | ☐→~ |  | Mac 은 실제로 띄워 확인. iPhone 화면·Siri 는 빌드만, 눈으로 못 봄 |
| 2026-11-16T01:22:55+09:00 | #sense-verdict | claude-code | ☐→~ |  | 판정 ✗ sense: 찾아야 할 것 34/34 (100%) · 잘못 고른 것 9/45 (20%) · 규칙만 10/34 (29%), 잘못 0 — 잘못 10% 이하 못 닿음 · mac |
| 2026-11-16T02:34:20+09:00 | #sense-verdict | claude-code | ~→x |  | 판정 ✗ sense-verdict4(새 목표 잘못 5% 이하, 처음 한 번): 찾아야 할 것 23/31 (74%) · 잘못 고른 것 0/26 (0%) — 잘못은 닿았고 찾음 80%는 못 닿음. 본 묶음 verdict2 는 11% · mac |
<!-- oculpm:plan-log end -->
