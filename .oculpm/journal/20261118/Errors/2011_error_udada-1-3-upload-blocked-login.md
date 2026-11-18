---
schema_version: 1
type: error
slug: "udada-1-3-upload-blocked-login"
status: in_progress
difficulty: low
created_at: "2026-11-18T20:11:26+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/project.yml"
    op: update
related:
  - ref: "20261118/Features_to_add/2006_feature_udada-live-voice-cards.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "mcp-tool"
---
[ ] 우다다: 1.3 업로드가 로그인 만료로 막힘

## 발생 원인
사용자(11-18): "올려줘 그리고 testflight 초대도 자동으로 되도록 깃허브에 올려줄수있나?" — 버전을 1.3 으로 올리고 `scripts/archive.sh` 를 iPhone · Mac 으로 돌렸다.

- 아카이브는 둘 다 됐지만 올리기에서 `error: exportArchive No Accounts with App Store Connect Access` / `** EXPORT FAILED **` (iPhone · Mac 둘 다).
- 같은 때 App Store Connect 웹도 로그인 화면으로 돌아갔다(`authResult=FAILED`). 오후에는 같은 방법으로 1.2 올리기와 공증이 됐으니, Apple 계정 세션이 그 사이에 끝난 것으로 보인다.

## 해결 방법
로그인은 사용자가 해야 한다 (암호 · 인증 번호를 내가 넣지 않는다).
1. Xcode → Settings → Accounts 에서 Apple 계정을 다시 로그인.
2. 크롬의 App Store Connect 를 다시 로그인.
그 뒤 이어서 할 일: `scripts/archive.sh` · `scripts/archive.sh --mac` 다시 → TestFlight 에 바깥 테스터 묶음과 공개 링크 만들기(베타 심사 제출 포함) → README 에 링크.

## 검증
- 결과 끝 줄: `error: exportArchive No Accounts with App Store Connect Access` / `** EXPORT FAILED **` (두 번).
- 1.3 으로 올린 `project.yml` 은 커밋 `fdb1672` 로 올렸다. TestFlight 에는 아무것도 안 올라갔고, 공개 링크도 아직 없다.