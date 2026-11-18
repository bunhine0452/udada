---
schema_version: 1
type: feature
slug: "udada-shredder"
status: done
difficulty: medium
created_at: "2026-11-04T19:26:10+09:00"
session_id: "01a1a5e3-d80d-7438-9877-705bad5aaa30"
agent:
  id: "pi"
  version: "claude-opus-5-5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/shredder.html"
    op: create
  - path: "udada/design/tests/shredder.test.js"
    op: create
  - path: "udada/design/index.html"
    op: update
  - path: "udada/design/VALUE.md"
    op: update
  - path: "udada/design/shots/shredder.png"
    op: create
related:
  - ref: "20261104/Chores/1900_chore_udada-value-redesign-research.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "research"
---
[x] 우다다: 생각 파쇄기 동작 프로토타입

## 추가 기능
사용자가 외부인용 재미 기능 후보 중 파쇄기를 골랐다. 기계 디자인(시안 D) 한 화면짜리 동작 프로토타입 `udada/design/shredder.html`. 근거는 Briñol 2012(생각을 물건처럼 버리면 덜 씀)와 Kanaya & Kawai 2024(파쇄기로 갈면 분노가 사라짐, 실험 2) — 둘 다 OpenAlex 초록으로 확인. 몸으로 할 때 효과가 컸다는 점 때문에 물리감을 최우선으로 했다.

## 동작 흐름
- 카드에 생각을 적는다(비우면 예시 문구). 카드를 아래로 끌어 슬롯에 밀거나 파란 키를 꾹 누른다. 떼면 멈춤, 45% 넘게 물리면 모터가 알아서 끝까지.
- 슬롯 아래로 12조각 세로 띠가 벌어지며 나오고(같은 카드 DOM 복제 + clip-path), 통으로 떨어져 종이 조각이 쌓인다. 통이 10번 차면 갈기 잠김 → 비우기.
- WebAudio로 모터(톱니파 58Hz)·갈림(대역 잡음)·칼날 딱딱 소리를 합성(파일 없음). 진동은 navigator.vibrate(안드로이드만). 갈리는 동안 기계가 미세하게 떨림, prefers-reduced-motion 존중.
- 저장: 버린 개수와 통 높이만 localStorage. 생각 내용은 저장하지 않음. 데스크톱은 왼쪽에 근거·한계 설명, `?demo=0.45` 는 스크린샷용 정지 상태.

## 검증
- `PW=/tmp/shtest/node_modules/playwright-core node tests/shredder.test.js` (실제 Chrome으로 꾹 누르기·드래그·통 가득·비우기) → 끝 줄 `errors: none`, localStorage `{"udada.shred.bin":"2","udada.shred.count":"2"}`. 처음 돌렸을 때 나온 버그 2개(멈춤 표시, 통 가득 문구)를 고친 뒤 다시 통과.
- 소리·진동은 헤드리스에서 확인 못 함. 실제 폰에서 손맛 확인 필요. 화면 속 파쇄의 심리 효과는 미검증.
