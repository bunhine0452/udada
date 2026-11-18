---
schema_version: 1
type: feature
slug: "udada-photo-vision-keep-lines"
status: done
difficulty: high
created_at: "2026-11-15T16:15:56+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/AI/BrainFallback.swift"
    op: update
  - path: "udada/ios/Udada/AI/TextScanView.swift"
    op: update
  - path: "udada/ios/Udada/AI/TextScan.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDump.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/Eval/make_photos.swift"
    op: create
  - path: "udada/ios/Eval/make_photos2.swift"
    op: create
  - path: "udada/ios/Eval/score_photos.py"
    op: create
  - path: "udada/ios/Eval/verdict2.json"
    op: create
  - path: "udada/ios/Eval/run.sh"
    op: update
  - path: "udada/ios/UdadaMacTests/BrainFinishTests.swift"
    op: update
  - path: "udada/ios/UdadaTests/BrainTests.swift"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Features_to_add/1429_feature_udada-ai-eval-blend-find.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-voice-photo-input.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 사진을 모델이 보고 일정으로, 줄 안 잃기

## 추가 기능
사용자(11-15): "어떻게든 완벽하게 만들어 그리고 애플 인텔리전스를 활용해 엄청난 기능을 만들어봐".

- **사진 보기** (`Brain.readPhoto` · `Brain.aiSeePhoto` · `BrainRules.lines(from:ocr:)`): iOS 27 / macOS 27 의 그림 첨부(`Attachment(cgImage)` · `capabilities.contains(.vision)`)로 포스터·안내문·진료 카드·시간표에서 일정을 찾는다. 모델은 이름 + 달·날·시·분만 내고, 규칙이 글자 인식 결과와 맞춰 본다(이름 글자 70% · 숫자가 사진에 있어야 함 · 0시는 자정이 적혀 있을 때만 · 시간표는 글자 인식의 '날짜가 읽히는 줄'로 채움). 만든 줄이 비우기 정리로 들어간다.
  - iPhone `TextScanView`: 찍으면 '사진에서 찾은 일정' + Apple Intelligence 표시, '읽은 글자 전부 보기'로 언제든 원래 줄.
  - Mac `MacDump`: 그림을 끌어다 놓거나 아이폰으로 찍으면 같은 길. 못 보는 기기는 지금까지처럼 읽은 줄 그대로.
- **줄을 잃지 않는 뼈대** (`BrainRules.finish` 다시 지음): 뼈대는 규칙이 자른 조각, 모델의 카드는 조각마다 붙여 글·칸에만 쓴다. 카드가 조각의 절반(여러 장이면 60%)을 못 담으면 그 조각은 사용자의 말 그대로 규칙 카드. 모델이 한 조각을 둘로 나눈 것은 살린다.
- 자르기 더함: 말 가운데의 일단·우선·이러다·그냥, 스스로 묻는 말(~ㄹ까) 뒤, 모르겠다·싶다 뒤, 일 이름으로 끝난 쉼표. '또'는 앞말이 맺어졌을 때만. 칸: '~고 싶다'·'~킬까' 는 버리기 쪽, '꺼내기'가 '내기'(납부)로 읽히던 것 고침.

## 막힌 곳
- 처음 보는 묶음 verdict2 에서 모델 길이 규칙만보다 **더** 잃었다(9 대 6) — 그래서 뼈대를 뒤집었다.
- 파이썬 치환 묶음이 한 줄의 문자열 불일치로 통째로 안 써진 것을 평가 숫자가 안 변해서 알았다(두 번). 스크립트 파일로 옮겨 다시 적용.
- 내 확인 조건(assert)이 틀려 적용이 한 번 더 막힘.

## 검증
- `Eval/run.sh photos2`(처음 한 번, Mac 실제 모델): `photos[글자 인식만]: 일정 15개 중 … 날짜·시각까지 맞음 8 (53%) · 군말로 남는 줄 25` / `photos[모델이 그림을 봄]: … 맞음 13 (86%) · 군말로 남는 줄 2`. 조정용 photos: 84% → 100%(글자 인식만 57%). 가운데값 2.0초.
- `Eval/run.sh verdict2`: 처음 한 번 `잃은 줄 9 · 칸 정확도 46/51 (90%)`(규칙만 6 · 91%) → 뼈대를 바꾼 뒤 `잃은 줄 5 · 51/55 (93%)`. heldout `0 · 50/50 (100%)`, verdict `0 · 56/59 (95%)`, fresh `4 · 51/55 (93%)`, tune `0 · 74/74 (100%)`.
- `xcodebuild test -scheme UdadaMac`: `Executed 25 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- `xcodebuild test -scheme Udada`(iPhone 18 Pro 시뮬, 다른 작업 없이): `Executed 42 tests, with 2 tests skipped and 0 failures` + 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- Mac 실제 화면: 독서 모임 포스터 그림 → "12월 5일 오후 3시 소설 읽기" 등 세 줄, '사진에서 일정을 찾음' 표시 (스크린샷).
- 못 닿은 것: '잃은 줄 0'(verdict2 5/60, fresh 4/59 — 규칙도 못 자르는 명사 나열). 사진 평가는 전부 내가 그린 깨끗한 그림 — 실제로 찍은 사진·손글씨는 안 쟀다. iPhone 스캔 화면의 새 길은 빌드와 기존 UI 테스트만(시뮬에 그림 보는 모델이 없어 화면 미확인). 실기기 측정, Siri 결과 안 버튼, 스토어 스크린샷, TestFlight 는 안 했다.