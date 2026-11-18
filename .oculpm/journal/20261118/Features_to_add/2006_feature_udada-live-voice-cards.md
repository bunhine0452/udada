---
schema_version: 1
type: feature
slug: "udada-live-voice-cards"
status: done
difficulty: medium
created_at: "2026-11-18T20:06:38+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/LiveDump.swift"
    op: create
  - path: "udada/ios/Udada/AI/VoiceDumpView.swift"
    op: update
  - path: "udada/ios/Udada/Mind/DumpFlow.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/LiveDumpTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/project.yml"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-voice-photo-input.md"
    kind: "followup"
  - ref: "20261118/Features_to_add/1955_feature_udada-replan-tool-calling.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 말하는 동안 카드가 떨어지는 쏟아내기

## 추가 기능
사용자(11-18): "2번으로고고고" (2번 = 말하는 동안 카드가 실시간으로 떨어지는 쏟아내기).

- 말로 쏟아내기 화면을 카드 중심으로 다시 지었다. 받아쓴 글이 자랄 때마다 **말이 끝난 조각**만 카드로 떨어지고, 아직 말하는 중인 끝 조각은 점선 줄로 기다린다. 1.6초 조용하면 끝 조각도 카드가 된다.
- 카드는 규칙이 바로 만든다(기다림 없음). Apple Intelligence 가 그 뒤로 한 장씩 칸을 다시 보고 표시가 붙는다(`Brain.suggest`).
- 받아쓰기가 앞 글을 고쳐 써도 같은 조각의 카드는 그대로 둔다 — 같은 id · 다듬은 칸 (`LiveDump.reconcile`).
- '다 말했어 · 카드 N장' → 적어 둔 글이 없었으면 그 카드들로 **바로** 한 장씩 넘기기가 열린다 (전에는 글 칸으로 돌아가 '정리하기'를 또 눌러야 했다).
- 확인용 `-udSay <글>`: 마이크 대신 그 글을 한 낱말씩 흘린다 (시뮬레이터 · UI 테스트).

## 검증
- `xcodebuild test -scheme UdadaMac`: `Executed 72 tests, with 0 failures` / `** TEST SUCCEEDED **` (LiveDump 테스트 4개).
- iPhone: 단위 `Executed 41 tests, with 0 failures`, UI 8개(말하는 동안 카드 · 한 주 풀기 · 비우기 흐름 여섯) `0 failures` / `** TEST SUCCEEDED **`.
- 화면: 시뮬레이터에서 `-udSay` 로 네 조각을 흘려 다섯 순간을 찍었다 — 둘째 순간에 카드 2장 + 점선의 '월세 오르면', 끝에 4장, 그 뒤 AI 표시가 한 장씩 붙음(실제 모델).
- **안 한 것: 진짜 마이크로 말해 보기.** 실제 받아쓰기는 낱말이 뭉쳐서 오고 앞 글을 고쳐 쓰는데, 그 박자에서 카드가 어떻게 떨어지는지는 기기에서 봐야 한다. Mac 에는 이 화면이 없다.