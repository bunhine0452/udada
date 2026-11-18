# 우다다 v5 — App Store 제출 꾸러미 (한국어)

버전 0.5.0 · 번들 ID `io.github.bunhine0452.udada` · iPhone 전용 · 무료(인앱 결제·광고 없음)

이 폴더만 보고 App Store Connect(ASC)를 채울 수 있게 정리했다. 글은 `metadata/`에 칸마다 파일 하나씩
(fastlane `deliver` 폴더 구조와 같다 — 나중에 자동 업로드해도 된다), 스크린샷은 `screenshots/`에 있다.

## 1. 한눈에

| 칸 | 값 | 길이 / 한도 |
|---|---|---|
| 이름 | 우다다: 할 일·일정 플래너 | 15 / 30자 |
| 부제 | 생각 정리부터 하루 계획까지 한 장에 | 20 / 30자 |
| 키워드 | `투두,할일,리스트,캘린더,달력,위젯,관리,걱정,집중,스케줄,AI,ADHD,루틴,휴식` | 100 / 100바이트 |
| 프로모션 텍스트 | `metadata/ko/promotional_text.txt` | 119 / 170자 |
| 설명 | `metadata/ko/description.txt` | 약 2,380 / 4,000자 |
| 이번 버전 새 기능 | `metadata/ko/release_notes.txt` | 첫 공개 버전이면 ASC가 이 칸을 받지 않는다 |
| 기본 카테고리 | 생산성 (Productivity) | |
| 보조 카테고리 | 라이프스타일 (Lifestyle) | |
| 연령 등급 | 9+ (아래 5절 답대로) | |
| 앱 개인정보 | 데이터를 수집하지 않음 (Data Not Collected) | |
| 심사 메모 | `metadata/review_information/notes.txt` (영어) | |
| 영어(나중에) | `metadata/en-US/` — 이름 Udada: Day Planner & To-Do · 부제 Brain dump to a one-page day | 26자 · 28자 |

키워드 칸은 **100바이트**다(Apple 도움말 원문 "up to 100 bytes"). 한글은 글자당 3바이트라 30자 남짓밖에
못 넣는다. 위 값은 정확히 100바이트이니 한 글자라도 더하면 넘친다.

## 2. 이름 · 부제 · 키워드를 이렇게 고른 이유

**이름 — 우다다: 할 일·일정 플래너.** 「우다다」 단독은 이미 다른 앱이 써서 ASC에 지금 「우다다: 뇌 리프레시」로
잡혀 있다(2026-11-05 TestFlight 일지). 검색에서 가장 무게가 큰 칸이 이름이라, 한국 사용자가 가장 많이 치는
범주어 셋(할 일 · 일정 · 플래너)을 넣고 브랜드를 앞에 뒀다. 「하루 한 장」은 부제와 스크린샷 1번이 맡는다.
경쟁 앱도 이름 칸을 범주어로 쓴다(투두메이트 「할 일, 루틴」, Structured 「데일리 플래너」, TickTick 「할일 목록/스케줄 플래너/미리알림/달력」).

**부제 — 생각 정리부터 하루 계획까지 한 장에.** 다른 플래너와 갈리는 지점(머릿속을 비우는 「비우기」 + 하루 한 장)을
한 문장으로 말하고, 이름에 없는 검색어(생각 정리 · 하루 · 계획)를 담았다. 「AI」는 부제에 넣지 않았다 —
기기 안 AI는 Apple Intelligence 지원 기기(iOS 26+)에서만 돌고 나머지는 규칙으로 같은 흐름이 돌기 때문에,
모든 사용자에게 AI라고 약속하면 과장이 된다. 대안(더 공격적): `쏟아내면 AI가 정리하는 하루 한 장` (19자).

**키워드.** 이름·부제에 이미 있는 낱말(할 일, 일정, 플래너, 생각, 정리, 하루, 계획)은 빼고, Apple이 칸을 넘어
낱말을 조합해 찾는 점을 이용했다 — `관리`(→ 일정 관리·할 일 관리), `리스트`(→ 투두 리스트·할 일 리스트).
- 큰 검색어: 투두, 할일(띄어 쓰지 않고 치는 경우), 캘린더, 달력, 스케줄, 루틴(반복 일정)
- 우다다만의 기능: 걱정(걱정 상자), 휴식(식히기), 집중, 위젯, AI(기기 안 AI)
- 뺀 것: 메모·습관·다이어리 — 찾는 양은 크지만 메모 앱·연속 기록형 습관 앱·꾸미기 다이어리를 찾는 사람이라 들어와도 맞지 않는다(전환이 낮으면 순위에도 불리)
- `ADHD`: 경쟁 앱 마이루틴이 이름에 「ADHD 하루 계획표」를 쓸 만큼 실제로 찾는 말이다. 우다다는 쏟아내기·지금 줄
  (약속까지 실제 남은 분)·연속 기록 없음처럼 주의가 흩어지는 사람에게 맞춘 설계라 관련은 있지만, **치료·개선 효과를
  말하지 않도록 보이는 글(이름·부제·설명·스크린샷)에는 쓰지 않았다.** 불편하면 `ADHD`를 빼도 된다 —
  다만 빈 5바이트로는 한글 두 글자(쉼표 포함 7바이트)가 안 들어가니 그대로 비워 두면 된다.
- 주의: Apple 도움말은 키워드를 "각 2자 초과"로 적는다. 한국어 두 글자 낱말(투두·달력·위젯…)은 실제로 널리
  쓰이지만, 제출 화면에서 막히면 `할일`→`할일목록`처럼 늘이기보다 빼는 쪽을 권한다.
- 검색량 숫자는 공개 자료에서 찾지 못했다. **제출 전에 Apple Search Ads(무료 계정) → 키워드 추천의 "검색 인기도"로
  위 14개와 후보(메모, 습관, 다이어리, 타이머, 시간표, 브레인덤프, 숏폼)를 한국 기준으로 비교해 1~2개를 바꾸길 권한다.**

## 3. 경쟁 앱 메모 (2025–2026)

apps.apple.com은 이 환경에서 직접 열리지 않아 검색 결과에 실린 제목·부제를 옮겼다. 제출 전 스토어에서 다시 볼 것.

| 앱 | 한국 스토어 제목(부제) | 자리 |
|---|---|---|
| 투두메이트 | 투두메이트: 할 일, 루틴 (시기에 따라 「할 일, AI」) | 국내 대표 할 일 앱, 리뷰 약 11만·4.8, 생산성 40위권(검색 시점) |
| 마이루틴 | 마이루틴: 루틴 습관 투두 플래너・ADHD 하루 계획표 (2026-07 갱신) | 루틴·습관, ADHD를 이름에 씀 |
| Structured | Structured - 데일리 플래너 | 하루 타임라인, 4.9(5.2천) · 2026 Halder 논문의 데이터 출처 앱 |
| TickTick | TickTick:할일 목록/스케줄 플래너/미리알림/달력 | 범용 할 일·달력 |
| TimeBlocks | TimeBlocks - Mobile Planner (타임블럭스) | 달력+할 일, 국내 연동(네이버 캘린더) |
| Tiimo | Tiimo (한국 스토어 주소에 「ADHD 개선 비주얼 루틴 투두 스케줄 앱」) | 2025 iPhone 올해의 앱, AI 비주얼 플래너 |
| TodoTick · Myday · Y-Pod | 「To Do 리스트 스케줄 플래너 달력」 · 「투두리스트, 할 일, 미리알림, 시간관리」 · 「AI 일정 플래너」 | 키워드형 이름 |

읽은 것: 한국 생산성 인기 차트 위쪽은 ChatGPT·Gemini·Claude 같은 AI 앱이 차지하고, 플래너는 키워드형 이름과
「AI」·「루틴」·「ADHD」 같은 말로 경쟁한다. 우다다가 비어 있는 자리는 **"더 많이 해치우기"가 아니라 "머리를
조용하게"** — 생각 정리 + 하루 한 장 + 다그치지 않음 + 기기 안에만. 이름은 찾히게, 스크린샷과 부제는 이 차이를 말하게 했다.

## 4. 카테고리

- **기본: 생산성.** 매일 하는 일은 할 일·약속을 하루에 놓는 것이다. 사용자가 플래너를 찾는 곳이고, 카테고리 차트는 기본 카테고리로 매겨진다(보조 카테고리가 차트에 잡히는지는 자료마다 말이 달라 기대하지 않는다).
- **보조: 라이프스타일.** 식히기·걱정 상자·하루 닫기의 차분한 쪽을 받쳐 준다. 「건강 및 피트니스」는 건강 효과를 기대하게 만들고
  의료성 문구 심사(지침 1.4.1)를 부를 수 있으며 HealthKit도 쓰지 않아서 고르지 않았다.

## 5. 연령 등급 답 (2025년 개정 설문)

| 항목 | 답 | 이유 |
|---|---|---|
| 자녀 보호 기능 · 나이 확인 | 아니요 | 없음 |
| 제한 없는 웹 접근 | 아니요 | 앱 안 브라우저 없음 |
| 사용자 생성 콘텐츠 · 메시지·채팅 · 소셜 미디어 · 광고 | 아니요 | 내 글은 기기 안에만, 남에게 퍼지지 않음 |
| 욕설 · 공포 · 술·담배·약물 | 없음 | |
| 의료 또는 치료 정보 | 없음 | 진단·치료 안내를 하지 않음. 위기 상담 전화번호(109·1577-0199)는 안전 안내일 뿐 |
| **건강 또는 웰니스 주제** | **예** | 식히기(1분 숨 고르기·10분 걷기)와 걱정 시간은 Apple 정의의 "자기 돌봄 권장"에 해당한다 → **9+** |
| 성적 내용 · 폭력 · 무기 | 없음 | |
| 도박 · 모의 도박 · 경품 · 랜덤 박스 | 없음 | 점수·순위 경쟁 없음 |

결과 9+. "건강 또는 웰니스 주제"를 아니요로 하면 4+가 되지만, 숨 고르기 안내가 있으니 예가 정직하다.

## 6. 앱 개인정보(App Privacy) 답

**데이터를 수집하지 않음.** Apple의 정의에서 "수집"은 데이터를 기기 밖으로 보내 개발자나 제3자가 실시간 처리보다 오래
볼 수 있게 하는 것이고, "기기 안에서만 처리하는 데이터는 수집이 아니다"(App Privacy Details). 코드로 확인한 사실:

- 개발자 서버로 가는 네트워크 호출 없음(`URLSession`·웹뷰·분석·광고 SDK 없음), 계정 없음, 추적 없음. **2026-11-15부터 iCloud 맞추기**: 사용자의 개인 CloudKit DB에만 저장 — 개발자가 볼 수 없으므로 Apple 정의의 "수집"이 아니다(답은 그대로 "수집하지 않음") — `PrivacyInfo.xcprivacy`도 수집 항목 0, 추적 false.
- 저장: 앱 그룹 컨테이너의 JSON 파일 하나(위젯과 공유). 기기 백업에 들어갈 수는 있다(Apple 백업).
- 기기 안 AI: Foundation Models — 기기 안 처리. 위기 낱말이 든 글은 모델에도 보내지 않는다.
- 달력: `requestFullAccessToEvents` 후 `events(matching:)`로 **읽기만**. 저장·삭제 호출 없음.
- 말: iOS 26+ SpeechAnalyzer(기기 안 모델). 모델이 없거나 이전 iOS면 SFSpeechRecognizer — 기기 안 인식이 안 되면
  **Apple 서버 인식**을 쓰고 화면에 "애플 서버에서 글자로 바꿔"라고 알린다. 개발자에게 오는 데이터는 없어 "수집 안 함"이
  맞지만, 처리방침과 설명에는 이 사실을 그대로 적었다.
- 카메라·사진: Vision 기기 안 글자 인식, 사진 보관하지 않음. 사진은 PhotosPicker로 고른 것만 읽는다(보관함 권한 없음).
- 처리방침 원문: `privacy.md` (한국어 + 영어). **ASC는 처리방침 URL을 반드시 요구한다** — 아래 체크리스트 참고.

## 7. 스크린샷

| # | 파일 | 머리말 / 설명 | 화면 |
|---|---|---|---|
| 1 | `01-today.png` | 하루를 세 칸에, / 지금 할 일 하나 | 오늘 — 14:20, 지금 줄 「치과까지 40분 · '메일 답장' 15분」 |
| 2 | `02-add.png` | 한 줄로 적으면 / 제자리에 | "내일 3시 치과" 입력 → 미리보기 「내일 15:00 약속 · 1시간」 |
| 3 | `03-dump.png` | 머릿속을 쏟아내면 / 알아서 나눠요 | 비우기 6/7장 「다음 달 월세 오르면 어떡하지」 → 제안 「걱정 시간」, 네 칸 |
| 4 | `04-rest.png` | 머리가 뜨거우면 / 1분만 | 식히기 고르기(1분·3분·10분, 연구 출처 표시) |
| 5 | `05-close.png` | 남은 일엔 자리만, / 오늘은 여기까지 | 하루 닫기 끝 — 「오늘 끝 11.12」 도장 |
| 6 | `06-widgets.png` | 앱을 열지 않아도 / 오늘이 보여요 | 위젯(중간·작게), 잠금 화면 실시간 현황(집중·식히기), Siri 문장 |
| 7 | `07-records.png` | 점수 대신 / 사실만 | 기록 — 이번 주 한 줄, 끝낸 일·비율(견줄 거리 49.5%), 띠별 |
| 8 | `08-evidence.png` | 연구를 읽고 / 만든 하루 | 설정 → 근거 보기 |

- 폴더: `screenshots/ko/iphone-6.9/`(1320×2868, 아이폰 17 Pro Max 등) · `screenshots/ko/iphone-6.5/`(1284×2778) ·
  `screenshots/ko/iphone-6.3/`(1206×2622). 한눈에 보기: `screenshots/preview.png`.
- **크기 주의:** Apple 스크린샷 규격 페이지(2026)는 iPhone에서 "Dynamic Island 중간 화면(6.3", 1206×2622 또는
  1179×2556) 1장 이상"을 필수로 적고, 큰 화면(6.9")이 없으면 6.5"를 요구한다. 그래서 세 크기를 모두 만들었다.
  6.9"와 6.3"를 올리면 충분하다.
- 만든 방법(정직성): 모든 앱 화면은 실제 빌드를 시뮬레이터에서 띄워 찍었다. 데이터는 앱의 저장 파일 형식 그대로 만든
  "써 본 사람"의 하루(`-udNow 2026-11-12T14:20/21:40`)이고, 상태 막대 시각을 앱 안 시각과 맞췄다(14:20 · 21:40).
  6번 위젯은 위젯 확장의 **뷰 코드를 그대로** 작은 렌더러 앱에서 같은 데이터·같은 시각으로 그린 것이며, 홈 화면·잠금 화면 같은
  시스템 화면은 흉내 내지 않고 종이 위 카드와 설명 글로만 보였다. Siri 문장은 실제 App Shortcuts 문구를 글자로 옮겼다.
- 디자인: 종이 바탕(앱 바탕보다 한 톤 깊은 #E7EBE4 — 앱의 "그림자 대신 톤 차이" 규칙), 먹 #19221F, 코발트 꼬리표 하나,
  머리말 고운바탕 Bold, 설명 Apple SD 산돌고딕 Neo. 그라데이션·그림자·빛·기기 틀·이모지 없음.

### 1.2 스크린샷 (2026-11-18)

- iPhone 9장은 `screenshots/v1.2/ko/`(세 크기) · 한눈에 보기 `screenshots/v1.2/preview.png`. ASC 에는 6.3" 9장을 올렸다.
  순서: 오늘 · 한 줄 나눠 넣기 · Siri(앱 안 사용법 장면) · Apple Intelligence 판 · 식히기 · 하루 닫기 · 위젯 · 기록 · 근거.
- 디자인을 바꿨다: 큰 명조 머리말, 평평한 먹색 기기 테, 바탕 세 색(종이·코발트·먹), 화면은 크게 아래로 넘치게. 그라데이션·그림자는 여전히 없다.
- Mac 4장은 `screenshots/mac/1-day · 2-dump · 3-find · 4-siri` (`tools/compose_mac.py`). **아직 ASC 에 안 올렸다** — Mac 1.1 이 심사 중이라.
- 1.1 때 스크린샷(`screenshots/ko/` · `mac/4-stuck.png` · 옛 `preview.png`)은 지웠다. ASC 자산 보관함에는 남아 있다.
- 합성만 다시 하려면 `RAW=<폴더> tools/capture.sh` 로 날것을 남긴 뒤 `compose.py shots.json <폴더>/shots <폴더>/widgets screenshots/v1.2`.

### 다시 찍기 (UI가 바뀌면)

다른 엔지니어들이 화면을 계속 고치고 있어 스크린샷은 금방 낡는다. 제출 직전에 한 번 더 돌릴 것:

```
udada/appstore/tools/capture.sh      # 약 15분, 끝나면 시뮬레이터·빌드 파일을 스스로 지운다
```

시뮬레이터를 새로 만들어(한국어·한글 키보드·24시간제) 최신 코드로 빌드 → `gen_data.py`의 데이터로 오늘·식히기·기록을
찍고 → `runner/Shots.swift`(UI 테스트)로 한 줄 넣기·비우기·하루 닫기·근거 보기를 누르고 → `gallery/GalleryApp.swift`가
위젯 확장의 뷰 파일을 그대로 컴파일해 그리는데, 위젯 카운트다운이 실제 시계를 쓰므로 `faketime.c`로 그 프로세스의 시계만
2026-11-12 14:20으로 옮긴다 → `compose.py`가 `shots.json`(머리말·설명·화면 짝)대로 세 크기를 합성한다.
머리말을 바꾸려면 `shots.json`만 고치면 된다.

## 8. App Store Connect에서 할 일

- [ ] **처리방침 URL 만들기(필수).** `privacy.md`를 공개 페이지로 올린다. 번들 접두사가 `io.github.bunhine0452`이니
      GitHub Pages(예: `https://bunhine0452.github.io/udada/privacy`)가 가장 쉽다. 시행일·연락 이메일 칸을 채울 것.
- [ ] **지원 URL(필수)** — 연락처(이메일)가 보이는 페이지. 처리방침 페이지에 연락처 절을 둬도 된다.
- [ ] 앱 정보 → 이름을 「우다다: 뇌 리프레시」에서 `metadata/ko/name.txt`로 바꾸기, 부제 넣기, 카테고리 생산성/라이프스타일.
- [ ] 0.5.0 버전 → 프로모션 텍스트 · 설명 · 키워드(100바이트) · 지원 URL · (선택) 마케팅 URL · 저작권(`2026 이름`).
      이번 버전 새 기능은 첫 공개 버전이면 칸이 없다.
- [ ] 스크린샷: 6.9"에 `screenshots/ko/iphone-6.9/` 10장, 6.3"에 `screenshots/ko/iphone-6.3/` 10장(필요하면 6.5"도). 순서 01→10.
- [ ] 연령 등급 설문: 5절 표대로(결과 9+).
- [ ] 앱 개인정보: "데이터를 수집하지 않음" 선택 → 처리방침 URL → 게시.
- [ ] 앱 심사 정보: 로그인 필요 없음, 연락처, 메모에 `metadata/review_information/notes.txt` 붙여 넣기.
- [ ] 빌드 선택(0.5.0) · 수출 규정: 암호화 사용 안 함(Info.plist `ITSAppUsesNonExemptEncryption = NO`라 묻지 않는다).
- [ ] 가격 무료 · 판매 국가(한국 우선). UI가 한국어뿐이라 영어 메타데이터(`metadata/en-US/`)는 앱을 영어로 옮긴 뒤에 켤 것.
- [ ] 1위를 노린다면: ASC **추천(Featuring) 신청**(앱 → 추천 → 신청 — 출시 몇 주 전에. Apple 지능·App Intents·
      실시간 현황·제어 센터·인터랙티브 위젯을 다 쓰는 점, 근거 기반·개인정보 무수집을 이야기로), 출시 뒤
      **제품 페이지 최적화**로 1번 스크린샷 두세 가지 시험(예: 「하루를 세 칸에」 vs 「머릿속을 쏟아내면」), 15~30초 앱 미리보기 영상.

## 9. 출처

- Apple, App Store Connect 도움말 — [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) (키워드 100바이트·각 2자 초과·앱 이름/회사명 중복 금지, 프로모션 170자, 설명 4,000자, 새 기능 첫 버전 없음)
- Apple — [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) (이름·부제 30자)
- Apple — [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) (필수 크기, 최대 10장, 알파 채널 금지)
- Apple — [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) · [Updated age ratings (2025)](https://developer.apple.com/news/?id=ks775ehf)
- Apple — [App privacy details](https://developer.apple.com/app-store/app-privacy-details/) ("기기 안에서만 처리하는 데이터는 수집이 아니다")
- Apple — [App Review Guidelines 2.3 정확한 메타데이터](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata) (상표·다른 앱 이름·무관한 말 넣기 금지)
- 경쟁 앱 제목: 검색 결과의 App Store 페이지 — [투두메이트](https://apps.apple.com/KR/app/id1505220130), [마이루틴(appfollow)](https://apps.appfollow.io/ios/mairutin-rutin-seubgwan-tudu-peulraeneoadhd-haru-gyehoegpyo/1518956326?country=kr), [Structured](https://apps.apple.com/kr/app/structured-%EB%8D%B0%EC%9D%BC%EB%A6%AC-%ED%94%8C%EB%9E%98%EB%84%88/id1499198946), [TickTick](https://apps.apple.com/KR/app/id626144601), [TimeBlocks](https://apps.apple.com/KR/app/id821381018), [TodoTick](https://apps.apple.com/kr/app/to-do-%EB%A6%AC%EC%8A%A4%ED%8A%B8-%EC%8A%A4%EC%BC%80%EC%A4%84-%ED%94%8C%EB%9E%98%EB%84%88-%EB%8B%AC%EB%A0%A5-todotick/id6711333539), [Myday](https://apps.apple.com/kr/app/%ED%88%AC%EB%91%90%EB%A6%AC%EC%8A%A4%ED%8A%B8-%ED%95%A0-%EC%9D%BC-%EB%AF%B8%EB%A6%AC%EC%95%8C%EB%A6%BC-%EC%8B%9C%EA%B0%84%EA%B4%80%EB%A6%AC-myday/id1631348027), [Y-Pod](https://apps.apple.com/kr/app/y-pod-ai-%EC%9D%BC%EC%A0%95-%ED%94%8C%EB%9E%98%EB%84%88/id6451288906), [한국 생산성 차트](https://apps.apple.com/kr/iphone/charts/6007?chart=top-free)
- Tiimo 2025 올해의 iPhone 앱 — [Daring Fireball](https://daringfireball.net/2025/12/2025_app_store_award_winners)
- 설명의 연구 문장은 `udada/design/DAY.md` · `VALUE.md`와 앱 안 「근거 보기」에 맞췄다. Halder 2026은 심사 전 관찰 연구라 "경향이 관찰됐다"로만 썼다.
