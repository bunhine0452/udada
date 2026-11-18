---
schema_version: 1
type: chore
slug: "udada-promo-without-sns"
status: done
created_at: "2026-11-18T21:40:58+09:00"
session_id: "20261118-001"
agent:
  id: "claude-code"
  session: "4ab0d695-c429-4424-8122-3908cd2f642d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/appstore/metadata/ko/subtitle.txt"
    op: update
  - path: "udada/appstore/metadata/ko/keywords.txt"
    op: update
  - path: "udada/appstore/metadata/ko/promotional_text.txt"
    op: update
  - path: "udada/appstore/metadata/ko/description.txt"
    op: update
  - path: "udada/appstore/metadata/ko/release_notes.txt"
    op: update
  - path: "udada/appstore/promo/show-gn.md"
    op: create
  - path: "udada/appstore/promo/pitch-mail.md"
    op: create
related:
  - ref: "20261115/Chores/0307_chore_udada-v5-appstore-package.md"
    kind: "followup"
tags:
  - "우다다"
  - "mcp-tool"
---
[x] 우다다: SNS 없는 홍보 글과 초안을 썼다

## 무엇을
사용자가 SNS 게시글 말고 홍보할 길을 물었고, 별점 요청은 싫다고 했다. 내세울 것은 "Apple Intelligence 가 이렇게까지 쓰인다고? 편하고 신기하다".

- App Store Connect 분석(30일): 자료는 11-16 하루뿐. 노출 25 · 제품 페이지 조회 14 · 최초 다운로드 1 · 전환율 33.3%. 나눠 볼 만큼의 수가 없다. 지금 막힌 곳은 페이지가 아니라 노출이다.
- 스토어 글(`appstore/metadata/ko`)을 1.3 용으로 다시 씀: 부제 "말로 쏟아내면 AI가 정리해 주는 하루"(21/30), 키워드 95/100(이름·부제에 있는 낱말은 뺌), 홍보 문구 125/170, 설명 첫머리를 "Apple Intelligence가 하는 일"로 바꾸고 밑에 묻혀 있던 옛 AI 절을 지움(3096/4000), 1.3 새 기능 글.
- 커뮤니티 글 초안 `appstore/promo/show-gn.md`: 광고가 아니라 "기기 안 모델을 잰 기록". 숫자는 `design/AI.md` 것만, 못 닿은 77% 도 적음.
- 제보 메일 초안 `appstore/promo/pitch-mail.md` + Gmail 임시 보관함(받는 사람 비움).
- 영어 지원은 크기를 재고 계획 `udada-english` 만 세움: Swift 84개 파일에 한글 문자열 2939개, 문자열 카탈로그 없음.

## 결정
- 부제·이름에는 Apple 상표를 넣지 않았다(심사 위험). 홍보 문구와 설명에는 "Apple Intelligence"를 맨 앞에.
- "전부 기기 안에서"라고 쓰지 않는다. 음성 인식은 기기가 못 하면 Apple 서버를 쓰고 iCloud 맞추기도 있다. "모델은 기기 안에서만"으로 적음.
- 커뮤니티 글의 "돌려 말한 것" 숫자는 고친 뒤(60→90%)가 아니라 처음 한 번 돌린 값(50→80%)을 씀.

## 검증
- 글자 수를 python3 로 셈: name 15/30 · subtitle 21/30 · keywords 95/100 · promotional_text 125/170 · description 3096/4000.
- 스토어에는 아직 아무것도 올리지 않았다. 부제·키워드·설명은 새 버전(1.3)을 낼 때만 바뀐다. 게시·발송도 하지 않았다.