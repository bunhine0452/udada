---
schema_version: 1
type: bug
slug: "udada-v5-parser-evening-words"
status: done
difficulty: low
created_at: "2026-11-15T02:33:25+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/Parser.swift"
    op: update
  - path: "udada/ios/UdadaTests/ParserTests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0059_feature_udada-v5-korean-parser.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: '7시 모임'을 저녁으로 읽기

## 발생 원인
한 줄 읽기는 오전·오후 표시가 없을 때 날을 말했으면 7–11시를 그대로 오전으로 읽었다. 그래서 "다음 주 수요일 7시 동창 모임", "내일 8시 회식", "매주 일요일 7시 저녁 예배"가 아침 약속이 됐다(AI 두뇌 세션이 찾아 보고).

## 해결 방법
`Shared/Parser.swift`: 원문에 저녁에 하는 일 낱말(회식·모임·동창·술자리·한잔·맥주·소주·와인·파티·데이트·공연·콘서트·영화·뒤풀이·야식·저녁)이 있으면 표시 없는 7–11시를 저녁으로. 오전·아침 같은 표시가 있으면 그대로("내일 아침 7시 모임" → 07:00). '술'만으로는 안 잡는다("7시 수술").

## 검증
- `sh scratchpad/parser/build.sh` → `parser: 154 cases, 0 fail` (새 사례 7개: 동창 모임 19:00, 회식 20:00, 영화 19:00, 저녁 약속 19:30, 내일 9시 회의 09:00 유지, 아침 7시 모임 07:00, 7시 수술). 예전 한계를 적어 둔 "7시 저녁 예배" 사례는 19:00 으로 고침. `UdadaTests/ParserTests.swift` 다시 생성.