---
schema_version: 1
type: feature
slug: "udada-mac-app-icloud-sync"
status: done
difficulty: high
created_at: "2026-11-15T13:12:53+09:00"
session_id: "20261115-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/Sync.swift"
    op: create
  - path: "udada/ios/Udada/Sync/CloudSync.swift"
    op: create
  - path: "udada/ios/Udada/App/Continuity.swift"
    op: create
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: create
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: create
  - path: "udada/ios/UdadaMac/MenuPanel.swift"
    op: create
  - path: "udada/ios/UdadaMac/QuickAdd.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacKit.swift"
    op: create
  - path: "udada/ios/UdadaMac/MacDump.swift"
    op: create
  - path: "udada/ios/UdadaMac/UdadaMac.entitlements"
    op: create
  - path: "udada/ios/UdadaMacTests/SyncTests.swift"
    op: create
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/ios/Shared/Theme.swift"
    op: update
  - path: "udada/ios/Shared/DataFile.swift"
    op: update
  - path: "udada/ios/Shared/Model.swift"
    op: update
  - path: "udada/ios/Udada/App/Store.swift"
    op: update
  - path: "udada/ios/Udada/Root/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/Rest/FocusView.swift"
    op: update
  - path: "udada/ios/Udada/Settings/SettingsSystem.swift"
    op: update
  - path: "udada/ios/Udada/Udada.entitlements"
    op: update
  - path: "udada/ios/Udada/Info.plist"
    op: update
  - path: "udada/ios/Udada/Services/CalendarService.swift"
    op: update
  - path: "udada/ios/Udada/Intents/Snippets.swift"
    op: create
  - path: "udada/appstore/privacy.md"
    op: update
related:
  - ref: "20261115/Features_to_add/0233_feature_udada-v5-on-device-ai-brain.md"
    kind: "followup"
  - ref: "20261115/Chores/0428_chore_udada-v5-testflight-0-5-0.md"
    kind: "followup"
tags:
  - "우다다"
  - "mac"
  - "sync"
  - "design"
  - "mcp-tool"
---
[x] 우다다: Mac 앱과 iCloud 로 iPhone 맞추기

## 추가 기능
사용자 요청(11-15): "Mac 과 iPhone 이 연동되어 감탄할 사용성", 이어서 "Mac 디자인을 더 세련되게(내 디자인 유지)", "상단바와 앱이 물아일체", "트레이 아이콘도 세련되게".

- **맞추기 규칙** `Shared/Sync.swift`(Foundation 만): AppData 를 '열쇠 → JSON' 낱장으로 편다(item.<uuid> · rest/dump/focus.<ms> · close.<날> · settings · nowfocus). 낱장마다 마지막에 고친 쪽이 이김. 지우기는 앱 안에서 사용자가 지웠을 때만 퍼짐(파일이 깨져 빈 데이터로 떠도 iCloud 를 안 비우고 되살림). 처음 맞출 때 설정·집중은 iCloud 쪽이 이김(새 기기 기본값이 안 덮음). 다른 버전이 쓴 모르는 필드는 '바뀜'으로 안 봄. 같은 반복의 같은 날을 두 기기가 따로 떼면 하나로 접음. 기기마다 다른 것(화면 밝기·진동·기기 달력·AI 스위치·syncOn·소개 봤는지)은 안 보냄.
- **엔진** `Udada/Sync/CloudSync.swift`: CKSyncEngine, 개인 DB 의 Udada 존, 레코드 타입 Leaf(body·stamp). 컨테이너 `iCloud.io.github.bunhine0452.udada`(자동 서명이 개발자 계정에 새로 만듦 — 되돌릴 수 없음). `-udReset/-udSeed/-udNoSync`·XCTest 에서는 절대 안 켜짐. `-udSyncTrace` 로 파일 추적, `-udDataDir` 로 저장소 분리.
- **Mac 앱** `UdadaMac/`(새 타깃, macOS 26+, 같은 번들 ID): 메뉴 막대(「지금 우」 템플릿 표식 + 다음 약속까지/남은 개수/집중 시계) · ⌃⌥Space 전역 한 줄 넣기 패널(치는 대로 읽는 칩) · 하루 한 장 창(세 띠 나란히, 끌어서 띠 옮기기, 오른쪽에 나중에 함·걱정 상자) · 집중(같은 ActiveFocus 를 맞춰 iPhone 에서 이어짐) · 쏟아내기(Brain 그대로 + 사진 끌어다 놓기 OCR + 연속성 카메라 '아이폰으로 찍기') · Handoff(보던 날). 제목 막대는 숨기고 종이가 창 꼭대기까지, 오른쪽 칸은 톤만 다르게. Store·DayLogic·Parser·Brain·Intents 는 iPhone 과 같은 파일.
- **iOS**: iCloud·푸시 권한과 remote-notification 배경 모드, 설정에 'iPhone · Mac' 칸, 다른 기기에서 시작/끝낸 집중 따라가기, Handoff.

## 동작 흐름
Store.persist → `afterUserChange` → CloudSync.localChanged(지우기 허용) → 엔진이 보냄. 받으면 먼저 이 기기 변경을 챙긴 뒤 합쳐 `Store.adopt`(다시 안 보냄). 앞으로 올 때 `refresh()`.

## 막힌 곳과 고친 것
- 엔진이 받는 중에 `sendChanges()` 를 직접 불러 CloudKit 단언으로 앱이 죽음(.ips: `closure in CloudSync.enqueue`) → will/did 이벤트로 `busy` 를 세고 바쁠 땐 미룸.
- 새 컨테이너 직후 몇 분은 "Not Authenticated: Could not determine iCloud account status"(계정은 available) → 기다리니 signIn 이벤트가 옴.
- 메뉴 막대 앱은 시작 때 Window 가 안 뜸 → 메뉴 글자의 task 에서 보이는 창이 없으면 openWindow.
- `log show` 는 이 셸에서 아무것도 안 나옴 → 파일 추적으로.

## 검증
- `xcodebuild test -scheme UdadaMac`(100회 반복): `Executed 1700 tests, with 0 failures` (맞추기 13 + 두뇌 4).
- 실제 iCloud(개발 환경), 한 Mac 에서 저장소 둘(devA·devB): A 에서 적기 → 새 B 가 그대로 받음, A 에서 끝내기 → B 반영, A 집중 시작 → B 에 같은 집중, B 에서 끝냄 → A 집중 없음+기록 1, A 에서 지우기 → B 에서도 없음. 충돌 0.
- iOS: 단위 35/35, 소개 UI 2/2(iPhone 18 Pro 시뮬). 시뮬 앱·파생 데이터 지움.
- 미확인: 실제 iPhone↔Mac 푸시 속도(한 Mac 의 두 인스턴스는 앞으로 올 때만 받음), 연속성 카메라·Handoff 실기기, Mac Spotlight/Siri 인텐트 실행, 메뉴 막대 표식(이 Mac 은 노치에 가려 글자만 보였음). 개발 환경 iCloud 에 시험 집중 기록 1건·설정 레코드가 남아 있음.