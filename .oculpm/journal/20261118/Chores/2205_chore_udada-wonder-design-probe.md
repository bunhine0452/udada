---
schema_version: 1
type: chore
slug: "udada-wonder-design-probe"
status: done
created_at: "2026-11-18T22:05:56+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched: []
related:
  - ref: "20261118/Features_to_add/2026_feature_udada-reply-with-my-schedule.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: 신기함 설계와 모델 한계 실험

## 무엇을
사용자가 "진짜 신기하게 만들 방안을 심층 탐구해서 설계하고 아티팩트로"를 요청. 설계 글은 아티팩트(https://claude.ai/artifact/H17fLZxeyZ4wuopvNYkB1N)에 있고 코드는 바꾸지 않았다.

## SDK 에서 본 것 (iPhoneOS 27.2 · MacOSX SDK 의 swiftinterface)
- `PrivateCloudComputeLanguageModel`(iOS 27): `availability` · `quotaUsage` · `capabilities`. `LanguageModelSession(model: some LanguageModel, …)` 로 넣는다.
- `ContextOptions(reasoningLevel: .light/.moderate/.deep)` 와 `Capability.reasoning`. `respond(…, contextOptions:)` 로 넘긴다.
- `_CoreSpotlight_FoundationModels.SpotlightSearchTool`(소스는 앱의 CoreSpotlight 색인과 파일), `_Vision_FoundationModels.OCRTool` · `BarcodeReaderTool`.
- `UIPasteboardDetectionPatternCalendarEvent`(iOS 15): 붙여넣기 허락 없이 일정처럼 보이는 글이 있는지만 안다.

## 실험 (이 Mac, 실제 모델, 서명 없는 swiftc 실행 파일)
- 기기 안 모델: `capabilities.reasoning == false`, toolCalling·vision true.
- 문제 14개(내가 지음), 문제마다 한 번, greedy:
  - 약속을 피해 N분짜리 일을 넣을 가장 이른 시각: 0/8
  - 단체 대화에서 마지막에 정해진 요일·시각·장소: 2/6
  - 가운데값 0.8초, 가장 긴 4.0초, 오류 0
- PCC: `availability=available`, `reasoning=true`, `quota=belowLimit` 로 나오지만 `respond` 가 14/14 오류. `LanguageModelError -1` 안에 `ModelManagerServices.ModelManagerError Code=1046`. 스키마 없이 글만 물어도 같다. 서명된 앱이나 권한이 필요한 것으로 짐작하나 확인 못 함.

## 설계의 뼈대
- 기기 안 모델의 머리로는 못 놀라게 한다. 자리(시키지 않아도 · 내 사정을 알고 · 그 자리에서 끝남)로 놀라게 한다.
- 1순위 화면 그대로(스크린샷 → 인텐트 → 고르는 결과 카드), 2순위 문자 자동 받기(단축어 개인 자동화), 3순위 복사 알아봄, 4순위 자판(보류).
- 만들기 전 실기기 확인 셋: 스크린샷이 인텐트로 넘어오고 카드 버튼이 눌리는가 · 메시지 자동화가 확인 없이 돌고 내용이 넘어오는가 · 서명된 앱에서 PCC 가 불리는가.

## 검증
- 실험 출력 끝 줄: `기기 안 · 그대로: 빈 시간 셈 0/8 · 대화의 최종 약속 2/6 · 가운데값 0.8초 · 가장 긴 4.0초 · 오류 0`
- PCC 쪽은 `오류 14`. 단축어 자동화와 스냅 카드 동작은 SDK 로 확인할 수 없어 재지 않았다.