import XCTest

/// 말로 찾기의 규칙 쪽: 물음 읽기, 실제 기록에서 찾기, 모델이 읽은 것 검사.
final class FinderTests: XCTestCase {
    private let today = DayKey(y: 2026, m: 11, d: 16) // 월요일
    private var data: AppData {
        var d = AppData()
        func it(_ t: String, _ day: DayKey?, time: Int? = nil, done: Bool = false, worry: Bool = false) -> Item {
            var i = Item(title: t, day: day, time: time, worry: worry); i.done = done; return i
        }
        d.items = [
            it("치과", today.adding(days: 2), time: 900),
            it("병원 정기검진", today.adding(days: 8), time: 600),
            it("병원 예약 전화", today.adding(days: -5), done: true),
            it("운동", today.adding(days: -6), done: true), it("운동", today.adding(days: -4), done: true), it("운동", today.adding(days: -3)),
            it("보고서 초안", today), it("여권 갱신", nil),
            it("월세 오르면 어떡하지", nil, worry: true),
            Item(title: "물 한 잔", day: today.adding(days: -10), repeatRule: .daily),
        ]
        return d
    }

    func testReadsQuestionByRules() {
        var q = FindRules.read("다음 주에 병원 언제야?")
        XCTAssertEqual(q.span, .nextWeek); XCTAssertEqual(q.words, ["병원"])
        q = FindRules.read("지난주에 끝낸 운동 몇 번이야")
        XCTAssertEqual(q.span, .lastWeek); XCTAssertEqual(q.state, .done); XCTAssertTrue(q.counting); XCTAssertEqual(q.words, ["운동"])
        q = FindRules.read("오늘 남은 할 일")
        XCTAssertEqual(q.span, .today); XCTAssertEqual(q.state, .open); XCTAssertEqual(q.words, [])
        q = FindRules.read("병원 언제였지")
        XCTAssertEqual(q.span, .past); XCTAssertEqual(q.words, ["병원"])
        q = FindRules.read("걱정 뭐 있어")
        XCTAssertEqual(q.kind, .worry); XCTAssertEqual(q.words, [])
        q = FindRules.read("이번 주 약속 보여 줘")
        XCTAssertEqual(q.span, .thisWeek); XCTAssertEqual(q.kind, .event); XCTAssertEqual(q.words, [])
    }

    func testAnswersComeFromRecords() {
        var a = FindRules.answer(FindRules.read("다음 주에 병원 언제야?"), data: data, today: today)
        XCTAssertEqual(a.hits.map(\.title), ["병원 정기검진"])
        XCTAssertEqual(a.line, "다음 주 · ‘병원’ — 11월 24일 (화) 10:00")
        a = FindRules.answer(FindRules.read("지난주에 끝낸 운동 몇 번이야"), data: data, today: today)
        XCTAssertEqual(a.hits.count, 2); XCTAssertEqual(a.line, "지난주 · ‘운동’ · 끝낸 것 — 2개")
        a = FindRules.answer(FindRules.read("병원 언제였지"), data: data, today: today)
        XCTAssertEqual(a.hits.map(\.title), ["병원 예약 전화"])
        a = FindRules.answer(FindRules.read("걱정 뭐 있어"), data: data, today: today)
        XCTAssertEqual(a.hits.map(\.title), ["월세 오르면 어떡하지"])
        a = FindRules.answer(FindRules.read("이번 주 약속"), data: data, today: today)
        XCTAssertEqual(a.hits.map(\.title), ["치과"])
        a = FindRules.answer(FindRules.read("수영 언제야"), data: data, today: today)
        XCTAssertTrue(a.hits.isEmpty); XCTAssertTrue(a.line.hasSuffix("찾은 게 없어"))
        // 반복은 범위 안의 날로 펼친다
        a = FindRules.answer(FindRules.read("내일 물"), data: data, today: today)
        XCTAssertEqual(a.hits.map(\.day), [today.adding(days: 1)])
    }

    /// 풀어 쓴 한글(NFD)로 와도 똑같이 읽는다 (UI 테스트에서 답이 "‘오늘 치과 시야’"로 나왔던 결함)
    func testDecomposedHangulReadsTheSame() {
        let nfd = "오늘 치과 몇 시야".decomposedStringWithCanonicalMapping
        XCTAssertNotEqual(Array(nfd.unicodeScalars).count, Array("오늘 치과 몇 시야".unicodeScalars).count)
        let q = FindRules.read(nfd)
        XCTAssertEqual(q.span, .today); XCTAssertEqual(q.kind, .event); XCTAssertEqual(q.words, ["치과"])
    }

    /// 모델이 지어낸 낱말은 버리고, 규칙이 또렷이 읽은 때는 규칙이 이긴다
    func testModelReadingIsChecked() {
        let model = FindQuery(words: ["병원", "치료", "다음 주"], span: .thisWeek, state: .any, kind: .any)
        let q = FindRules.checked(model: model, question: "다음 주에 병원 언제야?")
        XCTAssertEqual(q.words, ["병원"], "물음에 없는 '치료'와 때 낱말은 뺀다")
        XCTAssertEqual(q.span, .nextWeek)
        XCTAssertTrue(q.fromAI)
        // 규칙이 못 읽는 돌려 말한 물음은 모델의 읽기를 쓴다
        let soft = FindRules.checked(model: FindQuery(words: ["세탁소"], span: .past, state: .done, kind: .any), question: "세탁소 다녀온 게 며칠이더라")
        XCTAssertEqual(soft.words, ["세탁소"]); XCTAssertEqual(soft.span, .past); XCTAssertEqual(soft.state, .done)
    }

    // MARK: 뜻으로 찾기 (모델이 고른 이름을 규칙이 받아들이는 쪽)

    func testMeaningCandidatesAreRealRecordsWithoutLiteralHits() {
        let q = FindRules.read("병원 가는 거 뭐 있어")
        XCTAssertEqual(q.words, ["병원"])
        let c = FindRules.candidates(q, data: data, today: today)
        XCTAssertTrue(c.contains("치과"))
        XCTAssertFalse(c.contains("병원 정기검진"), "낱말로 이미 찾은 것은 후보가 아니다")
        XCTAssertEqual(c.filter { $0 == "운동" }.count, 1, "같은 이름은 한 번만")
        XCTAssertTrue(FindRules.candidates(FindRules.read("다음 주에 뭐 있어"), data: data, today: today).isEmpty, "낱말이 없으면 넓히지 않는다")
    }

    func testTrustedKeepsOnlyNamesInTheList() {
        let titles = ["치과", "운동", "보고서 초안", "여권 갱신", "물 한 잔", "장보기"]
        XCTAssertEqual(FindRules.trusted(["치과", "없는 일", " 치 과"], titles: titles), ["치과"])
        XCTAssertEqual(FindRules.trusted(["치과", "운동", "보고서 초안", "여권 갱신"], titles: titles), [], "절반 넘게 고르면 안 믿는다")
    }

    func testMeaningHitsComeAfterLiteralAndAreMarked() {
        let q = FindRules.read("병원 가는 거 뭐 있어")
        let a = FindRules.answer(q, data: data, today: today, meaning: ["치과"])
        XCTAssertEqual(a.hits.last?.title, "치과")
        XCTAssertEqual(a.hits.filter(\.byMeaning).map(\.title), ["치과"])
        XCTAssertTrue(a.hits.contains { $0.title == "병원 정기검진" && !$0.byMeaning })
        // 때는 여전히 규칙이 거른다: 다음 주 물음에 이번 주 치과는 뜻이 맞아도 안 나온다
        let next = FindRules.answer(FindRules.read("다음 주 병원"), data: data, today: today, meaning: ["치과"])
        XCTAssertFalse(next.hits.contains { $0.title == "치과" })
    }

    func testWordsKeepWholeNounsAndShortNouns() {
        XCTAssertEqual(FindRules.read("가족 일 뭐 있지").words, ["가족"])
        XCTAssertEqual(FindRules.read("거래처 미팅 언제야").words.first, "거래처")
        XCTAssertEqual(FindRules.read("돈 나가는 일").words.first, "돈")
        var d = AppData()
        d.items = [Item(title: "자동차 점검", day: today), Item(title: "차 빼기", day: today)]
        XCTAssertEqual(FindRules.answer(FindRules.read("차 관련"), data: d, today: today).hits.map(\.title), ["차 빼기"])
    }
}
