---
schema_version: 1
type: feature
slug: "udada-v5-on-device-ai-brain"
status: done
difficulty: superhigh
created_at: "2026-11-15T02:33:25+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainFallback.swift"
    op: create
  - path: "udada/ios/Udada/AI/AIBadge.swift"
    op: create
  - path: "udada/ios/UdadaTests/BrainTests.swift"
    op: create
  - path: "udada/design/AI.md"
    op: create
related: []
tags:
  - "우다다"
  - "research"
  - "mcp-tool"
---
[x] 우다다: 기기 안 AI 두뇌 (Foundation Models)

## 추가 기능
사용자 요청 "아이폰 내장 AI를 가장 잘 활용할 수 있는 방법을 강구하고 구현". 하위 세션(Opus 5.5)이 Xcode 27.2 SDK 인터페이스를 읽고, 이 Mac 의 실제 모델(macOS 27.0.1, AFM 3 Core Advanced, 8192 토큰, 한국어 — `supportsLocale(ko_KR)` 로 확인해야 함, `supportedLanguages` 는 ko-Kore-KR 로 저장돼 contains("ko") 가 false)로 프롬프트를 실제 돌려 조정했다. 전략 문서 `udada/design/AI.md`.
- 비우기 정리 `organize`: 규칙이 한국어 연결 어미로 먼저 자르고, 모델은 한 줄씩 다듬고 칸을 고른다(@Generable 가이드 생성, 낮은 온도, 6초 넘거나 오류면 규칙). 가드: 입력에 없는 낱말 카드는 버림, 사용자가 안 말한 날짜·시각은 안 읽음, '버리기'는 망설임 말(할까 말까·언젠가)일 때만 믿음, 걱정은 사용자 말 그대로, 시각 말을 잃으면 원문 복원. 매달린 "~하고" 0/35, 맞는 칸 32–33/35, 처음 보는 쏟아내기 17–18/22.
- 첫 동작: 흔한 일은 다듬은 틀("보고서 초안" → "문서 열고 제목만 쓰기"), 모르는 일만 모델("고양이 사료 주문" → "앱 열고 고양이 사료 검색하기") — 흔한 일에서 모델이 지어내는 것("운동화 신고 거실로 나가기")을 막으려고.
- 걱정: 모델은 '내 손 안인가'와 작은 한 걸음만("월세 오르면 어떡하지" → "임대료 명세서 확인하기"), 보여 주는 문장은 규칙 문장(모델의 위로 문장이 막연해서). 위기 말("그냥 사라지고 싶다")은 모델을 부르지 않고 109 / 1577-0199.
- 한 줄 읽기 보조: 규칙이 먼저("세 시", 공휴일, 음력 설날·추석, 월말, 다음 달 둘째 주 화요일, 퇴근하고), 남은 것만 모델, 답은 Parser 로 다시 읽혀야 받음.
- 하루 브리핑·하루 닫기·주간 돌아보기는 규칙만: 8개 표본 모두 모델이 틀보다 나빴다(빈 날에 '아침 식사'를 지어냄, 닫기에서 숫자를 빼먹음). API 는 async 그대로라 화면은 이미 연결됨.
- AI 가 없거나 꺼져도 같은 타입을 규칙으로 돌려준다(fromAI=false). 배지는 fromAI 카드에만.

## 검증
- 규칙 하네스 `scratchpad/brain/fallback/main.swift` → `brain-fallback: 150 cases, 0 fail`.
- `UdadaTests/BrainTests.swift` 를 실제 Brain/규칙과 macOS XCTest 로 → `Executed 15 tests, with 0 failures`.
- 모델 하네스로 실제 출력 확인(위 예시들), 조용할 때 지연 1.3–3초(쏟아내기 3–7개)·0.6–1.1초(첫 동작). 부하 중 6초 초과·가드레일 서비스 오류(SensitiveContentAnalysisML error 15) 때 규칙으로 깔끔히 넘어감.
- 대역 파일 삭제 후 실제 트리 `xcodebuild build` → BUILD SUCCEEDED. 실제 아이폰 측정은 안 함.