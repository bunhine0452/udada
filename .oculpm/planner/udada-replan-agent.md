---
oculpm_plan: v1
id: udada-replan-agent
title: "우다다: 한 주를 풀어 주는 도구 호출 비서"
status: active
created: 2026-11-18
updated: 2026-11-18
owner: claude-code
---

**완료 조건:** "이번 주 너무 빡빡해"라고 하면 기기 안 모델이 도구로 빈 시간과 할 일을 직접 보고 옮길 안을 내며, 처음 보는 묶음에서 넘치는 칸을 80% 이상 풀고 지키라고 한 일·없는 일을 건드리는 것이 0이고, iPhone 에서 보는 과정과 전후 그림이 뜨고 눌러야 적용된다
**확인 명령:** cd udada/ios && Eval/run.sh replan-verdict | tail -2

## 규칙과 도구 {#core}
- [ ] 한 주의 짐 보기·검사·규칙 대체 {#rules}
- [ ] 모델 도구 둘과 옮길 안 받기 {#tools}
- [ ] 실제 모델로 재는 묶음과 채점기 {#eval}

## 화면 {#ui}
- [ ] 보는 과정·전후 그림·적용 화면 {#view}
- [ ] 넣기 줄·AI 판·넘치는 칸에서 열기 {#entry}
- [~] 묶음으로 고치고 처음 보는 묶음 판정 {#tune}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-18T19:55:37+09:00 | #tune | claude-code | ☐→~ | journal/20261118/Features_to_add/1955_feature_udada-replan-tool-calling.md | 판정 ✗ replan 판정: 넘침 풀림 7/9 (77%) · 모델만으로 6/9 · 비우기 2/2 · 지키라는 일 건드림 0 · 필요 없는 옮김 0 · 때가 걸린 일을 미룸 3 (규칙만 8/9 · 3 — 모델이 규칙보다 낫지 않다) · mac |
<!-- oculpm:plan-log end -->
