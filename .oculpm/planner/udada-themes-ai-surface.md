---
oculpm_plan: v1
id: udada-themes-ai-surface
title: "우다다: 테마와 Apple Intelligence 표면 넓히기"
status: active
created: 2026-11-15
updated: 2026-11-15
owner: claude-code
---

종이·먹·강조 하나라는 규칙 안에서 테마를 여럿 만들고, 기기 안 AI 가 닿는 자리(스트리밍·표 문서·시각 지능·Siri 스니펫·화면 인식·위젯 관련도)를 넓힌다.

**완료 조건:** 테마를 바꾸면 iPhone·Mac·위젯이 그 색으로 바뀌고, 쏟아내는 동안 카드가 하나씩 올라오며, 표가 있는 그림에서 줄별 일정이 읽히고, iPhone 전용 넷이 빌드되어 테스트가 통과한다
**확인 명령:** cd udada/ios && xcodegen generate --quiet && xcodebuild test -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed [0-9]+ tests, |TEST (SUCCEEDED|FAILED)" | tail -2

## 테마 {#themes}
- [ ] 팔레트 다섯 벌과 바꾸는 장치 {#palette}
- [ ] iPhone 설정·Mac 메뉴에서 고르기 {#theme-ui}
- [ ] 위젯도 같은 테마로 {#theme-widgets}

## Mac 에서 확인되는 것 {#mac-checkable}
- [ ] 쏟아내는 동안 카드가 하나씩 {#stream}
- [ ] 표가 있는 문서 읽기 (문서 인식) {#tables}

## iPhone 전용 (빌드까지) {#phone-only}
- [ ] 카메라로 비추면 넣기 (시각 지능) {#visual}
- [ ] Siri 결과 안 끝내기·집중 버튼 {#snippet}
- [ ] 화면에 보이는 할 일을 Siri 가 알기 {#onscreen}
- [ ] 맞는 때에 위젯이 올라오기 {#relevance}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
<!-- oculpm:plan-log end -->
