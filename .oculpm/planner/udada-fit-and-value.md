---
oculpm_plan: v1
id: udada-fit-and-value
title: "우다다: 모든 화면·키보드 대응과 가치 강화"
status: active
created: 2026-11-05
updated: 2026-11-05
owner: claude-code
---

px 고정 레이아웃을 비례 배율(rem + --k)로 바꾸고, 키보드가 올라와도 입력과 주 버튼이 보이게 한다. 첫 실행 소개·기록 추이·하던 일로 돌아가기로 가치를 분명히 한다.

**완료 조건:** 360×640부터 440×956까지 7개 크기와 키보드 상태에서 넘침·가림·작은 터치가 0이고, 첫 화면부터 결과까지 앱이 주는 가치가 보이는 빌드가 TestFlight에 올라간다
**확인 명령:** cd udada/design && PW=/tmp/shtest/node_modules/playwright-core node tests/layout.test.js | tail -1 && PW=/tmp/shtest/node_modules/playwright-core node tests/refresh.test.js | tail -1

## 화면 맞춤 {#fit}
- [x] 레이아웃 감사 테스트 (7크기×키보드) {#audit}
- [x] rem 전환과 비례 배율 --k {#scale}
- [x] 키보드: 네이티브 축소·키보드 모드 {#keyboard}
- [x] 터치 44pt·입력 16px {#targets}

## 가치 {#value}
- [x] 첫 실행 소개 한 장 {#intro}
- [x] 홈·결과에 기록 추이 {#history}
- [x] 결과에서 하던 일로 돌아가기 {#resume}

## 배포 {#ship}
- [x] 시뮬레이터 크기별 확인 {#sim}
- [x] TestFlight 빌드 2 {#upload}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-05T23:27:36+09:00 | #audit | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | 처음 89건 실패 → 0 |
| 2026-11-05T23:27:40+09:00 | #scale | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | k=min(W/390,H/800), 키보드 무관 |
| 2026-11-05T23:27:46+09:00 | #keyboard | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | 웹 키보드 모드 테스트 통과, keyboardLayoutGuide 실기기 미확인 |
| 2026-11-05T23:27:51+09:00 | #targets | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | 키 44px 하한, 입력 max(16px,1rem) |
| 2026-11-05T23:27:57+09:00 | #intro | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md |  |
| 2026-11-05T23:28:02+09:00 | #history | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md |  |
| 2026-11-05T23:28:07+09:00 | #resume | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md |  |
| 2026-11-05T23:28:12+09:00 | #sim | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | SE·16 Pro Max 첫 화면 확인 후 시뮬레이터 삭제 |
| 2026-11-05T23:28:18+09:00 | #upload | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md | 판정 ✓ layout: 0 fail / all checks passed · Upload succeeded (빌드 2) |
<!-- oculpm:plan-log end -->
