---
schema_version: 1
type: bug
slug: "udada-motion-nonsense-fixes"
status: done
difficulty: medium
created_at: "2026-11-16T06:56:35+09:00"
session_id: "20261116-002"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Shared/Theme.swift"
    op: update
  - path: "udada/ios/Udada/AI/AITour.swift"
    op: update
  - path: "udada/ios/Udada/Today/DaySheetView.swift"
    op: update
  - path: "udada/ios/Udada/Today/TodayView.swift"
    op: update
  - path: "udada/ios/UdadaMac/DayWindow.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacDay.swift"
    op: update
  - path: "udada/ios/UdadaMac/MacFind.swift"
    op: update
  - path: "udada/ios/Udada/Find/FindView.swift"
    op: update
  - path: "udada/ios/Udada/AI/Finder.swift"
    op: update
  - path: "udada/ios/UdadaUITests/TodayUITests.swift"
    op: update
related:
  - ref: "20261116/Features_to_add/0457_feature_udada-1-2-bands-ai-tour.md"
    kind: "followup"
  - ref: "20261116/Features_to_add/0339_feature_udada-capture-audio-stuck-calm.md"
    kind: "followup"
tags:
  - "우다다"
  - "design"
  - "mac"
  - "testflight"
  - "mcp-tool"
---
[x] 우다다: 말이 안 되던 움직임 열 군데 고침

## 발생 원인
사용자(11-16, 1.2 TestFlight 를 써 보고): "모션들이 부드럽게 가긴하는데, 어불성설이 있는곳이 있어 UI들의 오류들을 찾고 고쳐줘". 어느 곳인지는 말하지 않았다 — 내가 코드를 읽고, 시뮬레이터를 녹화해 프레임으로 찾았다.

찾은 것과 원인:
1. **끝낸 줄의 잉크가 그어지지 않고 통째로 나타남** — `ViewThatFits` 가 끝내는 순간 글자 뷰를 갈아 끼워 긋는 애니메이션이 끊겼다. 한 줄 높이를 숨긴 뷰의 onAppear 로 잰 첫 고침도 값이 안 들어와 취소선으로 떨어졌다.
2. 튜토리얼이 되풀이될 때 카드가 칸에서 **거꾸로 날아 나옴** (phase 를 0 으로 되돌리며 애니메이션).
3. 사진 장면: 읽는 줄이 내려가기 **전에** 테두리가 생김 (둘이 같은 걸음에 묶여 있었다).
4. 받기 장면: 표시가 뒤늦게 끼어들며 약속 덩어리를 밀어 냄.
5. 쪼개기 장면: 큰일 덩어리가 까닭 없이 줄어듦.
6. 마지막 일을 끝내면 쉼 카드가 **맨 위에** 끼어들어 누르던 목록이 밀림 (Mac 도).
7. 지난 칸의 마지막 일을 끝내는 순간 그 칸이 접힘.
8. 하루 띠: 지금 칸의 막대만 굵음.
9. 찾기: 뜻으로 더 찾는 동안 "찾은 게 없어"를 먼저 말했다가 뒤집음.
10. Mac 넘어온 일 카드: '작게 쪼개기'를 누르고 닫기만 해도 카드가 사라짐.

## 해결 방법
- `StruckText`(Shared/Theme): 글자 뷰는 하나로 두고, 높이를 preference 로 재서 한 줄이면 `InkStrike`, 여러 줄이면 취소선.
- `TourPlayer`: 되풀이 사이에 막(opacity)을 닫고 애니메이션 없이 처음으로 돌린 뒤 다시 연다.
- 사진 장면의 줄은 1걸음에서 내려가고 테두리는 2걸음에서. 받기 장면의 표시는 자리를 미리 잡는다. 쪼개기의 scaleEffect 삭제.
- 쉼 카드는 목록 맨 아래(iPhone) · 세 칸 아래(Mac). 접기는 칸을 그리기 시작했을 때의 상태(`clearAtOpen`)로. 막대는 4pt 로 통일, 눈금만 11pt.
- 찾는 중에는 `FindRules.searching`. Mac 카드는 `keepStuck`(한 주 쉼).
- 녹화용 UI 테스트 `testMotionWalk`(TEST_RUNNER_MOTION=1 일 때만).

## 검증
- 녹화(simctl recordVideo) → 30fps 프레임: 줄을 끝낸 뒤 잉크가 프레임마다 왼쪽에서 오른쪽으로 늘어남(고치기 전에는 한 프레임에 통째로). 사진 장면은 줄이 바닥에 닿은 뒤 테두리 → 약속 덩어리 순. 쏟아내기 장면의 되풀이 경계는 흐려짐 → 빈 칸 → 다시 시작.
- `xcodebuild test -scheme UdadaMac`: `Executed 60 tests, with 0 failures` / `** TEST SUCCEEDED **`. iOS 전체: `Executed 48 tests, with 3 tests skipped and 0 failures` + 단위 `Executed 35 tests, with 0 failures` / `** TEST SUCCEEDED **`.
- TestFlight 1.2 다시 올림: `Uploaded Udada` · `Uploaded UdadaMac` / `** EXPORT SUCCEEDED **`.
- 눈으로 못 본 것: 4~10번(코드로만 고침), Mac 의 움직임, 비우기·식히기·하루 닫기 같은 앞서 있던 화면. 사용자가 말한 '어불성설'이 이 열 가지 안에 있는지는 모른다.