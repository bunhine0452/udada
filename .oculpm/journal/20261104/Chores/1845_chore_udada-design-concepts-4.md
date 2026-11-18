---
schema_version: 1
type: chore
slug: "udada-design-concepts-4"
status: done
difficulty: medium
created_at: "2026-11-04T18:45:25+09:00"
session_id: "01a1a5e3-d80d-7438-9877-705bad5aaa30"
agent:
  id: "pi"
  version: "claude-opus-5-5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/RESEARCH.md"
    op: create
  - path: "udada/design/index.html"
    op: create
  - path: "udada/design/a-rec.html"
    op: create
  - path: "udada/design/b-ticket.html"
    op: create
  - path: "udada/design/c-omr.html"
    op: create
  - path: "udada/design/d-device.html"
    op: create
  - path: "udada/design/shot.sh"
    op: create
related:
  - ref: "20261103/Features_to_add/0135_feature_udada-riso-image-feed.md"
    kind: "followup"
  - ref: "20261103/Refactors/0114_refactor_udada-poster-stamp-redesign.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "research"
---
[x] 우다다: 디자인 공부 노트와 시안 4종

## 무엇을 했나
사용자 요청: 앱 공부, 촌스럽지 않고 AI slop 같지 않은 디자인 공부, 시안 몇 개. 기존 일지 4건으로 앱과 거절 이력(v1 slop, v2 정적, v3 그림이 주인공)을 정리하고, 925studios·Designpixil(2026 AI slop 조사)·Anthropic frontend aesthetics cookbook·BuiltUX(촉감 디자인)·Tiimo 비교글을 읽어 `udada/design/RESEARCH.md` 에 남겼다.

## 결정
- 장식이 아니라 은유 하나가 화면 구조를 정하게 한다. 강조색 하나, 그라데이션·글래스·색종이·이모지·Inter 금지.
- 시안(각각 쏟아내기 / 할 일 한 장 / 끝냈을 때 3화면, 같은 예시 데이터): A 녹화중(캠코더 뷰파인더, 필름 롤), B 딩동 017번(번호표·LED 전광판·꽂이), C 답안지(시험지 명조·OMR 마킹·빨간 펜 채점), D 기계(노브·큰 파란 키·기계식 숫자판).
- 비교 페이지 `udada/design/index.html`, 스크린샷 `udada/design/shots/*.png`, 재촬영 `./shot.sh <이름>`.
- 웹검색 도구(pandi-anthropic-web-search)는 이번 세션에 아직 안 올라와서 DuckDuckGo HTML + 직접 fetch 로 조사(일부 검색은 봇 차단).

## 검증
- 헤드리스 Chrome `./shot.sh` 로 5페이지 촬영 → 각 PNG 생성(a 149KB, b 208KB, c 341KB, d 164KB, index 340KB) 후 눈으로 확인, 겹침·빈 공간 문제를 고쳐 다시 찍음.
- 정적 시안이라 동작 로직은 없음. 사용자 선택 전.
