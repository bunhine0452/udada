---
oculpm_plan: v1
id: udada-mac-continuity
title: "우다다: Mac 앱과 iPhone 이어 쓰기"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

Mac 메뉴 막대 앱을 새로 짓고 iCloud(CloudKit)로 iPhone 과 몇 초 안에 맞춘다. Apple 지능은 Mac 에서도 같은 두뇌로 돈다.

**완료 조건:** Mac 에서 한 줄 적거나 끝내면 다른 기기 저장소에 그대로 나타나고(반대도), 두 기기가 따로 고쳐도 잃는 것 없이 합쳐지며, Mac 앱과 iOS 앱이 둘 다 빌드되어 Mac 앱이 실제로 뜬다
**확인 명령:** cd udada/ios && xcodegen generate --quiet && xcodebuild test -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)" | tail -2

## 동기화 {#sync}
- [x] 데이터를 레코드로 펴고 합치는 규칙 + 테스트 {#codec}
- [x] CloudKit 동기화 엔진 (CKSyncEngine) {#engine}
- [x] iOS 앱에 동기화·권한·푸시 연결 {#ios-hook}
- [x] 실제 iCloud 왕복 확인 (두 저장소) {#roundtrip}

## Mac 앱 {#mac}
- [x] Mac 타깃·테마 공용화·빌드 {#target}
- [~] 메뉴 막대: 지금 줄·오늘·끝내기 {#menubar}
- [~] 전역 단축키 한 줄 넣기 패널 {#quickadd}
- [x] 하루 한 장 창 (세 띠 나란히) {#window}
- [x] 집중 시계가 두 기기에서 이어짐 {#focus}
- [x] Mac 에서 비우기 (기기 안 AI) {#mac-brain}
- [~] 아이폰 카메라로 찍어 Mac 에 넣기 {#camera}

## 시스템 연결 {#apple}
- [~] Handoff·화면 인식(보던 날 이어 열기) {#handoff}
- [~] Mac Spotlight·Siri 에서 적기·묻기 {#mac-intents}
- [ ] Siri 결과 안에서 바로 끝내기 버튼 {#snippet}
- [ ] 사진을 모델에 바로 (iOS 27 OCRTool) {#image-input}
- [ ] 실제 아이폰↔Mac 푸시 속도 재기 {#device-check}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-15T13:13:01+09:00 | #codec | claude-code | ☐→x | journal/20261115/Features_to_add/1312_feature_udada-mac-app-icloud-sync.md | 판정 ✓ Executed 1700 tests, with 0 failures (17개×100회) / ** TEST SUCCEEDED ** · mac |
| 2026-11-15T13:13:06+09:00 | #engine | claude-code | ☐→x |  | 엔진이 바쁠 때 수동 호출 미룸 (CloudKit 단언 충돌 고침) |
| 2026-11-15T13:13:11+09:00 | #ios-hook | claude-code | ☐→x |  | iOS 단위 35/35·소개 UI 2/2 (시뮬). 실기기 푸시는 device-check |
| 2026-11-15T13:13:15+09:00 | #roundtrip | claude-code | ☐→x |  | 실제 iCloud(개발): 적기·끝내기·집중 이어받기·지우기가 두 저장소에서 맞음 |
| 2026-11-15T13:13:18+09:00 | #target | claude-code | ☐→x |  |  |
| 2026-11-15T13:13:22+09:00 | #menubar | claude-code | ☐→~ |  | 코드·빌드 됨. 이 Mac 은 노치에 가려 표식·패널을 눈으로 못 봄 — 눈 확인 남음 |
| 2026-11-15T13:13:28+09:00 | #quickadd | claude-code | ☐→~ |  | 넣기 칸은 안내 쪽에서 확인. 전역 단축키 패널은 실제로 눌러 보지 못함 |
| 2026-11-15T13:13:32+09:00 | #window | claude-code | ☐→x |  | 스크린샷 확인: 제목 막대 없이 종이가 꼭대기까지 |
| 2026-11-15T13:13:36+09:00 | #focus | claude-code | ☐→x |  | iCloud 로 시작·끝 이어짐 확인. iPhone 화면 따라가기는 코드만 |
| 2026-11-15T13:13:40+09:00 | #mac-brain | claude-code | ☐→x | journal/20261115/Bugs/1312_bug_udada-brain-bin-tag-leak.md | 실제 모델로 나눔 확인, 칸 이름 새는 것·빠지는 줄 고침 |
| 2026-11-15T13:13:45+09:00 | #camera | claude-code | ☐→~ |  | 버튼·OCR 길은 지음. 실제 아이폰으로 찍기·끌어다 놓기는 미확인 |
| 2026-11-15T13:13:52+09:00 | #handoff | claude-code | ☐→~ |  | 양쪽에 NSUserActivity 붙임. 실기기 두 대에서 미확인 |
| 2026-11-15T13:14:05+09:00 | #mac-intents | claude-code | ☐→~ |  | 인텐트가 Mac 타깃에 컴파일됨(Metadata.appintents). Spotlight·Siri 에서 실행은 미확인 |
<!-- oculpm:plan-log end -->
