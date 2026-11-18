import XCTest
@testable import Udada

// 기기 안 AI 의 규칙 쪽 (Udada/AI/BrainFallback.swift). AI 가 꺼져 있거나 없거나 늦을 때 이 결과가 그대로 나간다.
// 모델은 기기마다 다르게 답하니 여기서는 부르지 않는다 — 모델 품질은 하네스로 본다 (udada/design/AI.md).
// 기준 시각은 2026-11-15 (일) 14:20 Asia/Seoul. 사례는 macOS 하네스와 같다.

final class BrainTests: XCTestCase {

    // MARK: 말 받아쓰기 자르기

    func testSplitsSpeechWithoutNewlines() {
        XCTAssertEqual(BrainRules.split("엄마한테 전화하고 보고서 써야 되고 월세 오르면 어떡하지"),
                       ["엄마한테 전화하기", "보고서 써야 돼", "월세 오르면 어떡하지"])
        XCTAssertEqual(BrainRules.split("음 그러니까 내일 3시에 치과 가야 되고 아 그리고 금요일까지 기획서 내야 되는데 아직 시작도 못 했어 그리고 헬스장 등록할까 말까 고민 중이고 택배 반품도 해야 돼"),
                       ["내일 3시에 치과 가야 돼", "금요일까지 기획서 내야 돼", "헬스장 등록할까 말까 고민 중이야", "택배 반품도 해야 돼"],
                       "앞 말에 붙인 푸념(아직 시작도 못 했어)은 카드로 만들지 않는다")
        // 메모 말투 · 문장 끝 · 걱정 끝말에서도 끊는다 (Eval 묶음에서 놓치던 꼴)
        XCTAssertEqual(BrainRules.split("날짜 잡기 연차 내기 검사 결과 안 좋으면 어떡하지"), ["날짜 잡기", "연차 내기", "검사 결과 안 좋으면 어떡하지"])
        XCTAssertEqual(BrainRules.split("통장 잔고가 너무 없어서 불안해 이번 달 가계부 정리해야 돼"), ["통장 잔고가 너무 없어서 불안해", "이번 달 가계부 정리해야 돼"])
        XCTAssertEqual(BrainRules.split("선풍기 넣기 전에 닦기"), ["선풍기 넣기 전에 닦기"], "'-기 전에'는 맺음이 아니다")
        XCTAssertEqual(BrainRules.split("우유 사고 빵 사고 그다음에 세탁소 들르기"), ["우유 사기", "빵 사기", "세탁소 들르기"])
        XCTAssertEqual(BrainRules.split("빨래 개고 설거지하고 쓰레기 버리기"), ["빨래 개기", "설거지하기", "쓰레기 버리기"])
        XCTAssertEqual(BrainRules.split("어제 늦게 잤고 오늘 피곤하고"), ["어제 늦게 잤어", "오늘 피곤하기"])
        XCTAssertEqual(BrainRules.split("유튜브 채널 언젠가 해 볼까 싶기도 하고 물도 좀 마셔야 되고"), ["유튜브 채널 언젠가 해 볼까 싶기도 해", "물도 좀 마셔야 돼"])
        XCTAssertEqual(BrainRules.split("엄마한테 전화하기. 보고서 쓰기! 월세 어떡하지?"), ["엄마한테 전화하기", "보고서 쓰기", "월세 어떡하지"])
    }

    func testSplitKeepsOneClauseTogether() {
        for line in ["우유하고 계란 사기", "운동하고 싶다", "커피 말고 차 마시기", "3.5시간 공부하기",
                     "팀장님이 내일까지 하라고 했는데 아직 못 했어", "공부하는데 집중이 안 돼"] {
            XCTAssertEqual(BrainRules.split(line), [line], line)
        }
        XCTAssertEqual(BrainRules.split("엄마하고 통화하고 은행 가기"), ["엄마하고 통화하기", "은행 가기"])
        XCTAssertEqual(BrainRules.split("주간 보고 올리고 팀장님한테 메일 보내기"), ["주간 보고 올리기", "팀장님한테 메일 보내기"])
        XCTAssertEqual(BrainRules.split("교통사고 처리하고 보험사에 전화하기"), ["교통사고 처리하기", "보험사에 전화하기"])
        XCTAssertEqual(BrainRules.split("메일 답장\n- 장보기\n3시 치과"), ["메일 답장", "장보기", "3시 치과"])
    }

    // MARK: 칸 고르기 (v4 Sorter + Parser)

    func testClassifier() {
        let cases: [(String, DumpBin, DayKey?, Part?)] = [
            ("월세 오르면 어떡하지", .worry, nil, nil), ("발표 망하면 어쩌지", .worry, nil, nil), ("시험 떨어질까 봐 무서워", .worry, nil, nil),
            ("헬스장 등록할까 말까", .drop, nil, nil), ("언젠가 기타 배우기", .drop, nil, nil), ("새 아이패드 사고 싶다", .drop, nil, nil),
            ("엄마한테 전화", .now, today, .afternoon), ("치과 예약", .now, today, .afternoon), ("오늘 엄마한테 전화", .now, today, .afternoon),
            ("오늘 저녁에 엄마한테 전화", .date, today, .evening), ("보고서 쓰기", .date, dk(11, 16), .morning),
            ("내일 엄마한테 전화", .date, dk(11, 16), nil), ("3시 치과", .date, today, .afternoon), ("10시 회의 자료 보내기", .date, today, .evening),
            ("나중에 책 읽기", .date, nil, nil), ("다음 달에 이사 준비", .date, dk(12, 1), .morning), ("금요일 저녁 7시 동창 모임", .date, dk(11, 20), .evening),
        ]
        for (text, bin, day, part) in cases {
            let s = BrainRules.suggest(text, today: today, now: now, calendar: seoul)
            XCTAssertEqual(s.bin, bin, text)
            XCTAssertEqual(s.day, day, text)
            XCTAssertEqual(s.part, part, text)
            XCTAssertFalse(s.fromAI, text)
            XCTAssertFalse(s.reason.isEmpty, text)
        }
    }

    func testOrganizeFallback() {
        let out = BrainRules.organize("엄마한테 전화하고 보고서 써야 되고 월세 오르면 어떡하지", today: today, now: now, calendar: seoul)
        XCTAssertEqual(out.map(\.bin), [.now, .date, .worry])
        XCTAssertEqual(out.map(\.duration), [5, 60, nil])
        XCTAssertEqual(out[1].reason, "언제 할지만 정하면 머리에서 내려가. 내일 아침 어때?")
        XCTAssertEqual(BrainRules.suggest("3시 치과", today: today, now: now, calendar: seoul).reason, "오늘 오후 3시로 둘게.")
    }

    /// AI 가 고른 '지금'도 사용자가 때를 말했으면 '날짜 정하기'
    func testReconcileKeepsUserTime() {
        let p = Parser.parse("저녁에 엄마한테 전화", now: now, calendar: seoul)
        XCTAssertEqual(BrainRules.reconcile(.now, parsed: p, today: today), .date)
        let q = Parser.parse("엄마한테 전화", now: now, calendar: seoul)
        XCTAssertEqual(BrainRules.reconcile(.now, parsed: q, today: today), .now)
    }

    // MARK: AI 카드 검사

    func testFinishDropsInventedCardsAndDates() {
        let raw = "엄마한테 전화하고 보고서 써야 되고 월세 오르면 어떡하지"
        let invented = BrainRules.finish([.init(text: "엄마한테 전화하기", bin: .now), .init(text: "병원 예약하기", bin: .now),
                                          .init(text: "보고서 쓰기", bin: .date), .init(text: "월세 오르면 어떡하지", bin: .worry)],
                                         raw: raw, today: today, now: now, calendar: seoul)
        XCTAssertEqual(invented?.map(\.text), ["엄마한테 전화하기", "보고서 쓰기", "월세 오르면 어떡하지"])
        XCTAssertEqual(invented?.allSatisfy(\.fromAI), true)
        // 모델이 한 줄만 내도 나머지 줄을 잃지 않는다: 놓친 조각은 사용자의 말 그대로 규칙 카드로 채운다
        let partial = BrainRules.finish([.init(text: "엄마한테 전화하기", bin: .now)], raw: raw, today: today, now: now, calendar: seoul)
        XCTAssertEqual(partial?.map(\.text), ["엄마한테 전화하기", "보고서 써야 돼", "월세 오르면 어떡하지"])
        XCTAssertEqual(partial?.map(\.fromAI), [true, false, false])
        XCTAssertNil(BrainRules.finish([.init(text: "병원 예약하기", bin: .now)], raw: raw, today: today, now: now, calendar: seoul),
                     "모델 카드가 하나도 입력과 안 닮았으면 규칙으로")
        let fake = BrainRules.finish([.init(text: "내일 엄마한테 전화하기", bin: .date), .init(text: "보고서 쓰기", bin: .date),
                                      .init(text: "월세 오르면 어떡하지", bin: .worry)], raw: raw, today: today, now: now, calendar: seoul)
        // 입력에 없던 '내일'은 읽지 않는다. 전화 한 통은 규칙이 '지금'으로 본다 (모델의 '날짜'보다 글에 적힌 낱말이 이긴다)
        XCTAssertEqual(fake?.first?.bin, .now)
        XCTAssertEqual(fake?.first?.day, today, "입력에 없던 '내일'은 읽지 않는다")
        let lost = BrainRules.finish([.init(text: "동생 생일 선물 사기", bin: .date), .init(text: "이사 업체 알아보기", bin: .date)],
                                     raw: "동생 생일 선물 사야 돼\n이번 주말에 이사 업체 알아봐야 돼", today: today, now: now, calendar: seoul)
        XCTAssertEqual(lost?[1].text, "이번 주말에 이사 업체 알아봐야 돼", "AI 가 빠뜨린 사용자의 때는 원래 조각으로")
        let real = BrainRules.finish([.init(text: "내일 3시 치과 가기", bin: .date)], raw: "음 내일 3시에 치과 가야 돼", today: today, now: now, calendar: seoul)
        XCTAssertEqual(real?.first?.day, dk(11, 16))
        XCTAssertEqual(real?.first?.reason, "내일 오후 3시로 둘게.")
    }

    // MARK: 첫 동작

    func testFirstStepTemplates() {
        let cases = [("보고서 초안", "문서 열고 제목만 쓰기"), ("엄마한테 전화", "연락처 열고 이름 찾아 두기"), ("치과 예약", "예약 화면 열어 두기"),
                     ("빨래 개기", "옷 한 벌만 개기"), ("운동", "운동화 꺼내 신기"), ("택배 보내기", "보낼 물건 문 앞에 두기"),
                     ("발표 준비", "슬라이드 열고 첫 장 제목 쓰기"), ("여권 갱신", "필요한 것 하나 꺼내 두기")]
        for (title, step) in cases {
            XCTAssertEqual(BrainRules.firstStep(for: title), step, title)
            XCTAssertLessThanOrEqual(step.count, 25, title)
        }
        XCTAssertEqual(BrainRules.firstStep(for: "세금 신고"), "홈택스 열어 두기")
        XCTAssertNil(BrainRules.knownStep(for: "여권 갱신"), "모르는 일만 AI 가 맡는다")
        let narrow: [(String, String?)] = [("책상 정리", "눈앞의 물건 하나 제자리에 두기"), ("통장 정리", "은행 앱 열기"), ("회의록 정리", "문서 열고 제목만 쓰기"),
                                           ("빌린 책 돌려주기", nil), ("이사 업체 알아보기", nil), ("고양이 사료 주문", nil), ("중고 거래 글 올리기", nil)]
        for (title, step) in narrow { XCTAssertEqual(BrainRules.knownStep(for: title), step, "갈래 낱말은 좁게: \(title)") }
        XCTAssertEqual(BrainRules.cleanStep("첫 동작: 문서 열고 제목만 쓰기.", title: "보고서"), "문서 열고 제목만 쓰기")
        XCTAssertNil(BrainRules.cleanStep("Open the document and write a title", title: "보고서"))
        XCTAssertNil(BrainRules.cleanStep("여권 갱신하기", title: "여권 갱신"), "할 일을 되풀이한 것은 첫 동작이 아니다")
        XCTAssertEqual(BrainRules.cleanStep("여권 꺼내 두기", title: "여권 갱신"), "여권 꺼내 두기")
    }

    // MARK: 하루 열기 — 진짜 DayLogic.sheet

    func testBriefFromRealSheet() {
        let sheet = DayLogic.sheet(for: today, data: seed(), now: now, calendar: seoul)
        let brief = BrainRules.brief(sheet, laterCount: 2, worryCount: 1)
        XCTAssertEqual(brief, "다음은 오후 3시 ‘치과’, 남은 할 일은 3개야. 지금은 ‘보고서 초안’ 30분이 딱 들어가.")

        XCTAssertEqual(BrainRules.brief(DayLogic.sheet(for: today, data: AppData(), now: now, calendar: seoul), laterCount: 0, worryCount: 0),
                       "오늘은 비어 있어. 쉬어도 되는 날이야.")
        var busy = seed()
        busy.items.append(Item(title: "기획서", day: today, part: .afternoon, duration: 180, created: now.addingTimeInterval(9)))
        let over = BrainRules.brief(DayLogic.sheet(for: today, data: busy, now: now, calendar: seoul), laterCount: 0, worryCount: 0)
        XCTAssertTrue(over.hasSuffix("낮이 1시간 5분 넘치니 하나는 미뤄도 돼."), over)
    }

    // MARK: 닫기 · 한 주

    func testClosingAndWeeklyTemplates() {
        XCTAssertEqual(BrainRules.closing(done: 3, moved: 2, dropped: 1, tomorrowFirst: "보고서 초안"),
                       "오늘 3개 끝냈어. 남은 2개는 자리를 정했고 1개는 내려놨어. 내일은 ‘보고서 초안’부터 하면 돼.")
        XCTAssertEqual(BrainRules.closing(done: 0, moved: 0, dropped: 0, tomorrowFirst: nil), "끝낸 게 없어도 괜찮은 날이야. 이제 머리는 쉬어도 돼.")
        let week = WeekStats(done: 12, added: 20, closedDays: 2, rests: 0, clarityDelta: nil, noiseDelta: -2.25, estimateRatio: 1.4, bestPart: .morning)
        XCTAssertEqual(BrainRules.weekly(week), "이번 주 20개를 적고 12개를 끝냈어. 비우고 나면 머리 소음이 평균 2.3만큼 내려갔어. 다음 주엔 길이를 조금 넉넉히 잡아 봐.")
    }

    // MARK: 걱정 · 위기

    func testCrisisDetection() {
        for text in ["죽고 싶다", "그냥 사라지고 싶어", "자해하고 싶은 생각이 들어", "살기 싫다 진짜"] {
            let w = BrainRules.worry(text)
            XCTAssertTrue(w.crisis, text)
            XCTAssertTrue(w.line.contains("109") && w.line.contains("1577-0199"), text)
            XCTAssertNil(w.step, text)
        }
        for text in ["피곤해 죽겠다", "배고파 죽을 것 같아", "보고서 끝내고 싶다", "일 끝내고 싶어"] {
            XCTAssertFalse(BrainRules.isCrisis(text), text)
        }
        let dump = BrainRules.organize("보고서 쓰고 그냥 죽고 싶다", today: today, now: now, calendar: seoul)
        XCTAssertEqual(dump.last?.bin, .worry)
        XCTAssertEqual(dump.last?.reason, BrainRules.crisisLine)
    }

    /// 위기 글은 AI 를 부르기 전에 걸러진다 — 꺼져 있든 켜져 있든 같은 답
    @MainActor
    func testBrainCrisisNeverReachesModel() async {
        let w = await Brain.shared.worry("요즘 그냥 죽고 싶어")
        XCTAssertTrue(w.crisis)
        XCTAssertEqual(w.line, BrainRules.crisisLine)
        let step = await Brain.shared.firstStep(for: "죽고 싶다")
        XCTAssertNil(step)
    }

    func testWorryFallbackAndAdviceFilter() {
        let inHands = BrainRules.worry("다음 주 발표 망하면 어떡하지")
        XCTAssertTrue(inHands.inMyHands)
        XCTAssertEqual(inHands.step, "슬라이드 열고 첫 장 제목 쓰기")
        let wait = BrainRules.worry("월세 오르면 어떡하지")
        XCTAssertFalse(wait.inMyHands)
        XCTAssertNil(wait.step)
        let advice = BrainRules.finishWorry(inMyHands: true, step: "주식 팔기")
        XCTAssertNil(advice.step, "투자 조언은 뺀다")
        XCTAssertEqual(advice.line, BrainRules.waitLine)
        let ok = BrainRules.finishWorry(inMyHands: true, step: "계약서에서 만료일 확인하기")
        XCTAssertEqual(ok.step, "계약서에서 만료일 확인하기")
        XCTAssertEqual(ok.line, BrainRules.inHandsLine)
        XCTAssertNil(BrainRules.finishWorry(inMyHands: true, step: "팀장님에게 긍정적인 말 한 가지 하기").step, "남의 마음 바꾸기 조언은 뺀다")
    }

    // MARK: 한 줄 읽기 도우미

    func testAssistParseRules() {
        let cases: [(String, DayKey?, Int?, Part?, String)] = [
            ("크리스마스에 파티 준비", dk(12, 25), nil, nil, "파티 준비"),
            ("퇴근하고 헬스장", nil, nil, .evening, "헬스장"),
            ("내일 세 시 치과", dk(11, 16), 900, nil, "치과"),
            ("추석에 할머니 댁", DayKey(y: 2027, m: 9, d: 15), nil, nil, "할머니 댁"),
            ("설날에 세배", DayKey(y: 2027, m: 2, d: 6), nil, nil, "세배"),
            ("다음 달 둘째 주 화요일 회의", dk(12, 8), nil, nil, "회의"),
            ("열흘 뒤 치과", dk(11, 25), nil, nil, "치과"),
            ("월말까지 정산", dk(11, 30), nil, nil, "정산"),
            ("다음 달 셋째 주에 이사", dk(12, 15), nil, nil, "이사"),
            ("이번 주 금요일 세 시 미팅", dk(11, 20), 900, nil, "미팅"),
            ("다음 달 15일 치과", dk(12, 15), nil, nil, "치과"),
        ]
        for (text, day, time, part, title) in cases {
            let p = BrainRules.assistParse(text, now: now, calendar: seoul)
            XCTAssertNotNil(p, text)
            XCTAssertEqual(p?.day, day, text)
            XCTAssertEqual(p?.time, time, text)
            if let part { XCTAssertEqual(p?.part, part, text) }
            XCTAssertEqual(p?.title, title, text)
        }
    }

    func testAssistParseNilWhenRuleParserFoundTime() {
        for text in ["3시 치과", "내일 저녁 7시 빨래", "오후 2시 반 미팅", "보고서 쓰기", "매주 월요일 운동", "나중에 책 읽기",
                     "드라이브 가기", "연말정산 서류 내기", "이따금 운동하기"] {
            XCTAssertFalse(BrainRules.needsAssist(Parser.parse(text, now: now, calendar: seoul)), text)
            XCTAssertNil(BrainRules.assistParse(text, now: now, calendar: seoul), text)
        }
        XCTAssertNil(BrainRules.applyWhen(phrase: "다음 주 언젠가", canonical: "다음 주 수요일", to: "보고서", now: now, calendar: seoul), "입력에 없는 말")
        XCTAssertNil(BrainRules.applyWhen(phrase: "셋째 주", canonical: "곧", to: "다음 달 셋째 주 이사", now: now, calendar: seoul), "표준 꼴이 아님")
        XCTAssertEqual(BrainRules.applyWhen(phrase: "셋째 주", canonical: "12월 14일", to: "다음 달 셋째 주 이사", now: now, calendar: seoul)?.day, dk(12, 14))
    }

    /// 실제 Brain 도 Parser 가 이미 시각을 찾았으면 nil (AI 를 부르지 않는다)
    @MainActor
    func testBrainAssistParseNilWhenTimeFound() async {
        let p = await Brain.shared.assistParse("3시 치과", now: Date())
        XCTAssertNil(p)
    }

    // MARK: 공통

    private let now: Date = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 14, minute: 20))!
    }()
    private var today: DayKey { DayKey(now, calendar: seoul) }
    private let seoul: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.locale = Locale(identifier: "ko_KR")
        return c
    }()
    private func dk(_ m: Int, _ d: Int) -> DayKey { DayKey(y: 2026, m: m, d: d) }

    private func seed() -> AppData {
        var d = AppData()
        func mk(_ title: String, _ day: DayKey, _ part: Part, time: Int? = nil, dur: Int = 30, _ i: Int) -> Item {
            Item(title: title, day: day, part: part, time: time, duration: dur, created: now.addingTimeInterval(Double(i)))
        }
        d.items = [mk("메일 답장", today, .morning, dur: 15, 0), mk("팀 회의", today, .morning, time: 600, dur: 60, 1),
                   mk("보고서 초안", today, .afternoon, 2), mk("택배 보내기", today, .afternoon, dur: 15, 3),
                   mk("치과", today, .afternoon, time: 900, dur: 60, 4), mk("저녁 약속", today, .evening, time: 1170, dur: 90, 5),
                   mk("빨래 개기", today, .evening, dur: 15, 6), mk("장보기", today.adding(days: 1, calendar: seoul), .afternoon, 7)]
        return d
    }
}
