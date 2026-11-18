---
schema_version: 1
type: feature
slug: "udada-film-opensource-nightly"
status: done
difficulty: medium
created_at: "2026-11-18T19:18:10+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/film/main.swift"
    op: create
  - path: "udada/film/Stubs.swift"
    op: create
  - path: "udada/film/render.sh"
    op: create
  - path: "udada/ios/scripts/nightly.sh"
    op: create
  - path: "udada/ios/UdadaMac/UdadaMacNightly.entitlements"
    op: create
  - path: "udada/ios/Udada/Sync/CloudSync.swift"
    op: update
  - path: "README.md"
    op: create
  - path: "LICENSE"
    op: create
  - path: ".gitignore"
    op: update
  - path: "docs/udada-preview.gif"
    op: create
related:
  - ref: "20261118/Chores/1854_chore_udada-old-shots-removed-promo-kit.md"
    kind: "followup"
  - ref: "20261118/Features_to_add/1814_feature_udada-1-3-guide-ai-door-siri.md"
    kind: "followup"
tags:
  - "우다다"
  - "mac"
  - "design"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 소개 영상·오픈소스 공개·Mac nightly

## 추가 기능
사용자(11-18): "피처링 요청 넣고 sns는 활용하지 않을거야" → "앱을 소개하는 영상을 매우매우 고퀄리티로 만들어서 내 앱 nightly 버전을 깃허브에 배포하자. 오픈소스로."

- **피처링 요청**: App Store Connect 에서 '앱 개선' 유형으로 제출(이름 `우다다 1.2 Siri 업데이트`, 게시일 11-23, iPhone). 설명·차별점 글은 내가 썼다. 첫 저장이 '문제가 발생했습니다'로 실패했는데 초안은 남았다 — 초안 `우다다 1.2 — Apple Intelligence·Siri 업데이트` 하나가 목록에 그대로 있다(안 지웠다).
- **소개 영상** (`udada/film/`): 화면 녹화가 아니라 앱의 사용법 장면 코드(GuideKit · GuideScenes · AITour)를 그대로 컴파일해 프레임마다 `ImageRenderer` 로 그리고 ffmpeg 로 흘린다. 여는 장면 → 여섯 장면(적기 · 세 칸 · 쏟아내기 · 말로 시키기 · Siri · 식히고 닫기) → 닫는 장면. 90.9초, 60fps, 1080p 와 4K, 소리 없음. `render.sh` 한 번이면 다시 나온다(1080p 약 45초).
- **오픈소스**: `github.com/bunhine0452/udada` 공개, MIT (사용자의 다른 공개 저장소가 전부 MIT 라 그 관례를 따랐다). 저장소 뿌리는 `brain_cooler/` 그대로(udada/ · .oculpm/ · AGENTS.md). 빌드 산출물 · 생성된 xcodeproj · 백업 tgz 는 제외.
- **Mac nightly**: `scripts/nightly.sh [--publish]`. Developer ID 로 서명, iCloud 권한 없음(`UdadaMacNightly.entitlements`), 번들 ID `…udada.nightly` 로 App Store 판과 저장소 분리. `CloudSync.allowed` 가 macOS 에서 iCloud 권한이 없으면 꺼지게 했다(권한 없이 CloudKit 을 부르면 죽는다). 릴리스 `nightly`(prerelease)에 zip · sha256 · 영상 두 벌.

## 검증
- 영상: `ffprobe` → `1920,1080,60/1 · 90.9s`, `3840,2160,60/1 · 90.9s`. 프레임 16장을 뽑아 눈으로 확인.
- nightly 앱: `codesign --verify --deep --strict` 통과, `Identifier=io.github.bunhine0452.udada.nightly`, 실행 인자 없이 띄워 7초 뒤 살아 있음. `spctl` 은 `rejected · source=Unnotarized Developer ID` — 공증을 안 해서 처음 열 때 사용자가 허용해야 한다.
- `xcodebuild test -scheme UdadaMac`(CloudSync 고친 뒤): `Executed 60 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- 공개 전 검사: 토큰 · 키 · 인증서 파일 없음. 이메일은 `appstore/privacy.md` 의 연락처(이미 공개 페이지에 있는 것)뿐.
- `gh api repos/bunhine0452/udada` → `visibility public · license MIT`, 릴리스 자산 4개.
- 안 한 것: 공증(notary 자격 증명이 이 Mac 에 없다), iPhone nightly(서명 때문에 못 나눠 준다), 날마다 자동으로 도는 빌드(CI 없음 — 스크립트를 손으로 돌려야 한다), 영상의 소리.