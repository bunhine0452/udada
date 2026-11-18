---
oculpm_plan: v1
id: udada-sorter-v4
title: "우다다: 머릿속 정리 기계로 재정의"
status: active
created: 2026-11-06
updated: 2026-11-06
owner: claude-code
---

"이 앱이 뭔데?"에 한 문장으로 답하게. 쏟아내기 → 한 장씩 정리 → 지금 할 단 하나. 처방 고르기는 뺀다. 근거는 VALUE.md.

**완료 조건:** 처음 연 사람이 첫 화면만 보고 '머릿속 걸 쏟아내서 정리하는 앱'이라고 말할 수 있고, 정해 둔 날짜·걱정 시간에 알림으로 돌아오는 빌드가 SE·Pro Max UI 테스트를 통과해 TestFlight에 올라간다
**확인 명령:** cd udada/ios && xcodebuild test -project Udada.xcodeproj -scheme Udada -destination "id=$SE" -destination "id=$PM" 2>&1 | tail -1

## 핵심 흐름 {#core}
- [x] 항목·언제·알림 모델 (단위 테스트) {#model}
- [x] 첨 화면: 한 문장·쏟아내기·오늘 할 것 {#home}
- [x] 쏟아내기·한 장씩 정리·파쇄 {#sort}
- [x] 끝: 지금 할 단 하나·머리 소음·숨 {#finish}
- [x] 정리함과 알림 (날짜·걱정 시간) {#drawer}

## 검증·배포 {#ship}
- [x] UI 테스트 SE·Pro Max {#uitest}
- [x] TestFlight 빌드 4 {#upload}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-11-06T00:59:41+09:00 | #model | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md |  |
| 2026-11-06T00:59:46+09:00 | #home | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md |  |
| 2026-11-06T00:59:52+09:00 | #sort | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md |  |
| 2026-11-06T00:59:58+09:00 | #finish | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md |  |
| 2026-11-06T01:00:07+09:00 | #drawer | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md | 알림 계획 단위 테스트 통과, 실기기 도착 미확인 |
| 2026-11-06T01:00:18+09:00 | #uitest | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md | 판정 ✓ ** TEST SUCCEEDED ** (SE·16 Pro Max) |
| 2026-11-06T01:00:24+09:00 | #upload | claude-code | ☐→x | .oculpm/journal/20261106/Features_to_add/0059_feature_udada-sorter-v4.md | 판정 ✓ ** TEST SUCCEEDED ** · Upload succeeded (빌드 4, 0.4.0) |
<!-- oculpm:plan-log end -->
