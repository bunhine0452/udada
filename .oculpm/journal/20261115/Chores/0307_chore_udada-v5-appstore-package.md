---
schema_version: 1
type: chore
slug: "udada-v5-appstore-package"
status: done
difficulty: high
created_at: "2026-11-15T03:07:24+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/appstore/README.md"
    op: create
  - path: "udada/appstore/privacy.md"
    op: create
  - path: "udada/appstore/metadata/ko/description.txt"
    op: create
  - path: "udada/appstore/screenshots/preview.png"
    op: create
  - path: "udada/appstore/tools/capture.sh"
    op: create
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
related: []
tags:
  - "우다다"
  - "research"
  - "mcp-tool"
---
[x] 우다다: 앱스토어 제출 패키지와 스크린샷

## 무엇을 했나
하위 세션(Opus 5.5)이 한국 앱스토어 제출 패키지를 `udada/appstore/` 에 만들었다(앱 코드는 안 건드림). 사용자 목표 "앱스토어 1위".
- 이름 `우다다: 할 일·일정 플래너`(15/30) — '우다다'만으로는 이미 사용 중이라 기존 ASC 레코드는 "우다다: 뇌 리프레시", ASC 에서 바꿔야 함. 이름 칸에 가장 큰 범주어 셋(할 일·일정·플래너), 경쟁 앱(투두메이트·Structured·TickTick)도 같은 방식.
- 부제 `생각 정리부터 하루 계획까지 한 장에`(20/30). 보이는 글에는 'AI' 를 안 씀(iOS 26 + Apple 지능 기기에서만 모델이 돌고 나머지는 규칙이라).
- 키워드 정확히 100바이트(한글 3바이트): 투두,할일,리스트,캘린더,달력,위젯,관리,걱정,집중,스케줄,AI,ADHD,루틴,휴식 — 이름·부제와 안 겹침, '일정 관리'·'투두 리스트' 조합 노림. ADHD 는 숨은 칸에만(선택).
- 범주 생산성 / 보조 라이프스타일(건강은 의료 주장 심사를 부름), 9+, 개인정보 '수집 안 함'(네트워크·SDK·추적 없음을 코드로 확인; 예외: 기기 안 받아쓰기 모델이 없을 때 Apple 서버 — 화면과 처방침에 적음).
- 설명(2,382/4,000), 홍보 문구, 0.5.0 새 기능, 심사 메모(영어: 예시 데이터 경로·위젯·Siri 문구·AI 가용성·권한), 영어판, 개인정보 처리방침(한·영) `privacy.md`. 연구 주장은 DAY.md·VALUE.md·앱 안 근거 페이지로 뒷받침되는 것만(Halder 2026 은 프리프린트 관찰로), 치료 아님과 위기 연락처 명시. AI 주장은 실제로 연결된 것만(정리·첫 동작·걱정).
- 스크린샷 8장 × 6.9"/6.5"/6.3": 하루 한 장 → 한 줄 넣기 → 비우기 → 식히기 → 하루 닫기 도장 → 위젯·Siri → 기록 → 근거·개인정보. 전부 현재 빌드의 실제 화면(써 본 사람 기록 파일 + UI 테스트로 조작, 위젯은 확장의 실제 뷰 코드), 가짜 시스템 UI 없음, 상태 막대는 앱 속 '지금'과 맞춰 14:20/21:40. 다시 만들기 `udada/appstore/tools/capture.sh`.
- 이 세션이 찾은 앱 문제 중 둘은 내가 바로 고침: 실행마다 무조건 저장하던 것 → 바뀐 게 있을 때만, 시스템 갱신(Spotlight·알림·달력·AI 준비)은 첫 화면 뒤 0.7초로 미룸, 식히기 중 앱이 꺼져 남은 라이브 액티비티는 시작 때 정리. 식히기 고르기 화면이 idle 이 안 되는 반복 애니메이션은 흐름 세션에 전달.

## 검증
- 모든 칸 글자·바이트 수를 세는 스크립트로 Apple 한도 확인(키워드 100/100 바이트).
- `udada/appstore/screenshots/preview.png` 를 직접 보고 8장이 실제 화면·같은 디자인 언어임을 확인. 하위 세션은 자기 시뮬레이터·빌드 파일을 지움(남은 폴더 8.7MB).
- 사용자가 할 일: privacy.md 호스팅 URL·지원 URL·저작권/연락처, ASC 에서 이름 변경.