---
oculpm_plan: v1
id: udada-ios-testflight
title: "우다다: iOS 앱으로 TestFlight"
status: active
created: 2026-11-05
updated: 2026-11-05
owner: claude-code
---

refresh·cooler 동작판을 SwiftUI+WKWebView 앱으로 감싸고, 햅틱·화면 유지·잠금 알람을 네이티브로 채워 TestFlight 에 올린다.

**완료 조건:** TestFlight 업로드가 성공하고, 시뮬레이터에서 앱을 띄워 리프레시 처방을 끝까지 돌릴 수 있다
**확인 명령:** udada/ios/scripts/archive.sh 2>&1 | tail -5

## 앱 {#app}
- [x] xcodegen 프로젝트·웹 번들 {#project}
- [x] 햅틱·화면 유지·잠금 알람 브리지 {#bridge}
- [x] 앱 아이콘 {#icon}
- [~] 시뮬레이터에서 띄워 확인 {#sim}

## 배포 {#ship}
- [x] 아카이브·TestFlight 업로드 {#archive}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-05T21:50:14+09:00 | #project | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2150_feature_udada-ios-testflight.md | xcodegen, 웹 4파일 직접 참조 |
| 2026-11-05T21:50:25+09:00 | #bridge | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2150_feature_udada-ios-testflight.md | 빌드 통과, 실기기 확인은 TestFlight 설치 후 |
| 2026-11-05T21:50:33+09:00 | #icon | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2150_feature_udada-ios-testflight.md | 기계 언어 1024 RGB |
| 2026-11-05T21:50:39+09:00 | #sim | claude-code | ☐→~ | .oculpm/journal/20261105/Features_to_add/2150_feature_udada-ios-testflight.md | 설치·실행·첫 화면 확인. 처방 끝까지 돌리기는 미확인 (탭 자동화 없음) |
| 2026-11-05T21:50:50+09:00 | #archive | claude-code | ☐→x | .oculpm/journal/20261105/Features_to_add/2150_feature_udada-ios-testflight.md | 판정 ✓ Upload succeeded / ** EXPORT SUCCEEDED ** |
<!-- oculpm:plan-log end -->
