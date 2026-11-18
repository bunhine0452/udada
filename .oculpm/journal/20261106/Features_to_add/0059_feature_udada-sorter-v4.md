---
schema_version: 1
type: feature
slug: "udada-sorter-v4"
status: done
difficulty: high
created_at: "2026-11-06T00:59:34+09:00"
session_id: "20261106-001"
agent:
  id: "claude-code"
  version: "claude-opus-5-5"
  session: "b895a277-53df-4b2e-938c-a1e89943330c"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Model/Items.swift"
    op: create
  - path: "udada/ios/Udada/Model/Store.swift"
    op: update
  - path: "udada/ios/Udada/Model/Flow.swift"
    op: update
  - path: "udada/ios/Udada/Model/Catalog.swift"
    op: delete
  - path: "udada/ios/Udada/UdadaApp.swift"
    op: update
  - path: "udada/ios/Udada/Screens/HomeView.swift"
    op: update
  - path: "udada/ios/Udada/Screens/SortView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/FinishView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/DrawerView.swift"
    op: create
  - path: "udada/ios/Udada/Screens/RxView.swift"
    op: delete
  - path: "udada/ios/Udada/Screens/RunView.swift"
    op: delete
  - path: "udada/ios/Udada/Screens/AfterView.swift"
    op: delete
  - path: "udada/ios/Udada/Screens/DumpView.swift"
    op: delete
  - path: "udada/ios/Udada/Kit/Knob.swift"
    op: delete
  - path: "udada/ios/Udada/Kit/Theme.swift"
    op: update
  - path: "udada/ios/UdadaTests/CatalogTests.swift"
    op: update
  - path: "udada/ios/UdadaUITests/FlowUITests.swift"
    op: update
related:
  - ref: "20261106/Features_to_add/0024_feature_udada-native-v3.md"
    kind: "followup"
  - ref: "20261104/Chores/1900_chore_udada-value-redesign-research.md"
    kind: "followup"
tags:
  - "우다다"
  - "ios"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 머릿속 정리 기계로 재정의

## 추가 기능
사용자: "그래서 이 앱이 뭔데? 했을 때 뭔지 잘 모르겠어." 원인은 이름(우다다 = 해치우기)과 내용(쉬기) 불일치, 세 갈래 기능, 앱 안에서만 통하는 말, 결과를 말하지 않는 첫 화면이었다. 세 가지 한 문장 후보 중 사용자가 "머릿속 정리 기계"를 골랐다. 그래서 **우다다 = 머릿속에 떠도는 걸 우다다 쏟아내고, 하나씩 '언제' 아니면 '안 함'을 붙여 닫아 주는 정리 기계**로 다시 만들었다(0.4.0). 근거는 VALUE.md 의 원래 핵심(Masicampo & Baumeister 2011, McGowan & Behar 2013, Scullin 2018).

## 동작 흐름
- 뺀 것: 상태 고르기, 처방 13개, 걷기·낮잠 화면, 만보계 권한, 노브.
- 첫 화면: "머릿속 거, 우다다 쏟아내." + 머리 소음 0~10 + 남는 공간을 채우는 큰 [쏟아내기] + 오늘 할 것(✓) + 닫은 고리 7세그먼트. 정리함 키에 남은 개수.
- 쏟아내기(키보드 바로 위 [정리하기]) → 한 장씩 네 칸: 지금(2분이면 끝) / 날짜 정하기(오늘 저녁·내일 아침·이번 주말·다음 주 → 실제 시각) / 걱정 시간(매일 21:30) / 버리기(카드가 10줄로 찢어져 떨어지는 파쇄 + 드르륵 햅틱).
- 끝: 지금 할 단 하나 영수증 + 칸별 개수 + 머리 소음 다시 + [숨 고르기 1분(바늘 게이지)][끝] → 홈에 "머리에서 N개를 내려놨어. 소음 a → b." 소식.
- '언제'를 진짜로: Reminders.plan/sync 가 날짜 칸은 그 시각에, 걱정 칸은 다음 21:30 에 로컬 알림을 건다. 권한은 날짜·걱정을 처음 정리했을 때 묻는다.
- 쉬운 말: 처방·맑기·책갈피·UD-R 대신 쏟아내기·정리·오늘 할 것·걱정 시간·정리함·머리 소음.

## 검증
- 단위 5개: 단어 규칙 제안, When 시각 계산(금요일 기준, 저녁 7시 지남, 토요일 오후의 '이번 주말', 월요일의 '다음 주'), 알림 계획(끝난 것 제외, 22시 이후 걱정은 다음 날), 표기, 호흡 박자.
- UI 1개(전체 흐름): 소개 → 홈 → 쏟아내기 중 화면 키보드 위에서 [정리하기] 눌림 → 5장 정리(지금·주말·걱정·파쇄·내일) → 끝 화면 '엄마한테 전화' → 숨 고르기 → 홈 소식 '5개'·오늘 할 것 → 정리함(걱정 시간 묶음, 버린 건 없음).
- `xcodebuild test -destination id=<iPhone SE 3> -destination id=<iPhone 16 Pro Max>` → `** TEST SUCCEEDED **`. 스크린샷으로 [숨 고르기] 키 찌그러짐, Pro Max 홈 빈 공간을 잡아 고친 뒤 다시 통과.
- 시뮬레이터 2대 삭제, 키보드 설정 원복(unset), build/dd 219M 삭제. `scripts/archive.sh` → `Upload succeeded` / `** EXPORT SUCCEEDED **` (빌드 4).
- 실기기 알림 시각 도착은 확인하지 못했다. App Store Connect 앱 이름은 아직 '우다다: 뇌 리프레시'.