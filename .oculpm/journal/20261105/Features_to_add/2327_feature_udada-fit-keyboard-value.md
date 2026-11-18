---
schema_version: 1
type: feature
slug: "udada-fit-keyboard-value"
status: done
difficulty: high
created_at: "2026-11-05T23:27:26+09:00"
session_id: "20261105-002"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/design/machine.css"
    op: update
  - path: "udada/design/machine.js"
    op: update
  - path: "udada/design/refresh.html"
    op: update
  - path: "udada/design/cooler.html"
    op: update
  - path: "udada/design/tests/layout.test.js"
    op: create
  - path: "udada/design/tests/refresh.test.js"
    op: update
  - path: "udada/ios/Udada/MachineView.swift"
    op: update
  - path: "udada/ios/Udada/UdadaApp.swift"
    op: update
related:
  - ref: "20261105/Features_to_add/2150_feature_udada-ios-testflight.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "ios"
  - "mcp-tool"
---
[x] 우다다: 모든 화면·키보드 대응과 가치 강화

## 추가 기능
사용자: "디자인은 맘에 드는데 UI 배치·화면 크기가 모든 폰에 맞아야 하고, 키보드 대비, 가치를 확실하게. 웹검색으로 공부해." 웹검색으로 확인한 것: WKWebView 는 키보드가 올라와도 스스로 줄지 않는다, 입력 글자 16px 미만이면 iOS 가 자동 확대한다, 터치 영역 44pt, 360×640 ~ 440×956 대응, 정신건강 앱 30일 잔존 중앙값 3.3%(Baumel 2019 JMIR) → 첫 세션의 가치 전달이 중요.

## 동작 흐름
- **감사 테스트** `tests/layout.test.js`: 7개 크기(360×640·375×667·375×812·390×844·402×874·440×956·412×915) × refresh/cooler 전 화면 × 키보드(포커스 → 뷰포트 44% 축소)에서 넘침·화면 밖·44px 미만 터치·키보드 위 주 버튼·입력 16px 를 판정. 처음 돌렸을 때 89건 실패.
- **비례 배율**: CSS px 를 전부 rem 으로 바꾸고(1~2px 선만 px), machine.js 가 html 글자 크기 = 16 × k, k = min(가로/390, 세로/800) 으로 맞춘다. 세로는 키보드 없을 때 높이(baseH)로 재서 키보드가 떠도 기계가 줄지 않는다. 키에는 44px 하한.
- **키보드**: 보이는 높이를 --appH 로, 입력 중에 120px 넘게 줄면 html.kb → .kb-hide(영수증·숫자판·힌트)를 접는다. iOS 는 MachineController(UIKit)에서 웹뷰 아래를 keyboardLayoutGuide 에 붙여 키보드 위까지만 차지하게 했다. 빈 곳을 탭하면 키보드가 내려간다(버튼은 제외: 누르는 순간 배치가 바뀌면 손가락 아래 버튼이 바뀜).
- **가치**: 첫 실행 소개 한 장("머리가 안 돌아갈 때 2~20분 만에 다시 돌게" + 3단계 + 치료 아님), 홈·결과에 '내 기록'(최근 8회 전후 막대, 평균, 제일 잘 든 처방), 책갈피를 적었으면 결과의 끝을 '이제 할 것 → 돌아가서 하기'로.
- 빈 공간 정리: 다이얼·돌아옴 노브는 가운데, 처방 영수증 묶음은 위아래 가운데, 식히기 분류 카드는 LCD 를 키움.
- 디버깅: ① 변환 스크립트가 machine.css 를 읽기 전에 쓰기 모드로 열어 비움 → 백업에서 복구 후 재변환. ② 키보드로 화면이 가로보다 낮아지면 orientationchange 가 와서 기준 높이가 리셋됨 → 입력 중엔 리셋 안 함.

## 검증
- `tests/layout.test.js` → 89건에서 끝 줄 `layout: 0 fail` / `errors: none`.
- `tests/refresh.test.js` (소개·기록·책갈피 체크 추가) → `all checks passed` / `errors: none`. `tests/shredder.test.js` → `errors: none`.
- iPhone SE·16 Pro Max 시뮬레이터(iOS 26.5)에서 첫 화면 비율이 같게 뜨는 것 확인 후 시뮬레이터 삭제. `scripts/archive.sh` → `Upload succeeded` / `** EXPORT SUCCEEDED **` (빌드 2).
- 실기기 키보드 동작(keyboardLayoutGuide)은 시뮬레이터에서 탭할 수 없어 확인하지 못했다. TestFlight 빌드 2로 확인해야 한다.