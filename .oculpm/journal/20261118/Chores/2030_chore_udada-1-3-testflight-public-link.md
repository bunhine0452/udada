---
schema_version: 1
type: chore
slug: "udada-1-3-testflight-public-link"
status: done
difficulty: low
created_at: "2026-11-18T20:30:25+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "README.md"
    op: update
  - path: "udada/ios/project.yml"
    op: update
related:
  - ref: "20261118/Errors/2011_error_udada-1-3-upload-blocked-login.md"
    kind: "followup"
  - ref: "20261118/Features_to_add/2026_feature_udada-reply-with-my-schedule.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 1.3 TestFlight 올리고 공개 링크

## 변경 요약
사용자(11-18): "올려줘 그리고 testflight 초대도 자동으로 되도록 깃허브에 올려줄수있나?" → (로그인 만료로 막힘) → "로그인해뒀어".

- 1.3(빌드 1)을 iPhone · Mac 둘 다 올렸다. 들어 있는 것: 한 주 풀기 · 말하는 동안 카드 · 받은 약속에 답장 · 사용법 장면 고침.
- App Store Connect: 바깥 테스터 묶음 '공개 테스터' 생성 → 테스트 정보(베타 앱 설명 · 피드백 이메일 · 심사 연락처 · 심사 메모) 입력 → iOS 1.3 (1) 을 묶음에 넣고 베타 심사 제출('로그인 필요'는 껐다) → 공개 링크 '모두에게 공개'.
- 연락처는 사용자에게 물어 '앱 심사 정보와 같은 값으로'라는 답을 받고 넣었다.
- 공개 링크를 README 맨 위에 넣었다: `https://testflight.apple.com/join/3Byb5p4P`.

## 검증
- 올리기: `Uploaded Udada` / `** EXPORT SUCCEEDED **`, `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`.
- ASC 화면에서 읽은 상태: 공개 테스터 묶음 `빌드(1) · 1.3 (1) · 심사 대기 중 · iOS`. 공개 링크 칸: "테스터는 이 그룹에 빌드가 승인될 때까지 공개 링크에 참여할 수 없습니다."
- `curl` 로 링크 응답 200.
- 안 한 것: Mac 1.3 은 올리기만 하고 바깥 묶음에 안 넣었다. 베타 심사가 끝나기 전에는 링크로 들어와도 설치가 안 된다. 안쪽 묶음('나 혼자')에 1.3 이 떴는지는 안 봤다.