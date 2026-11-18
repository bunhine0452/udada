---
schema_version: 1
type: bug
slug: "udada-v5-uitest-found-bugs"
status: done
difficulty: medium
created_at: "2026-11-15T01:42:11+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/UI/SwipeRow.swift"
    op: update
  - path: "udada/ios/Udada/UI/Kit.swift"
    op: update
  - path: "udada/ios/Udada/Today/QuickAddBar.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Today/EditSheet.swift"
    op: update
  - path: "udada/ios/Shared/Model.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
related: []
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: UI 테스트로 찾은 결함 6개 고침

## 발생 원인
v5 첫 통합 빌드와 UI 테스트·실패 녹화(xcresult 의 mp4 에서 프레임 추출)로 찾았다.
1. 밀어서 연 줄의 [내일]·[나중에]를 눌러도 닫히기만 함 — 닫기용 투명 덮개를 `.offset` 뒤에 붙여서 덮개가 원래 자리(버튼 위)에 남았다.
2. 비활성 버튼이 흐려지지 않음 — `FillButton` 이 isEnabled 를 안 읽어 "한 줄 이상 써 줘"·"넣기"가 눌릴 것처럼 보였다.
3. 넣기 줄 키보드를 내릴 확실한 방법이 없음 — 연속 입력을 위해 엔터 뒤에도 포커스를 유지하는데 아래로 쓸어도 안 내려가서, 키보드와 칩 판이 할 일 줄을 덮었다. 적는 동안 토스트도 미리보기를 가렸다.
4. 지난 띠의 약속이 회색 덩어리로 보임 — 지난 약속 판정이 지금 띠에서만 됐다.
5. 고치기 저장에서 Swift 배타 접근 위반(컴파일 오류) — `data.update` 안에서 `data.settings` 를 읽었다.
6. "내일 아침로 옮겼어", "나중에로" — 조사 받침 처리 없음.

## 해결 방법
1. 덮개를 offset 앞으로(줄과 같이 움직이게). 2. `FillButtonBody` 가 `@Environment(\.isEnabled)` 로 0.38 흐림. 3. 미리보기 줄 오른쪽에 키보드 내리기 버튼, 적는 동안 토스트는 위쪽. 4. 오늘이면 모든 띠에서 지난 약속을 테두리로. 5. parts 를 바깥에서 꺼내 씀. 6. `Fmt.ro`(받침 있으면 '으로', 없거나 ㄹ이면 '로'), 나중에는 "나중에 함에 넣었어".

## 검증
- 17 Pro Max 시뮬레이터 UI 테스트 10개 모두 통과(실패하던 testTodayAddCompleteSwipeEdit·testLaterSheetAndWeek·testRestBreathFinishes 포함, 뒤 둘은 테스트 쪽 오류도 고침: 그 주에 없는 16일, 60배속에선 시계가 보이기 전에 끝남).
- 조사: 내일 아침으로 / 내일로 / 오늘 낮으로 확인.