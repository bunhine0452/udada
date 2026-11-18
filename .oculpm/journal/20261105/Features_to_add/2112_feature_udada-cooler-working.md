---
schema_version: 1
type: feature
slug: "udada-cooler-working"
status: done
difficulty: medium
created_at: "2026-11-05T21:12:36+09:00"
session_id: "20261105-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/cooler.html"
    op: create
  - path: "udada/design/machine.css"
    op: create
  - path: "udada/design/machine.js"
    op: create
related:
  - ref: "20261104/Chores/1900_chore_udada-value-redesign-research.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 식히기 동작판

## 추가 기능
정적 시안이던 e-cooler 를 실제로 끝까지 도는 `udada/design/cooler.html` 로 만들었다. 흐름: 온도(노브) → 비우기(한 줄 = 고리) → 분류(한 장씩 지금/날짜 박기/내 손 밖/버리기, 키 1–4·Enter) → 식히기(cyclic sighing ×5) → 하나만(영수증, 2분) → 다시 온도 → 결과·서랍.

## 동작 흐름
- 분류 제안은 AI가 아니라 단어 규칙이다(걱정어 → 손 밖, "할까 말까" → 버리기, 짧은 연락 → 지금, 나머지 → 날짜 박기 + 언제 추정). 날짜 박기는 칩 4개(오늘 저녁/내일 오전/이번 주말/다음 주) 중에서 고른다.
- 저장: 서랍(날짜·손 밖·안 끝낸 지금), 세션(전후 온도·개수), 누적 닫은 고리. 버린 건 저장하지 않는다.
- `?from=refresh` 로 들어오면 온도를 건너뛰고, 하나만 다음에 refresh.html 로 돌아간다(리프레시의 '꽉 찼어' 갈래).
- 공용 부품은 `machine.css`/`machine.js` 로 뽑았다(노브·숫자판·소리·저장).
- 테스트 중 버그 2개를 잡았다: ① 정리하기 버튼에 포커스가 남은 채로 Enter 를 누르면 그 버튼이 다시 눌려 분류가 처음부터 다시 시작됨 → 화면 전환 때 포커스 해제 + Enter 기본 동작 막음. ② 마지막 카드 직후 0.25초 사이의 입력이 없는 카드를 읽다가 오류(`reading 'sug'`) → 분류 끝 가드.

## 검증
- `PW=/tmp/shtest/node_modules/playwright-core node tests/refresh.test.js` 의 식히기 왕복 구간(예시 → Enter ×8 → 숨 → 하나만 → 복귀) 통과, 끝 줄 `errors: none`. 별도 스크린샷 스크립트(c0–c4) 끝 줄 `errors: none`.
- 단독 실행의 다시 온도 → 결과 화면은 자동 테스트가 없다. 소리·진동은 헤드리스에서 확인 못 함.