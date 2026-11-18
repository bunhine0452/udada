---
schema_version: 1
type: chore
slug: "udada-value-redesign-research"
status: done
difficulty: high
created_at: "2026-11-04T19:00:29+09:00"
session_id: "01a1a5e3-d80d-7438-9877-705bad5aaa30"
agent:
  id: "pi"
  version: "claude-opus-5-5"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/VALUE.md"
    op: create
  - path: "udada/design/e-cooler.html"
    op: create
  - path: "udada/design/index.html"
    op: update
related:
  - ref: "20261104/Chores/1845_chore_udada-design-concepts-4.md"
    kind: "followup"
  - ref: "20261103/Chores/0029_chore_brain-cooler-design-plan.md"
    kind: "related"
tags:
  - "우다다"
  - "research"
  - "design"
---
[x] 우다다: 논문 근거로 가치 재설계, 기계 시안

## 무엇을 했나
사용자: "이게 뇌를 식힐 수 있을까? 논문 찾아 공부하고 가치를 다시 설계. 디자인은 기계가 제일 맘에 듦." OpenAlex API로 논문 24편 초록을 읽고 `udada/design/VALUE.md` 에 판정·근거·재설계·측정 기준·한계·참고문헌을 남겼다. 시안 D 언어로 새 흐름 6화면 `udada/design/e-cooler.html` 을 그렸다.

## 결정
- 판정: 지금 설계(무작위 크리티컬·콤보·XP·끝없는 클립 피드)는 식히기와 반대. Deci 1999 완료 보상 d=−.36 vs 긍정 피드백 +.33, Chiossi 2023 숏폼 전환이 전향 기억 저하, Tam&Inzlicht 2024 넘기기→지루함↑, Kang&Kurtzberg 2019 폰 휴식 회복 최하.
- 새 가치: "머릿속 열린 고리를 3분 안에 전부 닫는 기계, 그다음 딱 하나". 근거 Masicampo&Baumeister 2011(구체 계획이 침투 사고 소멸), Scullin 2018, McGowan&Behar 2013(걱정 시간), Balban 2023(cyclic sighing), Eckert 2016(감정 조절→미루기↓).
- 흐름: 온도 → 비우기 → 분류(카드 한 장씩 지금/날짜 박기/내 손 밖/버리기) → 식히기 1분(선택) → 하나만(영수증, 화면 꺼짐) → 다시 온도. 숫자판 = 닫은 고리. 0029의 8분 흐름이 거절된 이유(길고 참아야 함)를 피하려고 기본 3분 + 한 장씩 딸깍하는 손맛을 유지.
- 정직하게 뺀 것: Ward 2017 "폰이 있기만 해도"는 Hartanto 2024 메타에서 d=−.02라 문구로 쓰지 않음. 자이가르닉 기억 효과는 Ghibellini 2025 메타에서 재현 안 됨.
- 판정 기준: 온도 중앙값 −2 이상, 기본 흐름 3분 이하, 분류 완료율 80%+.

## 검증
- 헤드리스 Chrome `H=2080 ./shot.sh e-cooler` → shots/e-cooler.png 352900 bytes, 빈 공간 2곳 고친 뒤 다시 찍어 확인.
- 정적 시안이라 동작 없음. 효과는 미검증(앱 내 온도 측정으로 확인 예정). Lee 2015 등 4편은 초록을 못 구해 원문 확인 필요.
