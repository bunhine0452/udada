---
oculpm_plan: v1
id: udada-1-2
title: "우다다 1.2: 세 칸이 보이게 · 움직이는 AI 튜토리얼"
status: active
created: 2026-11-16
updated: 2026-11-16
owner: claude-code
---

사용자 피드백(11-16): 아침·낮·저녁이 UI에서 나뉘어 있다고 와닿지 않는다 · Apple Intelligence 튜토리얼이 글 설명뿐이고 모션 그래픽이 없다.

**완료 조건:** 오늘 화면을 처음 본 사람이 스크린샷 한 장에서 세 칸과 지금 칸을 바로 짚을 수 있고, 튜토리얼이 기능마다 움직이는 장면으로 Apple Intelligence 가 하는 일을 보여 주며, iPhone·Mac 테스트가 통과하고 사용자가 TestFlight 에서 좋다고 한다
**확인 명령:** cd udada/ios && xcodegen generate --quiet && xcodebuild test -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)" | tail -2

## 세 칸 {#bands}
- [x] 화면 위 하루 띠: 세 칸·지금·찬 정도 {#band-ruler}
- [x] 칸마다 종이 한 장, 큰 제목 {#band-cards}
- [~] 지난 칸은 한 줄로 접기 {#band-fold}
- [ ] Mac 세 칸도 같은 말로 {#band-mac}

## 튜토리얼 {#tutorial}
- [x] 기능마다 움직이는 장면 다섯 {#tour-scenes}
- [~] 처음 실행·설정에서 다시 보기·직접 해 보기 {#tour-entry}
- [ ] Mac 에도 같은 튜토리얼 {#tour-mac}

## 마무리 {#wrap}
- [x] 뜻으로 찾기: 병원→치과 되살리기 {#sense-recall}
- [x] 1.2 빌드를 TestFlight 에 {#ship-1-2}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-16T04:25:54+09:00 | #band-ruler | claude-code | ☐→x |  | iPhone 머리에 하루 띠. 시뮬레이터 스크린샷 + 오늘 UI 테스트 16개 통과 |
| 2026-11-16T04:25:59+09:00 | #band-cards | claude-code | ☐→x |  | 칸마다 카드, 큰 가로 제목, 지금 칸은 코발트 테두리·'지금' 표시 |
| 2026-11-16T04:26:04+09:00 | #band-fold | claude-code | ☐→~ |  | 접는 코드는 넣음. 접힌 모습은 눈으로 못 봄(예시 하루는 아침에 반복 일이 남아 안 접힘) |
| 2026-11-16T04:26:09+09:00 | #tour-scenes | claude-code | ☐→x |  | 일곱 장면. 시뮬레이터에서 장면마다 스크린샷(한 장은 카드가 칸으로 날아가는 도중) |
| 2026-11-16T04:26:27+09:00 | #tour-entry | claude-code | ☐→~ |  | 소개 4쪽 · 설정 · 비우기 탭에 입구, 직접 해 보기 연결. 입구를 눌러 여는 것은 눌러 보지 못함(실행 인자로만 띄움) |
| 2026-11-16T04:57:00+09:00 | #sense-recall | claude-code | ☐→x |  | 다섯 표는 검사 없이 받음. verdict4 87% · 잘못 0/30(본 묶음). Mac 앱에서 병원→치과 확인 |
| 2026-11-16T04:57:07+09:00 | #ship-1-2 | claude-code | ☐→x | journal/20261116/Features_to_add/0457_feature_udada-1-2-bands-ai-tour.md | 판정 ✓ Executed 60 tests, with 0 failures / ** TEST SUCCEEDED ** · iPhone·Mac 1.2 업로드 EXPORT SUCCEEDED. 사용자 평가는 대기 · mac |
<!-- oculpm:plan-log end -->
