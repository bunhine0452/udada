---
oculpm_plan: v1
id: udada-v5-intelligence
title: "우다다 v5: Siri·Apple 지능·iOS 통합"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

사용자 요청(11-15): iOS 에 특화된 앱, 내장 Siri 와 AI 를 쓰는 기능을 많이. 온디바이스(Foundation Models)로만, AI 가 없는 기기에서는 규칙으로 같은 흐름. UI 재탄생(udada-v5-comfort)과 완료 조건이 달라 따로 둔다.

**완료 조건:** Siri로 말해서 넣고·묻고·식히기를 시작할 수 있고, Apple 지능 기기에서는 비우기 분류·첫 동작·브리핑이 온디바이스로 돌며, 없는 기기에서는 규칙으로 같은 흐름이 도는 빌드가 테스트를 통과한다
**확인 명령:** cd udada/ios && xcodebuild test -project Udada.xcodeproj -scheme Udada -destination "id=$PM" 2>&1 | tail -1

## Siri·단축어 {#siri}
- [x] Siri 단축어: 적기·지금 뭐 해·식히기·닫기 {#shortcuts}
- [x] 할 일을 Siri·단축어가 찾게 (AppEntity) {#entities}
- [x] Spotlight 색인 {#spotlight}
- [x] 집중 모드 필터 {#focus-filter}
- [x] 숏폼 열면 우다다 먼저 (자동화 안내) {#automation}
- [x] 앱 안 Siri 팁·단축어 링크 {#tips}

## 온디바이스 AI {#ai}
- [x] 비우기 자동 분류·날짜 제안 {#ai-sort}
- [x] 첫 2분 동작으로 쪼개기 {#ai-step}
- [x] 하루 브리핑·주간 돌아보기 {#ai-brief}
- [x] 한 줄 읽기 보조 {#ai-parse}
- [x] 말로 쏟아내기 (기기 안 받아쓰기) {#voice}
- [x] AI 없는 기기에서 규칙으로 같은 흐름 {#fallback}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-15T01:47:52+09:00 | #shortcuts | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | 9개 단축어·한국어 문구, 실제 Siri 음성은 실기기 미확인 |
| 2026-11-15T01:47:57+09:00 | #entities | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | TaskEntity(AppEntity+IndexedEntity)+TaskQuery, testTaskEntities 통과 |
| 2026-11-15T01:48:03+09:00 | #spotlight | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | 저장마다 색인(afterPersist 훅), 결과 탭→그 날짜. 탭 이동은 실기기 미확인 |
| 2026-11-15T01:48:19+09:00 | #focus-filter | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-notify-calendar-siri.md | 걱정 알림 끄기·묶음만·나중에 숨기기, 오늘 화면 반영. 실기기 미확인 |
| 2026-11-15T01:48:26+09:00 | #automation | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md | GateIntent+잠깐 화면, 15분 통과, testGate 통과 |
| 2026-11-15T01:48:33+09:00 | #voice | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0142_feature_udada-v5-voice-photo-input.md | Mac SpeechAnalyzer 글자 95%, Vision 23/23. 실기기 마이크·카메라 미확인 |
| 2026-11-15T02:33:35+09:00 | #ai-sort | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md | Mac 실제 모델: 맞는 칸 32–33/35, 처음 보는 쏟아내기 17–18/22 |
| 2026-11-15T02:33:42+09:00 | #ai-step | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md | 흔한 일은 틀, 모르는 일만 모델 (0.6–1.1초) |
| 2026-11-15T02:33:50+09:00 | #ai-brief | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md | 규칙으로 결정 — 8표본 모두 모델이 틀보다 나빠서(지어냄·숫자 누락) |
| 2026-11-15T02:33:57+09:00 | #ai-parse | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md | 규칙 먼저(음력·공휴일·둘째 주 등), 남은 것만 모델, 답은 Parser 재검증 |
| 2026-11-15T02:34:04+09:00 | #fallback | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md | 판정 ✓ brain-fallback: 150 cases, 0 fail · BrainTests 15개 통과(macOS) · mac |
| 2026-11-15T03:30:10+09:00 | #tips | claude-code | ☐→x | .oculpm/journal/20261115/Features_to_add/0330_feature_udada-v5-records-settings-polish.md | 설정 Siri 칸 SiriTipCard+ShortcutsLink, RecordsUITests 9/9 (실제 탭은 미확인) |
| 2026-11-15T04:25:41+09:00 | #tips | claude-code | x→x |  | 판정 ✓ ** TEST SUCCEEDED ** — Pro Max·SE 각 74 통과·0 실패. 규칙 경로는 테스트, AI 경로는 Mac 모델 하네스로만(실기기 Apple 지능 미확인) · mac |
<!-- oculpm:plan-log end -->
