import Foundation

// 쪼개기: "금요일까지 발표 준비" 같은 큰일 하나를 3~5 걸음으로 나누고, 마감 전 날들에 놓는다.
// 다른 AI 기능과 같은 짜임이다 (design/AI.md):
//  · 걸음의 글은 모델(Apple Intelligence)이 쓰고, 검사는 규칙이 한다. 못 넘으면 다듬어 둔 걸음이 나간다.
//  · 날짜는 모델이 정하지 않는다 — 규칙이 오늘부터 마감 전날까지 고르게 놓는다. 마감을 넘기는 걸음은 없다.
//  · 바로 넣지 않는다: 미리 보여 주고, 사용자가 켜고 끈 뒤 눌러야 한 번에 들어간다 (되돌리기 한 번).
//  · 큰일 자체는 건드리지 않는다. 마감 날에 그대로 남아 끝을 표시한다.

/// 큰일 하나를 나눈 결과 (아직 날에 놓기 전)
struct Breakdown: Equatable, Sendable {
    /// 날짜 낱말을 뺀 큰일의 이름
    var subject: String
    var steps: [String]
    var fromAI: Bool
}

/// 날에 놓인 걸음 하나
struct BreakStep: Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var day: DayKey
    var part: Part
}

/// 걸음을 날에 놓는 방식
enum BreakPace: String, CaseIterable, Identifiable, Sendable {
    /// 오늘부터 마감 전날까지 고르게
    case spread
    /// 오늘부터 하루에 하나
    case daily
    /// 오늘 다
    case today
    var id: String { rawValue }
    var name: String {
        switch self {
        case .spread: "마감까지 고르게"
        case .daily: "하루에 하나"
        case .today: "오늘 다"
        }
    }
}

enum BreakRules {
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

    /// 날짜·시각 낱말을 뺀 이름 ("금요일까지 발표 준비" → "발표 준비")
    static func subject(_ title: String, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> String {
        let raw = BrainRules.tidy(title.precomposedStringWithCanonicalMapping)
        let t = BrainRules.tidy(Parser.parse(raw, now: now, parts: parts, calendar: calendar).title)
        return t.count >= 2 ? t : raw
    }

    // MARK: 다듬어 둔 걸음 (모델이 없거나 검사를 못 넘을 때)

    /// 갈래 낱말은 좁게 (첫 동작과 같은 이유 — 넓으면 엉뚱하게 걸린다)
    private static let known: [(NSRegularExpression, [String])] = [
        (rx(#"발표|PPT|ppt|피피티|프레젠테이션"#), ["전할 말 세 줄로 적기", "장마다 제목만 잡기", "장 내용 채우기", "소리 내어 한 번 해 보기"]),
        (rx(#"이력서|자소서|자기소개서|지원서|포트폴리오"#), ["공고 다시 읽고 요건 적기", "넣을 경험 고르기", "초안 끝까지 쓰기", "다시 읽고 고치기"]),
        (rx(#"보고서|기획서|제안서|레포트|리포트|논문|원고|과제|에세이"#), ["자료 모아 한곳에 두기", "목차만 잡기", "초안 끝까지 쓰기", "다시 읽고 고치기"]),
        (rx(#"시험|자격증|공부"#), ["범위 적어 보기", "범위를 덩어리로 나누기", "첫 덩어리 보기", "틀린 것만 다시 보기"]),
        (rx(#"이사|이삿짐"#), ["버릴 것 골라 내놓기", "이사 업체 견적 받기", "안 쓰는 것부터 상자에 싸기", "주소 바꿀 곳 적어 두기"]),
        (rx(#"여행|휴가"#), ["갈 곳과 날 정하기", "오가는 표 예매하기", "잘 곳 예약하기", "가져갈 것 적고 짐 싸기"]),
        (rx(#"대청소|청소|정리|치우"#), ["버릴 것부터 봉투에 담기", "한 군데만 골라 치우기", "나머지 치우기", "쓰레기 내놓기"]),
    ]

    static func knownSteps(for subject: String) -> [String]? { known.first { has($0.0, subject) }?.1 }

    /// 모델 없이도 나가는 걸음. 모르는 일이면 어떤 일에나 맞는 네 걸음.
    static func fallback(for subject: String) -> [String] {
        knownSteps(for: subject) ?? ["필요한 것 적어 보기", "가장 쉬운 데부터 손대기", "남은 데 마저 하기", "빠진 것 없는지 보기"]
    }

    // MARK: 모델이 쓴 걸음 검사

    private static let whenWord = rx(#"오늘|내일|모레|글피|요일|주말|다음\s*주|이번\s*주|아침|점심|저녁|오전|오후|밤에|\d+\s*(?:일|시|분|월)"#)
    /// 하는 일이 안 보이는 걸음 ("갱신 완료하기" · "준비하기") — 작은 모델이 끝에 자주 붙인다
    private static let hollow = rx(#"완료|완성하기$|종료하기$|마무리하기$|^(?:준비|정리|확인|검토|점검|시작|진행)하기$"#)

    /// 걸음마다: 한 줄 · 4~30자 · 한국어 · 조언·구호 없음 · 큰일을 그대로 되풀이하지 않음 (BrainRules.cleanStep),
    /// 그리고 큰일에 없는 날짜·시각 낱말 없음(날은 규칙이 놓는다) · 빈 걸음 아님 · 서로 겹치지 않음. 셋이 안 남으면 nil.
    static func clean(_ raw: [String], subject: String) -> [String]? {
        guard !BrainRules.isCrisis(subject) else { return nil }
        var out: [String] = []
        for r in raw {
            // "찾기하기 · 풀기하기"는 끝을 한 번만
            let once = r.replacingOccurrences(of: #"기하기\s*$"#, with: "기", options: .regularExpression)
            guard let s = BrainRules.cleanStep(once, title: subject), !BrainRules.isCrisis(s), !inventsWhen(s, subject: subject), !has(hollow, s) else { continue }
            let key = flat(s)
            if out.contains(where: { same(flat($0), key) }) { continue }
            out.append(s)
            if out.count == 5 { break }
        }
        return out.count >= 3 ? out : nil
    }

    /// 큰일의 이름에 없는 날짜·시각 낱말이 걸음에 들었나 ("주말농장 신청"의 '주말'은 이름이지 날짜가 아니다)
    private static func inventsWhen(_ step: String, subject: String) -> Bool {
        whenWord.matches(in: step, range: NSRange(step.startIndex..., in: step)).contains { m in
            Range(m.range, in: step).map { !subject.contains(step[$0]) } ?? false
        }
    }

    private static func flat(_ s: String) -> String { s.filter { !$0.isWhitespace && !$0.isPunctuation } }

    /// 거의 같은 걸음인가 (한쪽이 다른 쪽을 품거나, 글자가 8할 넘게 겹친다)
    private static func same(_ a: String, _ b: String) -> Bool {
        if a.contains(b) || b.contains(a) { return true }
        let x = Set(a), y = Set(b)
        return Double(x.intersection(y).count) / Double(max(1, min(x.count, y.count))) > 0.8
    }

    // MARK: 날에 놓기

    /// 고를 수 있는 방식 (첫째가 기본). '고르게'는 마감이 모레 이후일 때만 뜻이 있다.
    /// 마감이 오늘·내일이면 '오늘 다'가 기본이고, '하루에 하나'를 고르면 그 날을 넘겨 이어진다 (날짜를 안 써서 오늘에 들어간 큰일).
    static func paces(today: DayKey, due: DayKey?, calendar: Calendar = .current) -> [BreakPace] {
        guard let due else { return [.daily, .today] }
        return today.days(to: due, calendar: calendar) >= 2 ? [.spread, .daily, .today] : [.today, .daily]
    }

    /// 걸음을 날에 놓는다. 마감(due)이 모레 이후면 어떤 방식이든 걸음은 마감 전날까지 끝난다.
    /// - nowPart: 오늘 놓이는 걸음의 띠 (지금 띠). part: 다른 날의 띠 (큰일의 띠).
    static func place(_ steps: [String], pace: BreakPace, today: DayKey, due: DayKey?, nowPart: Part, part: Part, calendar: Calendar = .current) -> [BreakStep] {
        let n = steps.count
        guard n > 0 else { return [] }
        // 쓸 수 있는 날 수: 오늘 … 마감 전날. 마감이 없거나 오늘·내일이면 걸음 수만큼.
        let left = due.map { today.days(to: $0, calendar: calendar) } ?? 0
        let room = left >= 2 ? left : n
        let offsets: [Int]
        switch pace {
        case .today:
            offsets = Array(repeating: 0, count: n)
        case .daily:
            offsets = (0..<n).map { min($0, room - 1) }
        case .spread:
            offsets = (0..<n).map { n == 1 ? 0 : Int((Double($0 * (room - 1)) / Double(n - 1)).rounded()) }
        }
        return zip(steps, offsets).map { title, off in
            BreakStep(title: title, day: today.adding(days: off, calendar: calendar), part: off == 0 ? nowPart : part)
        }
    }

    /// 고른 걸음을 항목으로. 메모에 어느 큰일에서 왔는지 남긴다.
    static func items(_ steps: [BreakStep], subject: String, duration: Int, now: Date) -> [Item] {
        steps.enumerated().map { i, s in
            Item(title: s.title, note: "‘\(subject)’에서 나눈 걸음", day: s.day, part: s.part, duration: duration,
                 created: now.addingTimeInterval(Double(i) * 0.001))
        }
    }
}
