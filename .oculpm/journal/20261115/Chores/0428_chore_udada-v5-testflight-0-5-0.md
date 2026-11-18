---
schema_version: 1
type: chore
slug: "udada-v5-testflight-0-5-0"
status: done
difficulty: medium
created_at: "2026-11-15T04:28:00+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/PrivacyInfo.xcprivacy"
    op: create
  - path: "udada/ios/UdadaWidgets/PrivacyInfo.xcprivacy"
    op: create
  - path: "udada/ios/Udada/Info.plist"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/0142_feature_udada-v5-day-sheet-app.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: v5 최종 테스트 통과와 TestFlight 0.5.0

## 무엇을 했나
사용자 "다 되면 테스트플라이트에 올려줘". 하위 세션이 모두 끝난 뒤 통합해 전체 테스트를 돌리고 TestFlight 에 올렸다.
- 마지막 통합에서 내가 고친 것: 실행마다 무조건 저장하던 것 → 바뀐 게 있을 때만, 시스템 갱신(Spotlight·알림·달력·AI 준비)은 첫 화면 0.7초 뒤로, 식히기 중 꺼져 남은 라이브 액티비티는 시작 때 정리(돌던 집중은 이어짐), `CFBundleName` 우다다(단축어 링크에 Udada 로 보이던 것), UI 테스트용 `-udNoAI`, 개인정보 매니페스트(앱·위젯: 추적 없음·수집 없음·UserDefaults CA92.1/1C8F.1), 매일 반복 할 일 점 빼기, 늦은 밤 지금 줄.
- 서명: 위젯 확장 프로필 자동 생성, 앱·위젯 모두 앱 그룹 권한 확인. 앱 6.1MB.
- 정리: 테스트·아카이브에 쓴 시뮬레이터 2대와 파생 데이터·아카이브·내보내기 폴더 삭제. 우다다 시뮬레이터 0, 전역 DerivedData 우다다 0, 디스크 여유 56GB(병렬 작업 중 18GB 까지 줄었던 것 회복).

## 검증
- `xcodebuild test -project Udada.xcodeproj -scheme Udada -destination "id=$SE" -destination "id=$PM" -parallel-testing-enabled NO` → `** TEST SUCCEEDED **`, `Testing passed on 'udada-final-se'`·`'udada-final-pm'` — SE 74 통과·0 실패·2 건너뜀, iPhone 17 Pro Max 74 통과·0 실패·2 건너뜀(건너뜀은 스크린샷 전용). 단위(파서·하루 로직·AI 규칙·알림 계획·인텐트·인식·통계) + UI(Flow 10·Flows 8·Today 13·Records 9).
- `xcodebuild archive … -allowProvisioningUpdates` → `** ARCHIVE SUCCEEDED **`, `xcodebuild -exportArchive -exportOptionsPlist Config/ExportOptions.plist` → `Upload succeeded.` / `Uploaded Udada` / `** EXPORT SUCCEEDED **` (0.5.0, App Store Connect 처리 중).
- 실기기에서 아직 안 본 것: Siri 음성, 마이크·카메라, 진동, 잠금 화면 위젯·라이브 액티비티 카드, 실제 손가락 끌어 옮기기, Apple 지능 기기의 AI 지연.