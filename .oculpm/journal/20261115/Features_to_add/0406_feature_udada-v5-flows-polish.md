---
schema_version: 1
type: feature
slug: "udada-v5-flows-polish"
status: done
difficulty: superhigh
created_at: "2026-11-15T04:06:02+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: update
  - path: "udada/ios/Udada/Mind/DumpPlan.swift"
    op: create
  - path: "udada/ios/Udada/Mind/DumpFinishCard.swift"
    op: create
  - path: "udada/ios/Udada/Mind/FlowParts.swift"
    op: create
  - path: "udada/ios/Udada/Mind/MindView.swift"
    op: update
  - path: "udada/ios/Udada/Mind/WorryFlow.swift"
    op: update
  - path: "udada/ios/Udada/Rest/RestView.swift"
    op: update
  - path: "udada/ios/Udada/Rest/FocusView.swift"
    op: update
  - path: "udada/ios/Udada/Rest/CloseDayView.swift"
    op: update
  - path: "udada/ios/Udada/Rest/GateView.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowsUITests.swift"
    op: create
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 비우기·식히기·집중·닫기 흐름 다듬기

## 추가 기능
하위 세션(Opus 5.5)이 전체 화면 흐름을 Pro Max·SE × 밝은/어두운 × 큰 글자로 돌려 보며 다듬었다. 새 파일 `Udada/Mind/DumpPlan.swift`·`DumpFinishCard.swift`·`FlowParts.swift`.
- 큰 버그: 전체 화면(cover)이 떠 있는 동안 `store.cover` 를 바꾸면 SwiftUI 가 조용히 버리고 오늘로 돌아감 → 비우기 끝의 '숨 1분', 집중의 '식히기', 잠깐 화면의 '먼저 할래'·'숨'이 사실상 안 됨. 각 흐름이 같은 cover 안에서 다음 화면으로 넘어가게(`FlowNext`), 화면 녹화로 확인.
- 비우기: 쓰는 동안 소음 막대를 한 줄로 접고 마이크·카메라를 정사각 키로(SE 키보드 위에 다 들어감), 예시는 빈 쪽에서만, Writing Tools 끔, 닫아도 안 정한 줄은 초안으로 남아 다시 열면 복원(비우기 탭에 "쓰던 게 N줄 남아 있어"). AI 끔이면 규칙 카드 즉시, 켬이면 '나누는 중'에 사용자 줄을 보여 주고 1.5초 뒤 '기다리지 않고 나누기'. 카드 밀기(오른쪽 제안대로·왼쪽 버리기, 뒤에 라벨, 기준점 딸깍, 첫 카드 살짝 흔들기, VoiceOver 동작), 두 번 눌러 건너뛰기 방지, 날짜 칩 줄바꿈·중복 제거·토/일 주말 날짜 바로잡음·'나중에' 추가·"내일 15:00" 표기, 카드를 머리와 칸 사이 가운데로(빈 가운데 해결), 위기 줄엔 카드 위에 109/1577-0199.
- 들어가는 자리: 줄마다 Parser 로 다시 읽어 "내일 3시 치과" → 내일 15:00 약속(제목에서 날짜 낱말 뺌). 지금 → 오늘 지금 띠(첫 개 핀), 날짜 → 고른 날·띠 또는 나중에 함(전엔 '나중에' 제안이 내일로 감), 걱정 → 사용자 말 그대로, 버리기 → 없음. 카드·DumpLog 는 일찍 닫아도 한 번만.
- 걱정 시간: 위기 걱정은 바로 연락 카드·'할 일로' 없음, 다음 카드 조언 미리 가져옴, 작은 걸음을 할 일 제목으로(걱정은 메모에), 남은 시간은 분 단위.
- 식히기: 쉬는 중·끝 화면은 늘 밤색, 상태 막대 숨김, 새 숨 박자(종이 고리·점선=첫 들숨·박하 원판, 1.5초 준비, 진동은 시계 기준으로 단계 바뀔 때 정확히, 동작 줄이기면 크기 대신 투명도), 3·10분 시계는 초당 한 번 애니메이션 없이. RestLog 한 번.
- 집중: 예상 길이에 눈금, 넘으면 먹색으로 이어감(빨강 없음), 끝냈어 → 2.2초 예상 대 실제 요약 → 토스트, 그만 → "N분 집중했어. 할 일은 그대로 있어." FocusLog 한 번.
- 하루 닫기: 카드 밀기(오른쪽 내일·왼쪽 안 해), 뒤로 가기로 마지막 선택 되돌림(버린 것도 복구), 새 먹 도장(스프링 + 닿을 때 진동 + 살짝 번지는 먹 + 고정 결, 동작 줄이기면 페이드), 닫기 문장이 '내일 처음'을 반복 안 함, 하루에 CloseLog 하나(다시 닫으면 더함). 잠깐 화면은 코발트를 주 버튼에만, 큰 글자에선 전체 스크롤.
- 기다리는 화면에 반복 애니메이션 없음(식히기 고르기·오늘 시작 후 CPU 0.0%) — XCUITest idle 대기 문제 해결. RestLog·FocusLog·doneAt 은 `store.now`.

## 검증
- 하위 세션: Pro Max `Executed 18 tests, with 0 failures … ** TEST SUCCEEDED **`(단위 35 + FlowUITests 10 + FlowsUITests 8), SE 같음 18/18, 마지막 편집기 수정 후 SE 비우기 테스트 4/4 재통과.
- 스크린샷 전후(scratchpad/flows/shots/): 비우기·걱정·식히기·집중·닫기·잠깐, SE 어두운 화면, SE 큰 글자 결함 3개 전후.
- 미확인: 실기기 진동 느낌, 동작 줄이기·VoiceOver 는 코드로만. -udNoAI 로 UI 테스트는 AI 경로를 안 탐(앞선 모델 실행에서 생각 중 화면·배지·걱정 걸음 확인).