---
oculpm_plan: v1
id: udada-ai-best
title: "우다다: Apple Intelligence 품질과 새 쓰임"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

기기 안 모델의 품질을 숫자로 재서 올리고, 모델이 '알아듣고' 규칙이 '답하는' 새 쓰임을 더한다 (1.1 용).

**완료 조건:** 처음 보는 쏟아내기 묶음에서 실제 Mac 모델이 잃는 줄 0·새는 꼬리표 0·칸 정확도 90% 이상을 내고, 말로 찾기가 iPhone·Mac 에서 실제 항목을 돌려준다
**확인 명령:** cd udada/ios && Eval/run.sh heldout | tail -3

## 품질 재기 {#quality}
- [x] 실제 모델 평가 하네스와 라벨 묶음 {#harness}
- [x] 지금 숫자 재기 (조정·처음 보는 묶음) {#baseline}
- [~] 칸 90%·잃는 줄 0 까지 고치기 {#improve}

## 새 쓰임 {#uses}
- [x] 말로 찾기: 모델이 질문을 읽고 규칙이 답 {#ask}
- [~] iPhone·Mac 찾기 화면과 Siri 동작 {#ask-ui}
- [x] 사진을 모델에 바로 넣어 일정 읽기 시험 {#image}
- [ ] Siri 결과 안 끝내기 버튼 {#snippet}

## 내보내기 {#ship}
- [ ] 스토어 스크린샷 다시 찍기 {#shots}
- [ ] 실제 iPhone 에서 속도·정확도 재기 {#phone-measure}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-15T14:17:22+09:00 | #harness | claude-code | ☐→x |  | ios/Eval: 묶음 넷(tune·heldout·fresh·verdict) + 찾기 둘, Mac 앱의 -udEval 로 실제 모델을 잰다 |
| 2026-11-15T14:17:29+09:00 | #baseline | claude-code | ☐→x |  | 고치기 전: tune 잃은 줄 3·90%, heldout 0·86%, fresh 8·82% (규칙만 24·71%) |
| 2026-11-15T14:17:34+09:00 | #improve | claude-code | ☐→~ |  | 판정 ✗ heldout 잃은 줄 0·칸 100% 이지만 처음 본 verdict 는 잃은 줄 6~7·칸 90~91% — 칸 목표는 넘고 '잃는 줄 0'은 못 닿음 · mac |
| 2026-11-15T14:17:39+09:00 | #ask | claude-code | ☐→x |  | 처음 보는 물음 20개: 모델 길 80% · 규칙만 85%. 답은 전부 실제 기록에서 |
| 2026-11-15T14:17:46+09:00 | #ask-ui | claude-code | ☐→~ |  | iPhone(UI 테스트 통과)·Mac(실제 모델로 화면 확인) 됨. Siri '우다다에서 찾기'는 빌드만 — 실행 미확인 |
| 2026-11-15T15:58:13+09:00 | #image | claude-code | ☐→x |  | 처음 보는 합성 그림 8장: 날짜·시각까지 맞은 일정 13/15(86%), 글자 인식만 8/15(53%). 실제 찍은 사진은 미확인 |
| 2026-11-15T15:58:21+09:00 | #improve | claude-code | ~→~ |  | 판정 ✗ eval: 잃은 줄 5 · 칸 정확도 51/55 (93%) (verdict2, 규칙만 6·91%) — heldout·verdict 는 0, '잃는 줄 0'은 아직 · mac |
<!-- oculpm:plan-log end -->
