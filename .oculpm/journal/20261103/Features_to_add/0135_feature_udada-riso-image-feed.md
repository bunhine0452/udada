---
schema_version: 1
type: feature
slug: "udada-riso-image-feed"
status: done
difficulty: high
created_at: "2026-11-03T01:35:13+09:00"
session_id: "20261103-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "4d326471-6cda-429a-8286-054f147203fe"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/udada.src.html"
    op: create
  - path: "udada/build_udada.py"
    op: create
  - path: "udada/udada.html"
    op: create
  - path: "udada/img/s0.jpg"
    op: create
related:
  - ref: "20261103/Refactors/0114_refactor_udada-poster-stamp-redesign.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 리소 그림 숏폼 피드로 재작성

## 추가 기능
사용자 "이게 최선인가.. codex 이미지 생성 써도 돼". 직접 따져 본 v2(포스터+도장)의 문제: 숏폼처럼 생기지 않음, 정적인 빈 단색 화면, 도장과 숏폼 문법이 따로 놂.
- Codex CLI 0.166 `image_generation`(stable)으로 리소그래프 풍 9:16 그림 6장 생성(잉크 2색, 하프톤, 판 어긋남, 아래쪽 1/3 구도). 소재: desk 스탠드·노트 / phone 휴대폰·물컵 / outside 운동화·문 / laptop 노트북·커피 / parcel 상자·테이프 / timer 모래시계·헤드폰. `codex exec -s workspace-write` 를 5개 병렬로 돌렸고 각 1분 안쪽.
- AI 프롬프트에 `scene` 필드 추가 → 할 일 종류에 맞는 그림. 정규식 `guessScene` 으로 대체 동작.
- 숏폼 구조: 전체 화면 그림(26초 천천히 확대), 단어씩 튀어나오는 테두리 자막(마지막 단어 강조색), 오른쪽 아이콘 줄(끝/막힘/생각남/나중에), 왼쪽 아래 정보 칸 + 흐르는 「다음」 글자, 레벨 원판, 진행 막대. 두 번 톡 = 끝(누른 자리에 체크 터짐), 위로 밀기 = 현재 카드와 다음 카드가 같이 올라감.
- 완료 화면 = 프로필 격자(끝낸 클립 썸네일에 +XP).
- 종이 바탕(#EBE8E2)에 잉크 테두리 스티커 느낌 UI. 저장 키 v4.
- 빌드: `udada/build_udada.py` 가 `udada.src.html` 의 `/*__BGCSS__*/` 에 img/s0~5.jpg(1000px, q60, 합계 약 780KB)를 base64로 넣음 → udada.html(1.1MB).

## 동작 흐름
쏟아내기 → AI JSON(tasks + scene + steps …) → 피드 → 두 번 톡 / 위로 밀기 / 「끝」 → 보상 → 다음 카드. 나머지(쉬는 시간, 칼복귀, 막힘, 생각남, 위기 시트)는 v1과 같음.

## 검증
- `node --check` → SYNTAX_OK (빌드 결과물 기준).
- 헤드리스 Chrome 스크린샷(첫 화면/피드/체크 터짐) 확인. 아이콘 줄이 길어 소리 버튼을 위쪽 줄로 옮기고 라벨 스타일을 고친 뒤 Version 3 발행(고친 뒤 다시 찍어 보지는 않음).
- 실제 AI 호출·db 저장은 아직 실사용 확인 전.