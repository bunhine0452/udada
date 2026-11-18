---
schema_version: 1
type: chore
slug: "udada-release-1-0-prepare-1-1-mac"
status: done
difficulty: medium
created_at: "2026-11-16T04:03:21+09:00"
session_id: "20261116-001"
agent:
  id: "claude-code"
  version: "Fable 5.2"
  session: "7559962c-2a54-45e1-bb83-611d8c6d7b8d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/appstore/metadata/mac-ko/description.txt"
    op: create
  - path: "udada/appstore/metadata/mac-ko/keywords.txt"
    op: create
  - path: "udada/appstore/screenshots/mac/1-day.png"
    op: create
  - path: "udada/appstore/screenshots/mac/4-stuck.png"
    op: create
  - path: "udada/ios/UdadaMac/UdadaMacApp.swift"
    op: update
related:
  - ref: "20261116/Chores/0241_chore_udada-testflight-mac-ios-1-1.md"
    kind: "followup"
  - ref: "20261116/Features_to_add/0339_feature_udada-capture-audio-stuck-calm.md"
    kind: "followup"
tags:
  - "우다다"
  - "testflight"
  - "mac"
  - "mcp-tool"
---
[x] 우다다: 1.0 출시, 1.1·Mac 제출 직전까지 채움

## 변경 요약
사용자(11-16): "1.0을 지금 출시하고 1.1을 업데이트로 제출, 네가 mac플랫폼추가해". App Store Connect 를 Chrome 으로 열어 했다.

- **iOS 1.0 출시**: '이 버전 출시' → 대한민국. 상태가 '개발자 출시 대기 중' → '배포 준비됨'.
- **iOS 1.1 버전 생성**: 빌드 2, '이 버전에서 업그레이드된 사항' 문구(내가 씀) 입력, 저장. 출시 방식은 수동(1.0 값 그대로).
- **macOS 플랫폼 추가**: 버전 1.1, 빌드 1.1 (2), 스크린샷 2장(하루 화면 · 넘어온 일 카드, 2880×1800), 설명(`mac-ko/description.txt`, 내가 씀), 키워드('위젯'을 '메뉴막대'로), 지원 URL·저작권·연락처·심사 메모는 iOS 값. 저장.
- 확인용 실행 인자 `-udWindow 1440x900`(스토어 스크린샷 규격) 추가.

## 검증
- App Store Connect 화면에서 읽은 상태: iOS `1.1 제출 준비 중 · 1.0 배포 준비됨`, macOS `1.1 제출 준비 중`, Mac `10개 중 2개의 앱 스크린샷`, 두 버전 모두 '심사에 추가' 버튼이 켜짐.
- 입력 값은 페이지에서 다시 읽어 확인(keywords · supportUrl · versionString 1.1 · copyright). 처음에 지원 URL·저작권을 덧붙여 두 번 들어간 것을 고쳤다.
- **아직 안 한 것: '심사에 추가'(제출)는 두 플랫폼 모두 누르지 않았다** — 내가 쓴 공개 문구와 스크린샷을 사용자가 보고 정하게.
- 스크린샷을 찍다 발견: 엄한 기준의 뜻으로 찾기가 예시 하루에서 "병원 가는 거 뭐 있어" → 치과를 못 찾는다(앞 기준에서는 찾았다). 찾기·쏟아내기 장면은 화면이 꺼져 있어 창을 합쳐 찍지 못했다.
- Mac 심사 메모는 iOS 것 그대로라 위젯·잠금 화면 설명이 섞여 있다.