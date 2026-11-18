---
schema_version: 1
type: chore
slug: "udada-refresh-research-design"
status: done
difficulty: high
created_at: "2026-11-05T21:12:36+09:00"
session_id: "20261105-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/REFRESH.md"
    op: create
related:
  - ref: "20261104/Chores/1900_chore_udada-value-redesign-research.md"
    kind: "followup"
tags:
  - "우다다"
  - "research"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 뇌 리프레시 논문 공부와 설계

## 무엇을 했나
사용자 요청: "뇌가 안 돌아가. 이 앱이 뇌를 리프레시해 주면 좋겠어 → 뇌과학·심리 논문 찾아 읽고 설계 제대로." OpenAlex(DOI 일괄) + Europe PMC(초록이 없는 것 보충)로 논문 40편의 초록을 읽고 `udada/design/REFRESH.md` 에 정리했다. 구성: 뇌에서 무슨 일이 / 근거 강도별 처방 / 회복 경험 4가지 / 책갈피 / 설계 / 측정 / 한계 / 참고문헌.

## 결정
- "안 돌아감"을 4상태로 나눈다: 졸림(잠 빚) · 과부하(열린 고리) · 피로(오래 집중) · 막힘. 처방이 서로 다르고, 모두 화면 밖에서 한다.
- 핵심 근거: Wiehler 2022(하루 종일 어려운 일 → lPFC 글루타메이트↑, 저비용 선택 편향), Boksem & Tops 2008·Kurzban 2013(피로 = 비용 > 보상), Hopstaken 2015(보상 시 회복), Brooks & Lack 2006(10분 낮잠 최적, 30분은 수면 관성), Hayashi 2003(커피 낮잠, N=10), Baird 2012·Sio & Ormerod 2009(막힘엔 단순 딴짓), Leroy & Glomb 2018(복귀 계획 → 주의 잔여↓), Bennett 2018(분리 ↔ 피로, 통제 ↔ 활력), Kang & Kurtzberg 2019(폰 휴식 최하).
- 문구: 자아 고갈은 d=0.04로 재현 실패(Hagger 2016), 한정 믿음이 고갈을 만든다(Job 2010) → "배터리·방전" 금지.
- 커피 낮잠은 16시 이후 금지(Drake 2013: 잠들기 6시간 전 카페인도 밤잠 감소).
- 처방표 4상태 × 3시간(2/10/20분), 각 칸에 기본과 [다른 거](통제감). '꽉 찼어' 10·20분 = 식히기(cooler).
- 측정: 맑기 0–10 전후, 1차 중앙값 +2, 같은 사람 안에서 처방끼리 비교. PVT-B(Basner 2011)는 나중에.
- 한계: 효과 대부분 g .1~.35, 커피 낮잠·요가 니드라·NSDR은 근거가 약함, 자기 보고는 기대 효과에 약함.

## 검증
- 숫자는 모두 초록 원문에서 확인했다(Brooks & Lack 155분, Dutheil g=.18/.29, Hagger d=0.04 [-0.07, 0.15], Randolph 10분 vs 50mg N=18, Sianoja 15분 N=97, Drake 6시간 400mg).
- Leroy 2009는 초록을 못 구해서 알려진 결론만 인용했다. Kjaer 2002의 표본 크기는 원문 확인이 필요하다.