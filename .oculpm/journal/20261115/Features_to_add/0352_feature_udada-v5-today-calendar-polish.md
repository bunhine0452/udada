---
schema_version: 1
type: feature
slug: "udada-v5-today-calendar-polish"
status: done
difficulty: high
created_at: "2026-11-15T03:52:13+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/Udada/Today/EditSheet.swift"
    op: update
  - path: "udada/ios/Udada/Today/LaterSheet.swift"
    op: update
  - path: "udada/ios/Udada/Calendar/CalendarTab.swift"
    op: update
  - path: "udada/ios/Udada/UI/SwipeRow.swift"
    op: update
  - path: "udada/ios/UdadaUITests/TodayUITests.swift"
    op: create
  - path: "udada/ios/Shared/DayLogic.swift"
    op: update
  - path: "udada/ios/UdadaTests/DayLogicTests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 오늘·달력 다듬기와 결함 9개 고침

## 추가 기능
하위 세션(Opus 5.5)이 오늘·달력을 Pro Max·SE × 밝은/어두운 × 큰 글자로 돌려 보며 다듬었다.
- 고친 결함: (1) 여러 줄 붙여넣기가 한 항목이 됨(한 줄 필드가 줄바꿈을 공백으로) → `TextField(axis: .vertical)` + Return 은 여전히 넣기, 부수 효과로 연속 입력 사이에 키보드가 안 내려갔다 올라옴. (2) 할 일 줄·월 칸에서 시작한 세로 스크롤이 3번 중 2번 먹힘, 주 띠 밀기가 XCUITest 에서 죽음 → 옆 방향일 때만 시작하는 UIKit 팬 `HorizontalPan` 하나로 줄·주·월 밀기 통일. (3) 스크롤하면 상태 막대 밑으로 내용이 비침 → 머리를 위쪽 safe-area inset 에 단색 바탕으로. (4) 큰 글자에서 고정 머리가 SE 의 285pt 를 차지·날짜 줄바꿈·주 숫자 "1/0" → 큰 글자에선 머리가 함께 스크롤. (5) 지금으로 스크롤하다 빈 날 카드를 가림. (6) 콜드 스타트 `udada://add` 가 커서를 안 줌(달력 넣기 줄도 반응하던 것 정리). (7) 날짜 고르기 시트가 열리자마자 닫힐 수 있음. (8) 고치기: 요일 칩 SE 넘침 → 7칸 균등, 이날만 상태에서 반복을 고르면 조용히 무시 → 반복 전체로 전환, 제목 Return 이 줄바꿈, 처음 시각은 다음 30분. (9) SE 에서 실수로 끝까지 밀림 → 기준을 max(줄의 60%, 버튼+60pt), 끝까지일 때 실행될 동작만 보임.
- 다듬기: 메뉴에 '다른 띠로'(지난 띠 제외)·다른 날엔 '오늘로', 같은 VoiceOver 동작; 끝낸 줄은 밀면 되살리기만; 지난 띠에는 놓기 금지, 놓기 강조는 중립색; 토스트는 넣기 줄 바로 위·시트가 열리면 숨김; 큰 글자 재배치(띠·약속·지금 카드·나중에·달력 머리, 식히기는 아이콘만); 시트는 단색 바탕(글래스 없음); 빈 날은 "0 / 0" 요약 숨김. 하루 열기 AI 카드는 뺌(브리핑은 규칙이고 지금 카드와 겹쳐서).
- 이어서 내가: 매일 하는 할 일(물 한 잔)이 주 띠·월 칸의 모든 날에 점을 찍던 것 → `DayLogic.hasEntries` 에서 매일 반복 할 일은 점에서 뺌(약속은 그대로). FlowUITests 미리보기 검사는 라벨이 바뀔 때까지 기다리게.
- 끌어 옮기기: 남겨 둠. 최종 빌드에서 XCUITest 의 합성 길게 누르고 끌기는 메뉴를 열어 버려 테스트는 뺐고, 띠 옮기기는 '다른 띠로' 메뉴로 테스트. 실제 손가락 끌기는 기기에서 확인 필요.

## 검증
- 하위 세션 최종: TodayUITests SE `Executed 13 tests, with 1 test skipped and 0 failures`, Pro Max 같음(건너뛴 1개는 스크린샷 전용), FlowUITests SE·Pro Max 10/10.
- 점 수정: `scratchpad/logic/h/run.sh` → `logic: 68 cases, 0 fail` (매일 할 일 시리즈는 점 없음 확인 추가).
- 하위 세션이 시뮬레이터 둘·파생 데이터를 지움(남은 2.7MB 스크린샷). 미확인: VoiceOver 손 점검, 동작 줄이기 눈 확인, 어두운 화면 큰 글자.