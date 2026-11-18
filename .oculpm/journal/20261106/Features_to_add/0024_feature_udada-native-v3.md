---
schema_version: 1
type: feature
slug: "udada-native-v3"
status: done
difficulty: high
created_at: "2026-11-06T00:24:16+09:00"
session_id: "20261106-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/project.yml"
    op: update
  - path: "udada/ios/Udada/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/MachineView.swift"
    op: delete
  - path: "udada/ios/Udada/Model/Catalog.swift"
    op: create
  - path: "udada/ios/Udada/Model/Store.swift"
    op: create
  - path: "udada/ios/Udada/Model/Flow.swift"
    op: create
  - path: "udada/ios/Udada/Kit/Theme.swift"
    op: create
  - path: "udada/ios/Udada/Kit/Keys.swift"
    op: create
  - path: "udada/ios/Udada/Kit/Display.swift"
    op: create
  - path: "udada/ios/Udada/Kit/Knob.swift"
    op: create
  - path: "udada/ios/Udada/Screens/HomeView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/RxView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/RunView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/DumpView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/AfterView.swift"
    op: create
  - path: "udada/ios/UdadaTests/CatalogTests.swift"
    op: create
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: create
  - path: "udada/ios/scripts/archive.sh"
    op: update
related:
  - ref: "20261105/Features_to_add/2327_feature_udada-fit-keyboard-value.md"
    kind: "followup"
tags:
  - "우다다"
  - "ios"
  - "design"
  - "mcp-tool"
---
[x] 우다다: SwiftUI 네이티브로 다시 만듦

## 추가 기능
사용자 "앱 구려" → 고른 문제: 웹페이지 같은 느낌, 처방 시간이 심심함, 단계가 많음, 버튼이 너무 단순함. WKWebView 앱을 버리고 `udada/ios` 를 SwiftUI 네이티브(iOS 17, @Observable)로 다시 만들었다. 웹 동작판(udada/design)은 디자인 기준으로만 남긴다. 버전 0.3.0.

## 동작 흐름
- **부품(Kit)**: 입체 키 KeyStyle(윗면 + 측면 두께 + 윗선 하이라이트, 누르면 내려앉고 딸깍 + 햅틱), 각인 라벨 + LED, 널링 노브(72개 홈, 한 칸마다 선택 햅틱), 직접 그린 7세그먼트 숫자(꺼진 칸이 흐리게 남음), LCD 판, 0~10 맑기 막대(드래그), 슬롯에서 찍혀 나오는 영수증.
- **단계 줄임**: 홈에서 상태 하나 누르면 바로 처방 화면. 시간(2/10/20)·지금 맑기·책갈피를 한 화면에서 고르고, 시간·맑기는 지난번 값을 기억한다. 홈에 '지난번처럼' 키. 시작 키는 safeAreaInset 이라 키보드 바로 위에 붙고, 입력을 시작하면 입력칸을 끌어올린다. SE 처럼 낮은 화면은 영수증을 촘촘하게.
- **처방마다 다른 실행 화면**: 호흡은 아날로그 바늘 게이지(코로 훅 → 한 번 더 → 입으로 길게, 들숨에 부드러운 햅틱), 걷기는 CMPedometer 걸음 수 7세그먼트, 눈 감기·낮잠은 숨 쉬듯 밝아지는 점 하나와 흐린 시계, 나머지는 큰 카운트다운. 시간은 시작 시각 기준이라 백그라운드에서 돌아와도 맞고, 로컬 알림으로 잠금 화면에서도 깨운다.
- **꽉 찼어 → 머리 비우기**: TextEditor 로 쏟아내기 → 카드 한 장씩 4칸 분류(단어 규칙 제안, 날짜 칩) → 숨 → 돌아옴 화면에 '지금 할 단 하나'. 서랍(날짜·손 밖)은 홈에서 연다.
- 돌아옴(책갈피 먼저 + 노브), 결과(7세그먼트 전후, 내 기록 막대, 다음 비교 제안, 책갈피가 있으면 '돌아가서 하기').
- 테스트 중 고친 것: 뒤로 키가 반 화면으로 늘어남 → 크기 고정. SE 에서 책갈피 칸이 시작 키 막대 뒤에 걸려 시작이 눌림 → 촘촘한 영수증 + 테스트에서 위치 검사. 기록이 쌓이면 SE 홈이 넘쳐 위 막대가 상태 막대에 붙음 → 상태 키가 먼저 줄게. Pro Max 홈 위쪽 빈 공간 → 키가 채우게.

## 검증
- `xcodebuild test -scheme Udada -destination id=<iPhone SE 3> -destination id=<iPhone 16 Pro Max>` (iOS 26.5) → 단위 7 + UI 3, 두 기기 모두 통과, 끝 줄 `** TEST SUCCEEDED **`. UI 테스트는 실제로 탭한다: 멍해 → 다른 거 토글 → 책갈피 입력 중 화면 키보드가 뜨고 시작 키가 키보드 위에서 눌림 → 걷기 화면 → 노브 7 → 결과 +3 → 홈 기록·지난번처럼 / 머리 비우기 7장 분류 → 서랍 / 낮잠·호흡 화면.
- 확인 후 시뮬레이터 2대 삭제, 시뮬레이터 하드웨어 키보드 설정 원복, build/dd(515M) 삭제.
- `scripts/archive.sh` → `Upload succeeded` / `** EXPORT SUCCEEDED **` (빌드 3). 실기기 햅틱·만보계·알림은 TestFlight 로 확인해야 한다.