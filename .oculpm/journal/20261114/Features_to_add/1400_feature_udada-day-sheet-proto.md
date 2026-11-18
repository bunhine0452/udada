---
schema_version: 1
type: feature
slug: "udada-day-sheet-proto"
status: done
difficulty: high
created_at: "2026-11-14T14:00:32+09:00"
session_id: "20261114-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "d83302e5-97db-4bbd-a8b1-c021ec592b33"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/day.html"
    op: create
  - path: "udada/design/DAY.md"
    op: create
  - path: "udada/design/tests/day.test.js"
    op: create
related:
  - ref: "20261106/Features_to_add/0059_feature_udada-sorter-v4.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 하루 한 장 동작판을 만들었다

## 추가 기능
사용자 요청: 기존 디자인은 무시하고, 일정·할 일·머리 리프레시를 편하게 해 주는 앱을 논문 근거로 다시 설계. 일정·할 일 쪽 논문을 새로 읽고(DAY.md) 동작판 `udada/design/day.html` 을 만들었다.

핵심 근거와 결정:
- Halder 2026(Structured 앱 957명 24,265건): 하루 종일 과제 23.1% 완료 vs 시각 있는 과제 49.9%, 그런데 77.6%가 늦게 끝남, 버림은 10일째 42.4%에서 굳음 → 할 일은 아침·낮·저녁 띠에 놓고 시각은 약속만. 띠가 지나면 조용히 다음 띠로. '나중에'는 10일 넘으면 묻기.
- Tonietto & Malkoc 2016/2019 → 띠 단위 대충 일정, 지금 줄이 다음 약속까지 실제 남은 시간과 들어갈 일을 말함.
- 2026 뽀모도로 vs 자율 휴식(176명) → 타이머가 쉬라고 하지 않고 [식히기]를 내가 누름. 1분 숨/3분 멀리 보기/10분 걷기.
- Syrek 2014·Masicampo 2011 → 하루 닫기(내일/나중에/안 해).
- Piepenbrock 2013 → 밝은 화면 기본. Fitz 2019 → 알림 하루 3번(네이티브 때).

## 동작 흐름
- 아래 한 줄에 적기: `3시 치과`→일정, `보고서 30분`→지금 띠 할 일, `내일 저녁 빨래`. 칩(날·때·길이)은 선택.
- 약속=꽉 찬 먹색 덩어리, 할 일=열린 줄, 지금=코발트 줄. 띠마다 넣은 일/빈 시간.
- 줄 누르면 고치기 시트, 지우기는 되돌리기. 식히기·하루 닫기·나중에·달력.
- 디자인: 인쇄된 시간표. 세로쓰기 띠 이름, 좁은 숫자체, 둥근 모서리·그림자·그라데이션 없음.

막힌 것: OpenAlex 가 429 로 전부 거절 → Europe PMC 로 초록 6편만 원문 확인, 나머지는 보도자료·2차 요약(DAY.md 한계에 적음).

## 검증
- `node tests/day.test.js` → `day: 0 fail` (4개 크기+키보드+어두운 화면, 전체 흐름, 한 줄 읽기 10가지). 처음엔 13 fail: 작은 화면에서 키보드가 올라오면 입력창이 밀려남 → 적는 동안 머리를 접어 해결.
- 스크린샷으로 [그만] 글자 안 보임, '10분' 줄바꿈, 토스트 겹침을 잡아 고친 뒤 다시 통과.
- 아티팩트로 게시. 실제 폰 사파리 키보드 동작과 진동은 미확인. 네이티브 미착수.