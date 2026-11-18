---
schema_version: 1
type: bug
slug: "udada-v5-daylogic-tests-bugs"
status: done
difficulty: high
created_at: "2026-11-15T02:18:53+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/DayLogic.swift"
    op: update
  - path: "udada/ios/UdadaTests/DayLogicTests.swift"
    op: create
  - path: "udada/ios/Shared/Model.swift"
    op: update
  - path: "udada/ios/Udada/AI/_PendingBrain.swift"
    op: delete
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 하루 로직 테스트로 버그 8개 고침

## 발생 원인
하위 세션(Opus 5.5)이 `Shared/DayLogic.swift` 에 67개 사례 테스트를 쓰자 원래 코드에서 9개가 실패했다.
1. 반복 일정의 하루치를 두 번 누르면(위젯·화면이 옛 항목을 들고 있을 때) 같은 날에 복제본 둘 — `materialize` 가 이미 떼어 낸 항목을 찾지 않고 늘 새로 만들었다.
2. 떼어 낸 항목이나 원본에서 '반복 전체 지우기'를 하면 안 끝낸 다른 하루치가 남음 — `.occurrence` 경로만 지웠다.
3. 옛 화면에서 반복 하루를 지우면 이미 떼어 낸 그날 항목이 남아 계속 보임.
4. 오늘의 하나를 다른 날로 옮기면 그날 '하나'가 둘 — move 가 핀 유일성을 안 봤다.
5. settle 로 지난 날의 핀 항목이 넘어오면 오늘 '하나'가 둘.
6. 띠 경계를 걸친 약속(11:30–12:30, 17:00–19:00)이 다음 띠의 빈 시간에서 안 빠짐 — 시작 띠에서만 셌다.
7. 겹친 약속(09:00–10:00 + 09:30–10:30)을 120분으로 이중 계산.
8. (내가 고침) `DayKey.date(minute:)` 가 자정부터 흐른 분을 더해 서머타임 바뀌는 날 알림이 1시간 어긋남(뉴욕 3/8·11/1, 서울은 영향 없음).

## 해결 방법
1. 그 시리즈·그날 항목이 있으면 그것을 돌려줌 → toggleDone·move·pin·toWorry 가 옛 Entry 로도 같은 항목에 작동. 2·3. 비공개 `removeSeries(sid)` 하나로 두 경로 통일(끝낸 하루치는 기록으로 남김), 하루 지우기는 떼어 낸 항목도 지움. 4·5. 옮겨 갈 날에 이미 핀이 있을 때만 핀을 뗌. 6·7. 비공개 `busyMinutes` 가 모든 약속을 띠 창으로 자르고 겹침을 합친다. 8. 시·분 DateComponents 로 벽시계 시각을 만든다(1440분 넘으면 다음 날).
공개 타입·시그니처는 그대로.

## 검증
- 하네스 `scratchpad/logic/h/run.sh` → `logic: 67 cases, 0 fail` (반복 매일·평일·주말·여러 요일·31일/2월·N일마다·연말·뉴욕 서머타임, 떼어 내기·옮기기·지우기·핀·settle·띠 용량·지금 줄·DayKey·Codable 옛 파일).
- 하위 세션 시뮬레이터 `xcodebuild test -only-testing:UdadaTests` → `** TEST SUCCEEDED **` (트리 사본, 내 임시 대역 파일 제외 — 그 대역은 이제 지움).
- 서머타임: 뉴욕 2026-03-08·11-01 에 `date(minute: 600)` → 10:00, `1500` → 다음 날 01:00 출력 확인. 대역 삭제 후 실제 트리 `xcodebuild build` → BUILD SUCCEEDED.