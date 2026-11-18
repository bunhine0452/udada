---
schema_version: 1
type: chore
slug: "udada-v5-app-icon"
status: done
difficulty: medium
created_at: "2026-11-15T02:12:11+09:00"
session_id: "20261115-001"
agent:
  id: "claude-code"
  version: "Opus 5.5"
  session: "7ca3e7ef-8785-40fd-99ee-078d437a406d"
language: "ko"
verified_by_user: false
files_touched:
  - path: "udada/ios/Udada/Assets.xcassets/AppIcon.appiconset/Contents.json"
    op: update
  - path: "udada/ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    op: create
  - path: "udada/ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png"
    op: create
  - path: "udada/ios/Udada/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png"
    op: create
  - path: "udada/ios/Udada/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    op: delete
  - path: "udada/design/brand/README.md"
    op: create
  - path: "udada/design/brand/icon.py"
    op: create
  - path: "udada/design/brand/icon.svg"
    op: create
related: []
tags:
  - "우다다"
  - "design"
  - "mcp-tool"
---
[x] 우다다: 새 앱 아이콘 「지금 우」

## 무엇을 했나
하위 세션(Opus 5.5)이 v5 아이콘을 새로 만들었다. 고운바탕 Bold 의 '우'에서 가로획을 곧은 코발트 '지금' 선으로 바꿨다 — 띠 이름과 같은 명조, 하루를 가로지르는 지금 줄, 앱 이름이 한 글자에. 종이 #F1F3EE · 먹 #19221F · 코발트 #2E4AE3.
- 후보 5개를 300/180/120/60px·밝은/어두운·4×4 홈 화면 격자에서 비교: 하루 한 장 축소판(60px 에서 뭉개짐·흔한 목록 앱), 세로 우다다(120px 아래 못 읽음), 붓 획 우(달력보다 서예 같음), 꽉 찬 선(글자가 깨짐), 기하 우(♀ 기호로 읽힘) → 「지금 우」.
- 다듬기: 동그라미·선·기둥을 x=512 한 축에, 선 가장자리를 60px 격자에 맞춰 작은 크기에서도 선명, 선(51.2px)은 기둥(70px)보다 가늘게, 무거운 동그라미 때문에 8px 아래로.
- iOS 18+ 모양 3가지: 기본(알파 없음), 다크(투명 바탕 · #E6EDE9 · #8399FF), 틴트(회색조, 선만 흰색이라 틴트 후에도 강조 하나).
- `udada/design/brand/`: README(콘셉트·비교·치수·색 대비·하지 말 것), `icon.py`(다시 만들면 바이트까지 같음), `icon.svg`, 홈 화면 미리보기들. 옛 기계 아이콘은 지움.

## 검증
- `xcrun actool udada/ios/Udada/Assets.xcassets --compile … --app-icon AppIcon` → exit 0, 경고 없음. Assets.car 에 기본(ARGB)·다크(UIAppearanceDark)·틴트(ISAppearanceTintable, Gray) 1024 셋.
- `udada/design/brand/preview.png` 를 직접 보고 60px 에서도 '우'로 읽힘을 확인.