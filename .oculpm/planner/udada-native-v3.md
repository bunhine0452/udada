---
oculpm_plan: v1
id: udada-native-v3
title: "우다다: SwiftUI 네이티브 v3"
status: active
created: 2026-11-06
updated: 2026-11-06
owner: claude-code
---

"웹페이지 같다·처방이 심심하다·단계가 많다·버튼이 단순하다"를 네이티브 재작성으로 푼다. 웹 동작판은 디자인 기준으로 남긴다.

**완료 조건:** 상태 한 번 누르고 시작 한 번이면 처방이 돌고, 처방마다 다른 화면(호흡 게이지·걸음 수·낮잠 시계)이 나오는 네이티브 앱이 SE와 Pro Max에서 UI 테스트로 끝까지 돌고 TestFlight에 올라간다
**확인 명령:** cd udada/ios && xcodebuild test -project Udada.xcodeproj -scheme Udada -destination "id=$SIM" 2>&1 | tail -3

## 부품 {#kit}
- [x] 처방·기록 모델 (단위 테스트) {#model}
- [x] 입체 키·노브·세그먼트 LCD {#keys}

## 흐름 {#flow}
- [x] 소개·홈·지난번처럼 {#home}
- [x] 처방 화면 (시간·맑기·책갈피 한 화면) {#rx}
- [x] 처방별 실행 화면 (호흡·걸음·낮잠) {#run}
- [x] 돌아옴·결과·서랍 {#after}
- [x] 꽉 찼어: 비우기·분류 {#dump}

## 검증·배포 {#ship}
- [x] UI 테스트 SE·Pro Max (키보드 포함) {#uitest}
- [x] TestFlight 빌드 3 {#upload}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-06T00:24:23+09:00 | #model | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md | 단위 테스트 7개 통과 |
| 2026-11-06T00:24:28+09:00 | #keys | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md |  |
| 2026-11-06T00:24:33+09:00 | #home | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md |  |
| 2026-11-06T00:24:38+09:00 | #rx | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md |  |
| 2026-11-06T00:24:44+09:00 | #run | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md | 호흡·걷기·낮잠 화면 스크린샷 확인, 실기기 만보계 미확인 |
| 2026-11-06T00:24:49+09:00 | #after | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md |  |
| 2026-11-06T00:24:54+09:00 | #dump | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md |  |
| 2026-11-06T00:25:05+09:00 | #uitest | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md | 판정 ✓ ** TEST SUCCEEDED ** (SE·16 Pro Max, 키보드 포함) |
| 2026-11-06T00:25:11+09:00 | #upload | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0024_feature_udada-native-v3.md | 판정 ✓ ** TEST SUCCEEDED ** · Upload succeeded (빌드 3, 0.3.0) |
<!-- oculpm:plan-log end -->
