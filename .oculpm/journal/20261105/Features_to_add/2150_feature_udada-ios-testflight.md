---
schema_version: 1
type: feature
slug: "udada-ios-testflight"
status: done
difficulty: medium
created_at: "2026-11-05T21:50:03+09:00"
session_id: "20261105-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/project.yml"
    op: create
  - path: "udada/ios/Udada/UdadaApp.swift"
    op: create
  - path: "udada/ios/Udada/MachineView.swift"
    op: create
  - path: "udada/ios/Udada/Info.plist"
    op: create
  - path: "udada/ios/Udada/Assets.xcassets"
    op: create
  - path: "udada/ios/Config/ExportOptions.plist"
    op: create
  - path: "udada/ios/scripts/archive.sh"
    op: create
  - path: "udada/design/machine.js"
    op: update
  - path: "udada/design/machine.css"
    op: update
  - path: "udada/design/refresh.html"
    op: update
related:
  - ref: "20261105/Features_to_add/2112_feature_udada-refresh-prototype.md"
    kind: "followup"
tags:
  - "우다다"
  - "ios"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: iOS 앱 TestFlight 첫 업로드

## 추가 기능
웹 동작판(refresh·cooler·machine)을 SwiftUI + WKWebView 앱 `udada/ios` 로 감쌌다(xcodegen `project.yml`, 웹 파일은 ../design 을 번들 리소스로 직접 참조해서 복사본이 없다). 번들 ID `io.github.bunhine0452.udada`, App Store Connect 앱 이름은 「우다다: 뇌 리프레시」(「우다다」는 이미 다른 앱이 쓰고 있음), 표시 이름은 우다다.

## 동작 흐름
- 브리지 `window.webkit.messageHandlers.ud` (machine.js 의 `UD.native`):
  - `haptic` → UIImpactFeedbackGenerator / 성공 피드백 (iOS 웹뷰엔 navigator.vibrate 가 없음)
  - `awake` → isIdleTimerDisabled
  - `alarm` / `alarmCancel` → 처방 타이머 종료 시각의 로컬 알림 (잠금 화면에서도 울림)
- 앱 안에선 html 에 `ud-app` 클래스를 붙여 가짜 상태 막대를 숨기고, 안전 영역은 네이티브가 몸체 색으로 칠한다.
- 아이콘: 기계 언어(회색 몸체, LCD 막대, 파란 키)를 HTML 로 그려 헤드리스 Chrome 으로 1024 렌더 후 알파 채널 제거.
- 막힌 것과 해결: ① 아카이브가 팀 와일드카드 프로필로 서명돼 번들 ID 가 등록되지 않음 → Developer 사이트에서 직접 등록. ② 앱 레코드가 없어 `Error Downloading App Information` → 사용자 승인 후 App Store Connect 에서 레코드 생성(드롭다운은 React 라서 네이티브 setter 로 값 주입). 업로드 스크립트 `udada/ios/scripts/archive.sh`.

## 검증
- `xcodebuild … -destination id=<iPhone 16 / iOS 26.5 시뮬레이터> build` → `** BUILD SUCCEEDED **`. 시뮬레이터에 설치해 띄운 스크린샷에서 상태 화면 정상(웹 폰트 로드, 가짜 상태 막대 숨김).
- `udada/ios/scripts/archive.sh` → `** ARCHIVE SUCCEEDED **`, 웹 번들 4개 ✓, `Upload succeeded` / `** EXPORT SUCCEEDED **`.
- 웹 회귀 `tests/refresh.test.js` → `all checks passed` / `errors: none`.
- 시뮬레이터에서 탭으로 처방을 끝까지 돌려 보지는 못했다(simctl 로는 탭 불가). 실제 폰에서 햅틱·알람·화면 유지는 TestFlight 설치 후 확인해야 한다.