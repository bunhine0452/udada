---
schema_version: 1
type: chore
slug: "brain-cooler-design-plan"
status: done
difficulty: medium
created_at: "2026-11-03T00:29:51+09:00"
session_id: "20261103-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "4d326471-6cda-429a-8286-054f147203fe"
language: "ko"
verified_by_user: false
files_touched: []
related: []
tags:
  - "설계"
  - "design"
  - "research"
  - "mcp-tool"
---
[x] 설계: 브레인 쿨러 설계안 아티팩트

## 무엇을 했나
머리가 과부하일 때 쓰는 웹앱 「브레인 쿨러」의 설계안을 논문 조사 후 아티팩트로 발행. https://claude.ai/artifact/JoRBWp1bNVMHGZrnm33QJv

## 결정
- 흐름(약 8분): 온도 재기(0–10) → 생리적 한숨 90초(Balban 2023) → 쏟아내기 3분(Scullin 2018, Klein&Boals 2001, 감정 한 단어 Lieberman 2007) → 카드 한 장씩 나누기: 지금/날짜/내 손 밖(걱정 시간, McGowan 2013)/버리기(Briñol 2013) → 언제·어디서 계획(Masicampo&Baumeister 2011, Gollwitzer&Sheeran 2006) → 다음 한 가지(2분 첫 동작, 홈 고정) → 40초 자연 장면(Lee 2015) → 온도 재기.
- 숏폼 근거: Nguyen 2025 메타(억제 r=−.41, 상관), Chiossi 2023(의도 기억↓), Tam&Inzlicht 2024(넘기기→지루함↑). 원칙: 한 화면 한 가지, 피드·알림·연속기록 없음, 의도는 앱이 기억.
- 90초 입구: 숏폼 충동 시 바로가기. 막지 않음. 효과는 미검증이라 앱 내 지표로 확인.
- 스택: PWA, Vite+TS, 프레임워크 없음, IndexedDB만(서버·계정 없음).
- 판정: 온도 중앙값 −2 이상, 시작률 60%+, 완주 8분 이하, Playwright 완주 테스트.

## 검증
아티팩트 발행 성공(Version 1). 코드는 아직 없음 — 구현은 사용자 확인 후.