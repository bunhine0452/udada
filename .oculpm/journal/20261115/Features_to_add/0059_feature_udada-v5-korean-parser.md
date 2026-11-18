---
schema_version: 1
type: feature
slug: "udada-v5-korean-parser"
status: done
difficulty: high
created_at: "2026-11-15T00:59:24+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/Parser.swift"
    op: create
  - path: "udada/ios/UdadaTests/ParserTests.swift"
    op: create
related:
  - ref: "20261114/Features_to_add/1400_feature_udada-day-sheet-proto.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 한국어 한 줄 읽기 파서

## 추가 기능
v5 재탄생(사용자 11-15: 가장 편안한 UI·많은 기능·Siri/AI)의 첫 부품. 빠른 넣기 줄에 `내일 3시 치과`, `보고서 30분`, `매주 월수금 아침 운동` 처럼 한 줄로 적으면 날·시각·길이·띠·반복을 규칙으로 읽는다. day.html 의 JS parse() 를 옮기고 넓혔다. 하위 세션(Opus 5.5)에 위임해 만들었다.

- `Shared/Parser.swift` (Foundation 만, 정규식은 static 으로 한 번만 컴파일, 21µs/회): `Parser.parse(_:now:parts:calendar:) -> Parsed`, `Parser.split(_:)` (여러 줄 붙여넣기, 글머리표 제거).
- 날: 오늘/내일/모레/글피/낼, 요일(가장 가까운 앞날), 이번 주·다음 주 X요일, 주말·다음 주말, N일/주/개월 뒤, M월 D일·M/D·연도, D일까지.
- 시각: 오전/오후/아침/저녁/밤/새벽 H시 반·M분, HH:MM, 정오, N분/시간 뒤, 범위(3시부터 5시까지, 15:00-16:30 → 길이).
- 띠 단어는 조사가 붙거나 날 뒤에 올 때만 제목에서 지움(`저녁 약속`은 제목 유지, 띠만 저녁).
- 반복: 매일·평일·주말마다·매주 월수금·X요일마다·매달 N일·N일마다·격일·아침마다.
- 결정: 일요일에 말하는 '이번 주'는 내일부터의 주로 본다(`다음 주 수요일` = 11-25). 반복 규칙은 명시된 날로 쳐서 `매일 9시`는 09:00.
- 안 하는 것: 격주(RepeatRule 에 주 간격 없음), `이번 주` 단독, `24:00`, `N주마다`. `버전 1.2` 는 1월 2일로 읽힘(M.D 와 구별 불가) — 미리보기 줄에서 바로 보임.

## 검증
- 하네스 `scratchpad/parser/build.sh` → `parser: 147 cases, 0 fail` (지시한 필수 예시 15개 포함).
- iOS 타입 검사(`swiftc -typecheck -target arm64-apple-ios17.0-simulator`) 통과, Swift 6 모드도 깨끗.
- `UdadaTests/ParserTests.swift` 는 같은 사례로 생성했고 아직 프로젝트 안에서 돌리지 않음(앱 빌드 후 실행).