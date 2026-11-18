---
schema_version: 1
type: chore
slug: "udada-old-shots-removed-promo-kit"
status: done
difficulty: low
created_at: "2026-11-18T18:54:38+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/appstore/promo/posts.md"
    op: create
  - path: "udada/appstore/promo/card-1-today.png"
    op: create
  - path: "udada/appstore/screenshots/preview.png"
    op: delete
  - path: "udada/appstore/screenshots/mac/4-stuck.png"
    op: delete
  - path: "udada/appstore/README.md"
    op: update
related:
  - ref: "20261118/Chores/1849_chore_udada-1-2-shots-submit.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 옛 스크린샷 지우고 홍보 글·카드 준비

## 변경 요약
사용자(11-18): "네가 지워줘 그리고 내 앱 홍보해줘".

- **지움**: 1.1 때 스크린샷 `screenshots/ko/`(세 크기 폴더 통째), `mac/4-stuck.png`, 옛 `preview.png`. 새것은 `screenshots/v1.2/` 와 `mac/1~4`.
- **홍보 준비** (`appstore/promo/`): 채널별 글 `posts.md`(짧은 글 · 만든 이야기 · 사용자 커뮤니티 · 1.2 가 나온 뒤) + 1080×1350 카드 넉 장.
- 지금 스토어에 있는 것은 1.1 이라, 글은 1.1 에 실제로 있는 것만 말하게 썼다. Siri 시키기 · 사용법 · AI 버튼(1.2, 심사 중)을 말하는 글과 카드 석 장에는 `after-1.2` 를 붙여 따로 뒀다.

## 검증
- `ls screenshots` → `mac  v1.2`, `ls screenshots/mac` → `1-day 2-dump 3-find 4-siri`.
- 스토어 주소 `apps.apple.com/kr/app/id6831147747` 응답 200.
- **아직 아무 데도 올리지 않았다** — 어느 채널에 어떤 계정으로 올릴지는 사용자가 정해야 한다.