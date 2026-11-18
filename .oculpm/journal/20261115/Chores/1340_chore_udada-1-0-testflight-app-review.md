---
schema_version: 1
type: chore
slug: "udada-1-0-testflight-app-review"
status: done
difficulty: medium
created_at: "2026-11-15T13:40:20+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/appstore/privacy.md"
    op: update
  - path: "udada/appstore/metadata/review_information/notes.txt"
    op: update
  - path: "udada/appstore/metadata/ko/description.txt"
    op: update
  - path: "udada/appstore/metadata/ko/promotional_text.txt"
    op: update
  - path: "udada/appstore/metadata/ko/release_notes.txt"
    op: update
  - path: "udada/appstore/metadata/copyright.txt"
    op: update
  - path: "udada/appstore/README.md"
    op: update
  - path: "udada/ios/UdadaUITests/RecordsUITests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/TodayUITests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowsUITests.swift"
    op: update
related:
  - ref: "20261115/Features_to_add/1312_feature_udada-mac-app-icloud-sync.md"
    kind: "followup"
  - ref: "20261115/Chores/0307_chore_udada-v5-appstore-package.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "appstore"
  - "mcp-tool"
---
[x] 우다다: 1.0 TestFlight 업로드와 앱 심사 제출

## 동기
사용자(11-15): "testflight 업로드하고, 앱 심사까지 진행해." 묻고 받은 답: 지원·처리방침 페이지 공개 게시 허락, 버전 1.0, CloudKit 운영 스키마 배포 허락, 심사 연락 전화번호.

## 변경 요약
- 버전 `MARKETING_VERSION` 0.5.0 → 1.0. `scripts/archive.sh` 로 아카이브·업로드.
- 공개 페이지: `bunhine0452.github.io/udada/`(지원) · `/udada/privacy.html`(처리방침) — 기존 cat 페이지 형식, 커밋 d8a59dd. `appstore/privacy.md` 를 iCloud 맞추기에 맞게 고침("인터넷으로 보내는 일 없음"은 이제 틀린 말이라 뺌).
- CloudKit 콘솔: `iCloud.io.github.bunhine0452.udada` 개발 스키마(Leaf 타입·색인 5·기본 역할)를 운영에 배포 — "Changes Deployed". 되돌릴 수 없음.
- App Store Connect(앱 6831147747): 이름 「우다다: 할 일·일정 플래너」·부제·생산성/라이프스타일, 프로모션·설명·키워드(100바이트)·지원 URL·저작권 2026 Hyunbin Kim, 심사 연락처·메모(iCloud 절 추가, 로그인 불필요), 수동 출시, 연령 등급 9+(건강·웰빙 주제만 예), 콘텐츠 권한 아니요, 개인정보 "수집하지 않음" 게시 + 처리방침 URL, 가격 무료, 판매 지역 대한민국만, 스크린샷 6.3" 8장(모든 iPhone 크기에 공용), 빌드 1.0 (1) 선택 → 심사 제출.
- UI 테스트 실행 인자에 `-udNoSync`: 서명 없는 테스트 빌드는 iCloud 권한이 없어 `CKContainer(identifier:)` 에서 죽는다(.ips: `CloudSync.start()` ← `UdadaApp.init`). 서명된 빌드에는 권한이 있다(아카이브 entitlements 확인).

## 검증
- `udada/ios/scripts/archive.sh` 끝 줄: `Upload succeeded.` / `** EXPORT SUCCEEDED **`. TestFlight 에 버전 1.0 빌드 (1) 표시.
- ASC 화면: "1개의 항목 제출됨", 상태 "1.0 심사 대기 중".
- 업로드 전 iOS 전체 테스트: `** TEST FAILED **` — 실패 2건(testRecordsFillFromFlows 앱 충돌, testQuickAddReadsKorean "연속 넣기"). 위 인자를 넣고 둘만 다시: `Executed 2 tests, with 0 failures` / `** TEST SUCCEEDED **`. **전체 묶음을 고친 뒤 다시 돌리지는 않았다.** 올라간 앱 코드는 실패했던 실행과 같다(바뀐 것은 테스트 인자뿐).
- `curl` 로 두 공개 페이지 200.
- 미확인·남은 것: 스크린샷은 Apple Intelligence 표시·소개 5쪽 이전에 찍은 것(다시 찍지 않음). 실기기에서 운영 iCloud 맞추기 미확인. Mac 앱은 ASC 에 플랫폼을 추가하지 않았고 올리지 않았다.