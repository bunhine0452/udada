---
schema_version: 1
type: chore
slug: "udada-1-3-screen-build-upload"
status: done
created_at: "2026-11-18T22:37:41+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20261118/Features_to_add/2233_feature_udada-screen-as-is.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 화면 그대로 빌드를 TestFlight 에 올렸다

## 무엇을
사용자 요청("올려바")으로 화면 그대로 · 복사 알아보기 · 우다다로 받기가 든 iPhone 1.3 빌드를 `scripts/archive.sh` 로 올렸다(커밋 e665741). 빌드 번호는 App Store Connect 가 매긴다. Mac 은 올리지 않았다(새 기능이 iPhone 전용).

외부 그룹 "공개 테스터"에는 넣지 않았다 — 베타 심사 제출이라 사용자 확인 뒤에. 내부 테스터는 처리가 끝나면 받는다.

## 검증
- `scripts/archive.sh` 끝 줄: `Upload succeeded.` / `Uploaded Udada` / `** EXPORT SUCCEEDED **`
- App Store Connect 에서 처리 완료와 빌드 번호는 확인하지 않았다.