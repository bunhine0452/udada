---
schema_version: 1
type: feature
slug: "udada-ai-eval-blend-find"
status: done
difficulty: high
created_at: "2026-11-15T14:29:49+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Eval/run.sh"
    op: create
  - path: "udada/ios/Eval/score.py"
    op: create
  - path: "udada/ios/Eval/score_find.py"
    op: create
  - path: "udada/ios/Eval/tune.json"
    op: create
  - path: "udada/ios/Eval/heldout.json"
    op: create
  - path: "udada/ios/Eval/fresh.json"
    op: create
  - path: "udada/ios/Eval/verdict.json"
    op: create
  - path: "udada/ios/Eval/find.json"
    op: create
  - path: "udada/ios/Eval/find-verdict.json"
    op: create
  - path: "udada/ios/Udada/AI/BrainFallback.swift"
    op: update
  - path: "udada/ios/Udada/AI/Finder.swift"
    op: create
  - path: "udada/ios/Udada/AI/BrainPrompts.swift"
    op: update
  - path: "udada/ios/Udada/AI/Brain.swift"
    op: update
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacFind.swift"
    op: create
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
  - path: "udada/ios/Udada/Intents/UdadaIntents.swift"
    op: update
  - path: "udada/ios/Udada/Intents/UdadaShortcuts.swift"
    op: update
  - path: "udada/ios/Udada/Intents/Snippets.swift"
    op: update
  - path: "udada/ios/Udada/App/DeepLink.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Calendar/CalendarTab.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/FinderTests.swift"
    op: create
  - path: "udada/ios/UdadaTests/BrainTests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/design/AI.md"
    op: update
related:
  - ref: "20261115/Bugs/1312_bug_udada-brain-bin-tag-leak.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/1312_feature_udada-apple-intelligence-intro.md"
    kind: "followup"
  - ref: "20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mac"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 모델 품질을 숫자로 재고 말로 찾기 추가

## 추가 기능
사용자(11-15): "Apple Intelligence와 함께 최고의 앱으로 만들어줘!!" 도중에 Mac 창 지적 둘: 위쪽 버튼이 신호등과 높이가 안 맞음 → "애초에 저 두 버튼이 저기가 맞아? 쏟아내기는 위치가 이상해".

- **평가 하네스** `ios/Eval/`: Mac 앱의 `-udEval <묶음> <결과>` 가 실제 기기 안 모델로 돌리고 끝낸다. `Eval/run.sh <묶음>`(EVAL_NOAI=1 규칙만 · EVAL_RAW=1 원문 그대로). 라벨 묶음: tune 24 · heldout 16 · fresh 20 · verdict 20 (쏟아내기), find 24 · find-verdict 20 (물음 읽기).
- **쏟아내기 고침** `BrainFallback`: `blend`(모델 칸 + 규칙 칸: 글에 또렷한 망설임·걱정 말투·2분짜리·큰일 낱말은 규칙이), 새 자르기(걱정 끝말·마음 끝·'해야 돼' 뒤·메모 맺음 '-기/함/것'·그래서/그래도), 푸념 조각은 카드로 안 만듦, 걱정 말투라도 '해야 함'으로 맺으면 할 일.
- **말로 찾기** `Finder.swift` + `Brain.find`: 모델은 물음을 읽기만(낱말·때·상태), 찾기와 답 한 줄은 규칙이 실제 기록으로. 낱말은 모델, 종류·상태·또렷한 때는 규칙(`FindRules.checked`). iPhone: 달력 탭 돋보기 → `FindView`, `udada://find?q=`, Siri "우다다에서 찾기"(`FindIntent` + 스니펫, App Shortcut 10개째). Mac: ⌘F · 오른쪽 칸 '말로 찾기' → `MacFind`.
- **Mac 창 배치**: 위쪽 줄은 신호등만. 주 이동 화살표는 한 주 띠 양옆, '오늘로'는 날짜 옆, 쏟아내기는 한 줄 넣기 칸 옆(넣는 길 두 가지를 한 줄에). ⌘←/→ 는 메뉴로.

## 막힌 곳
- 처음엔 모델과 규칙의 칸 정확도가 같았다(받아쓰기 말투). 어려운 말투 묶음을 따로 써서야 차이가 보였다.
- 모델에게 원문을 주는 실험은 더 나빴다(잃은 줄 tune 0→8, heldout 0→7, fresh 5→10) — 버림.
- 내가 넣은 '-기/것' 끊기가 "나빠지는 것 같아서 · 적금 만기 · 전세 사기 당하면"을 잘못 끊었다 → 예외. 그 예외에 "하기"를 잘못 넣어 '전화하기' 끊기가 죽었다가 뺌.
- 풀어 쓴 한글(NFD, 실행 인자·주소)은 정규식에 안 걸려 iPhone 찾기 답이 "‘오늘 치과 시야’"로 나왔다 → 딥링크와 FindRules 에서 모아 쓴 꼴로.

## 검증
- `Eval/run.sh` (Mac 실제 모델, 상태 ready): heldout `eval: 잃은 줄 0 · 꼬리표 0 · 남는 카드 0 · 칸 정확도 50/50 (100%)`, verdict `잃은 줄 7 · 칸 정확도 47/52 (90%)`(처음 한 번은 6 · 91%), fresh `잃은 줄 5 · 49/54 (91%)`, tune `0 · 73/74 (99%)`. 규칙만: heldout 96% · verdict 9·86% · fresh 11·81%. 고치기 전: tune 3·90% · heldout 0·86% · fresh 8·82%.
- 물음 읽기: find(조정용) 29% → 91%, find-verdict(처음 한 번) `통째로 맞음 16/20 (80%)`, 규칙만 85%.
- `xcodebuild test -scheme UdadaMac`: `Executed 21 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- iOS 전체(`-scheme Udada`, iPhone 18 Pro 시뮬): `Executed 42 tests, with 2 tests skipped and 1 failure` / `** TEST FAILED **` — testTodayAddCompleteSwipeEdit "옮김 토스트". 평가를 같이 돌리던 중이었고, 단독 3회는 `passed` ×3 / `** TEST SUCCEEDED **`. 전체 실행은 마지막 BrainFallback 예외 수정 **전**에 시작했다(그 뒤로는 Mac 21개와 iOS 단위 35개만 다시 돌림).
- 화면: Mac 찾기(실제 모델, "오늘 · ‘치과’ · 약속 — 오늘 15:00" + Apple Intelligence 표시) · Mac 창 머리 · iPhone 찾기(UI 테스트 testFindAnswersFromRecords 통과) 스크린샷 확인.
- 목표 대비: 칸 90% 는 넘었고 '잃는 줄 0'은 heldout 에서만. 못 한 것: 실제 iPhone 에서 재기, 사진을 모델에 바로, Siri 결과 안 버튼, Siri 찾기 실행 확인, 스토어 스크린샷. 이 변경은 TestFlight 에 올리지 않았다(1.0 이 심사 중).