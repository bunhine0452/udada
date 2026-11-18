---
schema_version: 1
type: refactor
slug: "udada-poster-stamp-redesign"
status: done
difficulty: medium
created_at: "2026-11-03T01:14:50+09:00"
session_id: "20261103-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "4d326471-6cda-429a-8286-054f147203fe"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20261103/Features_to_add/0107_feature_udada-shortform-todo-app.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 포스터+도장 디자인으로 재작성

## 동기
사용자: "ai slop 같아 디자인 이게 최선인가? 요즘 디자인 트렌드 알아봐봐". v1은 어두운 배경, 분홍·주황 그라데이션, 빛 번짐, 색종이, 알약 버튼, TikTok식 + 버튼 등 AI 기본값 그대로였다. 2026 트렌드(글자가 곧 구조, 극단적 크기 대비, 평평한 색, 장식 걷어내기, 손으로 만든 흔적)를 조사해서 반영했다.

## 변경 요약
- 클립 = 평평한 단색 포스터 한 장(코발트/노랑/초록/주황/검정/분홍/회색 7종). 제목은 Do Hyeon 13vw로 크게. 그라데이션·빛 번짐·질감 오버레이 제거.
- 보상: 색종이 대신 「참 잘했어요」 도장(Hahmlet, SVG 잉크 필터, 쾅 하고 찍히는 애니메이션, 화면 흔들림, 쿵 소리). 변형: 콤보 3 이상 「아주 잘했어요」, 크리티컬 「최고예요」. 완료 화면은 칭찬 도장판 격자.
- 첫 화면: 종이 흰 바탕, 거대한 「우다다.」 워드마크, 줄 노트 입력칸, 각진 시간 선택 버튼.
- 시간 표시 = 분 단위 자 눈금. 쉬는 시간 = 초록 포스터에 큰 숫자 시계.
- 하단 TikTok식 내비게이션 제거, 위쪽에 「전체」「+ 쏟아내기」 텍스트 버튼.
- 저장 키 v2(v1 상태와 섞이지 않게). 동작 로직은 v1과 같음.

## 검증
- `node --check` → SYNTAX_OK.
- 헤드리스 Chrome 스크린샷 3장(첫 화면/피드/도장) 확인. 도장이 너무 거칠고 제목을 가려서 잉크 필터를 약하게 하고 위치를 내림, 안내 메시지 위치도 고친 뒤 Version 2 발행(고친 뒤 다시 찍어 보지는 않음).
- AI 호출·db 저장은 아직 실사용으로 확인하지 못함.