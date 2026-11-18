---
oculpm_plan: v1
id: udada-outside-in
title: "우다다: 밖에서 받기·녹음·미룬 일·차분한 모션"
status: active
created: 2026-11-16
updated: 2026-11-16
owner: claude-code
---

남이 보낸 글·녹음에서 할 일을 받아 오고, 여러 번 넘어온 일을 풀어 주고, 화면을 더 차분하고 부드럽게.

**완료 조건:** 처음 보는 메시지 묶음에서 실제 Mac 모델이 받아야 할 일정·할 일의 80% 이상을 날짜까지 맞게 받고 없는 일을 5% 이하로 만들며, 공유·녹음·미룬 일 풀기가 iPhone·Mac 에서 실제로 돌고 두 앱의 테스트가 통과한다
**확인 명령:** cd udada/ios && Eval/run.sh capture-verdict | tail -2

## 밖에서 받기 {#capture}
- [x] 메시지 묶음 둘과 채점, 지금 숫자 {#capture-eval}
- [x] 남이 보낸 글에서 일정·할 일 뽑기 {#capture-core}
- [~] iPhone 공유 확장과 받은 것 정리 {#capture-share}
- [x] Mac 서비스 메뉴로 보내기 {#capture-mac}

## 녹음 {#audio}
- [x] 녹음 파일 받아쓰고 할 일 찾기 {#audio-core}
- [~] iPhone·Mac 에서 녹음 파일 넣기 {#audio-ui}

## 미룬 일 {#stuck}
- [x] 넘어온 횟수 세기와 고르기 규칙 {#stuck-core}
- [x] 오늘 화면의 한 줄 물음 {#stuck-ui}

## 차분한 화면 {#calm}
- [~] 모션 토큰과 주요 전환 부드럽게 {#motion}
- [x] 마음 편한 디자인 더하기 {#calm-design}
- [x] 테스트 통과 후 TestFlight {#ship}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-16T03:12:10+09:00 | #capture-eval | claude-code | ☐→x |  | 처음 숫자: 모델만 61% · 없는 일 12%, 규칙만 83% |
| 2026-11-16T03:12:15+09:00 | #capture-core | claude-code | ☐→x |  | 판정 ✓ capture-verdict(처음 한 번): 받은 것 15/18 (83%) · 날짜·시각 틀림 3 · 없는 일 1/22 (4%) · 규칙만 15/18 (83%) · mac |
| 2026-11-16T03:12:20+09:00 | #capture-mac | claude-code | ☐→x |  | 비우기 창에서 받기는 띄워 확인. 서비스 메뉴는 코드만, 다른 앱에서 눌러 보지 못함 |
| 2026-11-16T03:12:26+09:00 | #audio-core | claude-code | ☐→x |  | 합성 음성 6개: 받은 것 9/9 · 없는 일 0/9. 실제 회의 녹음으로는 안 잼 |
| 2026-11-16T03:12:33+09:00 | #stuck-core | claude-code | ☐→x |  | Mac 단위 테스트 60개 통과 (새 9개) |
| 2026-11-16T03:39:48+09:00 | #capture-share | claude-code | ☐→~ | journal/20261116/Features_to_add/0339_feature_udada-capture-audio-stuck-calm.md | 받아 둔 것 → 비우기는 UI 테스트 통과. 공유 시트에서 확장을 실제로 눌러 보는 것이 남음(실기기) |
| 2026-11-16T03:39:53+09:00 | #audio-ui | claude-code | ☐→~ |  | Mac 은 띄워 확인. iPhone 의 녹음 파일 버튼은 빌드만, 눌러 보지 못함 |
| 2026-11-16T03:39:58+09:00 | #stuck-ui | claude-code | ☐→x |  | iPhone UI 테스트 + Mac·iPhone 스크린샷 |
| 2026-11-16T03:40:02+09:00 | #motion | claude-code | ☐→~ |  | 토큰·잉크 줄·줄 이동 넣음, 테스트 통과. 움직임 자체는 눈으로 못 봄 — 사용자 피드백 대기 |
| 2026-11-16T03:40:07+09:00 | #calm-design | claude-code | ☐→x |  | 쉼 카드 · 숨 쉬는 먹점 · 알림 카드 한 번에 하나 |
| 2026-11-16T03:40:15+09:00 | #ship | claude-code | ☐→x |  | 판정 ✓ capture: 받은 것 18/18 (100%) · 없는 일 0/21 (본 묶음; 처음 한 번은 83% · 4%). iPhone·Mac 업로드 EXPORT SUCCEEDED · mac |
<!-- oculpm:plan-log end -->
