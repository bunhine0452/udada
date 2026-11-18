---
schema_version: 1
type: chore
slug: "udada-1-2-shots-submit"
status: done
difficulty: medium
created_at: "2026-11-18T18:49:43+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/appstore/tools/compose.py"
    op: update
  - path: "udada/appstore/tools/compose_mac.py"
    op: create
  - path: "udada/appstore/tools/shots.json"
    op: update
  - path: "udada/appstore/tools/capture.sh"
    op: update
  - path: "udada/appstore/tools/runner/Shots.swift"
    op: update
  - path: "udada/appstore/metadata/ko/release_notes.txt"
    op: update
  - path: "udada/appstore/screenshots/v1.2/preview.png"
    op: create
  - path: "udada/appstore/screenshots/mac/1-day.png"
    op: update
  - path: "udada/appstore/screenshots/mac/2-dump.png"
    op: create
  - path: "udada/appstore/screenshots/mac/3-find.png"
    op: update
  - path: "udada/appstore/screenshots/mac/4-siri.png"
    op: create
  - path: "udada/appstore/README.md"
    op: update
related:
  - ref: "20261118/Features_to_add/1814_feature_udada-1-3-guide-ai-door-siri.md"
    kind: "followup"
  - ref: "20261116/Chores/0403_chore_udada-release-1-0-prepare-1-1-mac.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "mac"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 1.1 출시, 1.2 새 스크린샷으로 제출

## 변경 요약
사용자(11-18): "스크린샷도 더 전문가스럽게 찍고 업데이트 출시해 mac 도 출시해". App Store Connect 는 Chrome 으로 했다.

- **빌드**: 오늘 작업(움직이는 사용법 · AI 입구 · Siri 시키기)이 든 1.2 를 iPhone(빌드 3) · Mac 둘 다 올렸다.
- **iOS 1.1 출시**: 승인되어 '개발자 출시 대기 중'이던 1.1 을 '이 버전 출시' → `1.1 배포 준비됨`. (1.2 버전을 만들려면 먼저 나가야 했다)
- **iOS 1.2 제출**: 버전 생성 → 업데이트 문구(`release_notes.txt`, 내가 씀) → 빌드 3 → 출시 방식 '자동으로 버전 출시' → 스크린샷 9장으로 교체 → 심사 제출.
- **iPhone 스크린샷 새로** (`screenshots/v1.2/`): 큰 명조 머리말 · 평평한 먹색 기기 테 · 바탕 세 색(종이·코발트·먹) · 화면은 크게 아래로 넘치게. 순서: 오늘 · 한 줄 나눠 넣기(실제 Apple Intelligence 표시가 찍힘) · Siri(앱 안 사용법 장면이라고 꼬리표에 적음) · AI 판 · 식히기 · 하루 닫기 · 위젯 · 기록 · 근거. `capture.sh` 에 `RAW=<폴더>`(날것 남기기)와 사용법 장면 멈춰 찍기를 넣었다.
- **Mac 스크린샷 새로** (`compose_mac.py`, 2880×1800 네 장): 하루 · 쏟아내기 · 뜻으로 찾기 · Siri 장면. 실제 Mac 앱을 따로 둔 저장소(-udDataDir)로 띄워 찍었다.

## 검증
- 업로드: iPhone `Uploaded Udada` / `** EXPORT SUCCEEDED **`, Mac `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`.
- App Store Connect 화면에서 읽은 상태: iOS `1.2 심사 대기 중 · 1.1 배포 준비됨`, 제출 뒤 '1개의 항목 제출됨'. 스크린샷 칸 `10개 중 9개`, 순서 01→09.
- macOS 는 `1.1 심사 중` 그대로, 출시 방식은 이미 '자동으로 버전 출시'(AFTER_APPROVAL)라 승인되면 바로 나간다.
- **안 한 것**: Mac 1.2 제출과 Mac 새 스크린샷 올리기 — 1.1 이 심사 중이라 새 버전을 만들 수 없다(심사를 빼면 줄을 다시 서야 해서 그대로 뒀다). 1.1 이 나간 뒤에 한다.
- 비우기 카드 스크린샷은 뺐다: `testH_DumpAll` 이 '예시로 채워 보기'를 눌러도 글이 안 채워져 빈 화면이 찍혔다(촬영 테스트 문제인지 앱 문제인지 안 가렸다).
- 옛 스크린샷(`screenshots/ko/…` 8장, `mac/4-stuck.png`)은 지우지 않았다 — 삭제 명령이 안전 검사에 막혔다.