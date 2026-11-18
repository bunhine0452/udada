---
schema_version: 1
type: feature
slug: "udada-v5-voice-photo-input"
status: done
difficulty: high
created_at: "2026-11-15T01:42:10+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/VoiceInput.swift"
    op: create
  - path: "udada/ios/Udada/AI/VoiceDumpView.swift"
    op: create
  - path: "udada/ios/Udada/AI/TextScan.swift"
    op: create
  - path: "udada/ios/Udada/AI/TextScanView.swift"
    op: create
  - path: "udada/ios/UdadaTests/SensesTests.swift"
    op: create
related: []
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 말로 쏟아내기와 사진으로 넣기

## 추가 기능
하위 세션(Opus 5.5)이 만든 기기 안 인식 입력을 비우기 흐름에 연결했다(비우기 탭의 [말로]·[사진으로], 쏟아내기 화면 버튼, `udada://dump/voice|photo`).
- `VoiceInput`: iOS 26+ SpeechAnalyzer+SpeechTranscriber(기기 안), 한국어 모델이 없으면 내려받는 동안 SFSpeechRecognizer(기기 안 가능하면 기기 안, 아니면 서버 — 화면에 알림). 3분 상한, 전화·이어폰 빠짐·백그라운드에서 멈추고 글은 남김. 잠깐 멈췄다 이어 말하면 새 줄 → 정리 카드 한 장이 되기 쉽다. `AssetInventory.reserve` 를 먼저 불러야 설치된 모델을 쓰는 함정을 Mac 에서 발견해 고침.
- `VoiceDumpView`: 열자마자 듣기, 큰 마이크 키, 먹색 막대 레벨, [다시]/[다 말했어], 권한 거절·불가 상태 안내.
- `TextScan`: iOS 18 Swift Vision `RecognizeTextRequest`(정확도, ko-KR+en-US), 기울기 보정 → 위에서 아래로 줄 묶기, 네모·체크·글머리표와 손으로 그린 네모의 오인식(口·ㅁ·[·|) 제거, 기호만·쪽 번호·날짜 머리줄·중복 제거.
- `TextScanView`: 앨범 또는 카메라(VisionKit 라이브 텍스트 지원 시), 고칠 수 있는 체크 목록 → [N개 가져오기].

## 검증
- Mac 의 실제 Vision 으로 하네스: 고딕 정자·4°·10° 기울임, 나눔손글씨 정자·−6°, 일정표 화면 캡처 → `lines exact 23/23 · char accuracy 100.0%` (처음 20/23, 손그림 네모 규칙 2개로 고침).
- 받아쓰기: `say -v Yuna` 음성을 앱의 변환기로 ko_KR SpeechAnalyzer 에 → 글자 약 95%(택배→특별 한 곳), 다른 클립은 완전 일치. 조립 로직 `23 pass, 0 fail`. 우리 프로젝트 테스트에서 SensesTests 7개 통과.
- 실기기 마이크·카메라·권한 창은 미확인.