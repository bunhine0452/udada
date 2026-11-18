---
schema_version: 1
type: feature
slug: "udada-shortform-todo-app"
status: done
difficulty: high
created_at: "2026-11-03T01:07:34+09:00"
session_id: "20261103-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "4d326471-6cda-429a-8286-054f147203fe"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20261103/Chores/0029_chore_brain-cooler-design-plan.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "research"
  - "mcp-tool"
---
[x] 우다다: 숏폼형 할 일 앱 첫 버전

## 추가 기능
사용자 피드백("숏폼 중독인 나한테 도움 안 될 듯, 디자인 별로")으로 8분짜리 흐름 설계안을 접고 방향을 바꿨다. 숏폼(쇼츠·릴스) 모양을 빌려 보상 심리를 할 일 쪽으로 돌리는 아티팩트 앱 「우다다」를 만들었다. https://claude.ai/artifact/STUEXjwAjCwPMpU392uCqB

## 동작 흐름
- 쏟아내기(텍스트) + 쓸 수 있는 시간 칩 → `sample.json`(default, effort low)이 tasks/steps(2~10분 클립)·later·drop·pep·crisis 를 JSON으로 준다. AI를 못 쓰면 줄마다 나누는 로컬 대체 동작.
- 피드: 세로 전체 화면 카드, 위 진행 막대, 오른쪽 아이콘 줄(끝/막힘/생각남/나중에/소리), 아래 예상 시간 진행선. 위로 밀기 = 끝냈다(넘기기 아님). 나중에 = 콤보 0.
- 보상: XP(10+분×2, 콤보 배수 최대 1.5), 15% 크리티컬 ×2, 10% 쉬는 시간 +2분, 클립 3개마다 쉬는 시간 5분, 레벨. 쉬는 시간 끝나고 90초 안에 돌아오면 칼복귀 +30. 알람은 AudioContext 시계로 예약해서 백그라운드 탭에서도 울린다.
- 막힘 → quick 모델로 1~3분 조각 2~4개로 쪼갬. 생각남 → 인박스, 나중에 AI로 정리해서 뒤에 붙임. 진행 중 + 버튼 → 기존 클립 뒤에 붙이기.
- 저장: db `data/users/<id>/state`(본인만 읽음) + localStorage. 다시 열면 이어하기 배너.
- crisis 플래그면 109 / 1577-0199 시트를 먼저 보여 준다.
- 브랜드 로고·이름·색은 쓰지 않았다(생김새만 닮게).

## 검증
- `node --check` 로 스크립트 문법 → SYNTAX_OK. 아티팩트 발행 성공(capabilities sample, db, user).
- 실제 AI 호출·db 쓰기는 사용자가 열어서 써 봐야 확인된다(세션에서 검증 못 함). 소스: scratchpad/udada.html (프로젝트 폴더에는 없음).