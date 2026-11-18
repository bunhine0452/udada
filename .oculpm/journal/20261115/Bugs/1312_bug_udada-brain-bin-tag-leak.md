---
schema_version: 1
type: bug
slug: "udada-brain-bin-tag-leak"
status: done
difficulty: low
created_at: "2026-11-15T13:12:54+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/AI/BrainFallback.swift"
    op: update
  - path: "udada/ios/UdadaMacTests/BrainFinishTests.swift"
    op: create
related:
  - ref: "20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md"
    kind: "followup"
tags:
  - "우다다"
  - "ai"
  - "mcp-tool"
---
[x] 우다다: 비우기 카드에 칸 이름이 새고 줄이 빠짐

## 발생 원인
Mac 쏟아내기를 실제 기기 안 모델(macOS 27.2)로 돌려 보니: ① 카드 글 끝에 칸 이름이 샜다 — "엄마한테 전화해야 돼 (now", "… (date", "… (drop". ② 여섯 조각 중 걱정("월세 오르면 어떡하지")이 통째로 사라졌다. `BrainRules.finish` 는 놓친 조각이 1/3 이하면 그냥 통과시켰고, 규칙 자르기는 "어떡하지" 뒤에서 안 끊어 걱정이 다음 일과 한 조각이었다. iPhone 과 같은 코드라 iPhone 에도 해당.

## 해결 방법
- `stripBinTag`: 글 끝의 (now|date|worry|drop) 와 짝 없는 여는 괄호를 뗀다. 'update 문서'처럼 낱말 속은 안 건드림.
- `finish`: 모델이 빠뜨린 조각은 규칙 카드로 끝에 붙인다(쏟아낸 것은 하나도 안 잃음). 1/3 넘게 놓치면 여전히 통째로 규칙.
- `splitSpeech`: 걱정 끝말(어떡하지·어떡해·어쩌지…) 뒤에서 끊는다.

## 검증
- `BrainFinishTests` 4개 포함 `Executed 17 tests, with 0 failures`.
- 같은 글로 Mac 앱을 다시 띄워 스크린샷: 괄호 없음, '월세 오르면 어떡하지'가 걱정 칸에. (그 실행은 규칙 경로였음 — 모델 경로의 실제 재확인은 못 함.)