---
schema_version: 1
type: chore
slug: "udada-testflight-mac-ios-1-1"
status: done
difficulty: low
created_at: "2026-11-16T02:41:50+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/scripts/archive.sh"
    op: update
related:
  - ref: "20261116/Features_to_add/0234_feature_udada-meaning-find-precision.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: Mac·iPhone 1.1 을 TestFlight 에 올림

## 변경 요약
사용자가 Xcode 에 Apple 계정을 로그인해 둠("로그인해둠") → 어제부터 막혀 있던 업로드를 다시 돌렸다. 뜻으로 찾기(5% 기준)까지 든 1.1.

- `scripts/archive.sh --mac`: Mac 앱 아카이브 + 업로드.
- `scripts/archive.sh`: iPhone 앱 아카이브 + 업로드.

## 검증
- Mac: `** ARCHIVE SUCCEEDED **` → `Upload succeeded.` / `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`.
- iPhone: `** ARCHIVE SUCCEEDED **` → `Uploaded Udada` / `** EXPORT SUCCEEDED **`.
- 미확인: App Store Connect 에서 처리가 끝나 TestFlight 에 실제로 뜨는지, 테스터 그룹에 배포됐는지는 못 봤다(웹에서 확인해야 한다).