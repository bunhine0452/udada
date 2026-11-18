---
oculpm_plan: v1
id: udada-english
title: "우다다 영어 지원"
status: active
created: 2026-11-18
updated: 2026-11-18
owner: claude-code
---

**완료 조건:** 기기 언어가 영어일 때 화면 글이 전부 영어로 나오고, "dentist tomorrow 3pm" 한 줄과 영어로 쏟아낸 말이 한국어와 같은 짜임(규칙이 자르고 모델이 읽기)으로 나뉘어 들어가, 영어권 사람이 TestFlight 로 받아 바로 쓸 수 있다
**확인 명령:** cd udada/ios && xcodegen generate --quiet && xcodebuild test -project Udada.xcodeproj -scheme UdadaMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed [0-9]+ tests, |TEST (SUCCEEDED|FAILED)"

## 읽기 규칙 {#rules}
- [ ] 영어 한 줄 읽기 테스트부터 (지금 빨강) {#red-test}
- [ ] 한 줄 읽기·자르기·시키기·답장 규칙 영어판 {#parse-en}
- [ ] 모델 지시문 영어판과 영어 평가 묶음 {#prompts-en}

## 화면과 스토어 {#surface}
- [ ] 화면 글을 문자열 카탈로그로 (한글 2939개) {#strings}
- [ ] 사용법·영상·스크린샷 영어판 {#guide-film-en}
- [ ] 영어 스토어 글 (AI 가 하는 일을 맨 앞에) {#store-en}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
<!-- oculpm:plan-log end -->
