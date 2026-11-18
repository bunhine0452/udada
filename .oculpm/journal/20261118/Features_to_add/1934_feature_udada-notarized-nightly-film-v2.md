---
schema_version: 1
type: feature
slug: "udada-notarized-nightly-film-v2"
status: done
difficulty: medium
created_at: "2026-11-18T19:34:27+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/scripts/nightly.sh"
    op: update
  - path: "udada/film/main.swift"
    op: update
  - path: "udada/film/sfx.py"
    op: create
  - path: "udada/film/render.sh"
    op: update
  - path: "udada/ios/Udada/AI/GuideScenesA.swift"
    op: update
  - path: "README.md"
    op: update
  - path: "docs/udada-preview.gif"
    op: update
related:
  - ref: "20261118/Features_to_add/1918_feature_udada-film-opensource-nightly.md"
    kind: "followup"
tags:
  - "우다다"
  - "mac"
  - "design"
  - "mcp-tool"
---
[x] 우다다: nightly 공증, 소개 영상 53초 컷으로

## 추가 기능
사용자(11-18): "공증까지 네가해줘" · (영상의 칸 그림을 보이며) "이 부분이 이상해. 애초에 영상 이게 최선이야?" · "진짜 애플 인텔리전스 활용한 기능 … 이게 최선이야?"

- **공증**: 암호를 넣지 않는 길을 썼다 — `xcodebuild -exportArchive`(method developer-id · destination upload)가 Xcode 에 로그인된 계정으로 공증 서비스에 올리고, `xcodebuild -exportNotarizedApp` 으로 표가 붙은 앱을 받는다. `nightly.sh` 에 `NIGHTLY_NOTARIZE=1` 로 넣었다. 두 번 다 1분 안에 끝났다.
- **칸 버그**: 쏟아내기 장면에서 칸에 앉은 카드가 칸 밖으로 삐져나왔다. 긴 카드와 짧은 카드를 겹쳐 두고 투명도만 바꿔서, 안 보이는 긴 카드의 최소 폭이 짧은 카드의 판을 밀어냈다. 날아가는 도중에 하나만 두고 폭으로 자르게 고쳤다. **앱의 사용법에도 같은 버그가 있다 — 심사 중인 1.2(빌드 3)에는 그대로 들어 있다.**
- **영상 다시**: 90.9초 → 52.9초. 가장 놀라운 것(Siri)부터, 컷마다 바탕색(먹 · 종이 · 코발트), 설명은 세 줄 목록 대신 그 대목의 한 줄, 화면이 천천히 다가감, 장면마다 쓰는 구간만 잘라 씀. 효과음은 `sfx.py` 가 사인파와 잡음으로 만든다(자판 · 누름 · 톡 · 앉음 · 도장 · 화음 63개) — 가져다 쓴 음원 없음.
- SDK 에서 본 것(iOS 27): 모델의 도구 호출(`onToolCall`) · `SpotlightSearchTool`(앱의 Spotlight 색인을 모델이 직접 찾는 도구) · `OCRTool` · 추론 단계. 우다다는 이 가운데 아무것도 안 쓴다(구조화된 출력 13곳 · 흘려 받기 1곳뿐).

## 검증
- 공증: `spctl -a -vv` → `accepted · source=Notarized Developer ID`, `stapler validate` → `The validate action worked!`. 릴리스 글에 공증 문구가 들어간 것을 `gh release view` 로 확인.
- 영상: `52.9s 3174 frames` 1080p · 4K, 소리 `aac 2ch · max -1.1 dB`. 프레임 12장을 뽑아 칸 안에 카드가 앉은 것과 기기가 프레임 안에 있는 것을 확인. **소리는 들어 보지 못했다(크기만 쟀다).**
- 안 한 것: 고친 사용법 장면을 앱 빌드로 다시 올리지 않았다. nightly zip 도 고치기 전 커밋으로 만든 것이다.