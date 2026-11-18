---
schema_version: 1
type: feature
slug: "udada-refresh-prototype"
status: done
difficulty: medium
created_at: "2026-11-05T21:12:55+09:00"
session_id: "20261105-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/refresh.html"
    op: create
  - path: "udada/design/tests/refresh.test.js"
    op: create
  - path: "udada/design/index.html"
    op: update
  - path: "udada/design/shots/refresh.png"
    op: create
  - path: "udada/design/cooler.html"
    op: update
related:
  - ref: "20261105/Chores/2112_chore_udada-refresh-research-design.md"
    kind: "followup"
  - ref: "20261105/Features_to_add/2112_feature_udada-cooler-working.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 뇌 리프레시 동작판

## 추가 기능
REFRESH.md 설계를 `udada/design/refresh.html` 로 구현했다(기계 언어, machine.css/js 공용). 흐름: 상태 4키(졸려/꽉 찼어/멍해/막혔어) → 맑기 노브 + 시간(2/10/20분) → 처방 영수증(단계·왜·저자 연도, [다른 거]) → 화면 꺼짐 타이머 → 돌아옴(책갈피 먼저, 맑기 다시) → 결과(전후, 나한테 잘 든 처방 순위).

## 동작 흐름
- 처방 13개, MENU[상태][시간] = [기본, 다른 거]. 16시 이후엔 커피 낮잠 대신 15분 낮잠 + 세수(`?hour=` 로 테스트).
- 책갈피: 기본은 "돌아오면 먼저 할 것", 막혔어는 "막힌 문제를 한 줄로". 돌아와서 보여 준 뒤 저장하지 않는다.
- 타이머는 Date 기준(백그라운드에서 느려져도 맞음). 화면 꺼짐 방지(Wake Lock)를 쓰고, 끝나면 차임 + 진동. 숨 단계에선 "코로 훅 / 한 번 더 훅 / 입으로 길게" 문구가 돈다.
- '꽉 찼어' 10·20분 = cooler.html?from=refresh 로 왕복. pending 키로 전 맑기·책갈피를 이어 붙인다.
- 개인 비교: 처방별 평균 변화. 2회 이상 쌓이면 홈과 처방 화면에 힌트를 띄우고, 결과 화면에선 아직 안 해 본 [다른 거]를 비교용으로 제안한다.
- `design/index.html` 맨 위에 카드를 추가했다(shots/refresh.png).

## 검증
- `cd udada/design && PW=/tmp/shtest/node_modules/playwright-core node tests/refresh.test.js` → 37개 체크(상태·처방 매핑·다른 거 토글·타이머 종료·책갈피 미저장·16시 규칙·중단 기록·식히기 왕복·순위·힌트·폰 폭) 끝 줄 `all checks passed` / `errors: none`. 회귀 `tests/shredder.test.js` 끝 줄 `errors: none`.
- 스크린샷 7장(r1–r7)으로 레이아웃을 직접 확인하고, 첫 화면 빈 공간과 키 라벨 줄바꿈을 고쳤다.
- 실제 폰에서 알람·진동·Wake Lock 은 확인하지 못했다. 효과(맑기 중앙값 +2)는 실사용 기록으로 판정해야 한다.