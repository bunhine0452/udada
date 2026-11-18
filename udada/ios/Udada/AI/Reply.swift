import Foundation

// 받은 약속에 답장: "금요일 7시에 강남역에서 저녁 어때?" → 내 일정을 실제로 보고(비었나 · 겹치나 · 대신 되는 때) 답장을 쓴다.
// 모델은 받은 글의 말투에 맞춰 답장 문장을 쓰고, 날과 시각을 읽는 것 · 일정이 겹치는지 · 대신 되는 때는 전부 여기 규칙이 실제 기록으로 정한다.
// 모델이 쓴 문장은 vet 이 다시 본다 — 정해 준 시각 말고 다른 시각을 말하거나 말투가 어긋나면 규칙 문장을 쓴다. Foundation 만 쓴다.

/// 받은 글에서 읽은 제안
struct ReplyOffer: Hashable, Sendable {
    var message: String
    /// 약속 이름 ("강남역에서 저녁")
    var title: String
    var day: DayKey
    /// 0시부터 분
    var time: Int
    var duration: Int
    /// 존댓말로 온 글인가
    var polite: Bool
}

/// 내 일정에 대어 본 결과
struct ReplyCheck: Hashable, Sendable {
    var offer: ReplyOffer
    var today: DayKey
    /// 그 시간에 겹치는 내 약속
    var clashes: [Entry]
    /// 그날의 내 약속 전부 (그림에 쓴다)
    var events: [Entry]
    /// 겹칠 때 대신 되는 가장 가까운 때
    var alt: Slot?
    var free: Bool { clashes.isEmpty }

    struct Slot: Hashable, Sendable { var day: DayKey; var time: Int }
}

struct ReplyDraft: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable, CaseIterable { case accept, alternative, decline }
    var kind: Kind
    var text: String
    var fromAI: Bool
    var id: Kind { kind }
    var label: String { switch kind { case .accept: "좋아" ; case .alternative: "다른 시간" ; case .decline: "이번엔 어려워" } }
}

enum ReplyRules {
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
    private static func strip(_ r: NSRegularExpression, _ s: String) -> String { r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "") }

    /// 만나자고 묻는 말
    private static let ask = rx("어때|어떠세요|어떠신|볼래|볼까|보자|만날래|만날까|만나자|가능해|가능하|괜찮아|괜찮으|시간 ?돼|시간 ?되|될까|갈래|갈까|가자|하자|할래|먹을래|먹자|마실래|마시자|뵐|봬")
    private static let politeCue = rx("요[.?!~ ]*(\\n|$)|니다|세요|까요|시죠|시나요|드려요|드립니다")
    private static let tail = rx("\\s*(은|는)?\\s*(어때요|어떠세요|어떠신가요|어때|볼래요|볼래|볼까요|볼까|만날래요|만날래|만날까요|만날까|가능해요|가능하세요|가능해|괜찮아요|괜찮으세요|괜찮아|시간 ?돼요|시간 ?되세요|시간 ?돼|될까요|될까|갈래요|갈래|갈까요|갈까|하실래요|할래요|할래|먹을래요|먹을래|뵐 수 있을까요|봬요)[?!.~ ]*$")
    private static let morning = rx("오전|아침|새벽|모닝|조식|출근")
    private static let evening = rx("저녁|밤|퇴근|야식|술|회식|디너")
    private static let noon = rx("점심|런치")

    /// 답장이 필요한 약속 제안인가 (때가 있고, 만나자고 묻는다)
    static func looksLikeOffer(_ text: String, now: Date, calendar: Calendar = .current) -> Bool { offer(from: text, now: now, calendar: calendar) != nil }

    /// 받은 글 → 제안. 여러 문장이면 때가 읽히고 묻는 말이 있는 첫 문장을 쓴다.
    static func offer(from text: String, now: Date, calendar: Calendar = .current) -> ReplyOffer? {
        let whole = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        guard whole.count >= 4, whole.count <= 600, has(ask, whole) else { return nil }
        let sentences = whole.components(separatedBy: CharacterSet(charactersIn: "\n.!")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 3 }
        for s in sentences where has(ask, s) {
            let p = Parser.parse(s.replacingOccurrences(of: "?", with: ""), now: now, calendar: calendar)
            guard p.day != nil || p.time != nil || p.part != nil else { continue }
            guard let time = clock(p, in: s) else { continue }
            let today = DayKey(now, calendar: calendar)
            // 날을 안 말했으면 오늘, 이미 지난 시각이면 내일
            var day = p.day ?? today
            if p.day == nil, time <= minuteOfDay(now, calendar: calendar) { day = today.adding(days: 1, calendar: calendar) }
            guard day >= today else { continue }
            var title = strip(tail, p.title).trimmingCharacters(in: CharacterSet(charactersIn: " ?!.~,"))
            title = strip(rx("^(우리|혹시|그럼|그러면|너|저희)\\s+"), title)
            title = strip(rx("(에|에서)$"), title)
            if title.count < 2 { title = "약속" }
            let meal = has(evening, s) || has(noon, s)
            return ReplyOffer(message: whole, title: String(title.prefix(30)), day: day, time: time, duration: p.duration ?? (meal ? 90 : 60), polite: has(politeCue, whole))
        }
        return nil
    }

    /// 만나는 약속의 시각으로 읽는다: "7시"는 저녁 7시, "3시"는 오후 3시. 아침이라고 했으면 그대로. 시각 없이 '저녁에'면 19시, '점심'이면 12시.
    private static func clock(_ p: Parsed, in s: String) -> Int? {
        if var t = p.time {
            let h = t / 60
            if !has(morning, s) {
                if (1...7).contains(h) { t += 720 }
                else if (8...11).contains(h), has(evening, s) { t += 720 }
            }
            return t
        }
        if has(noon, s) { return 12 * 60 }
        if has(evening, s) || p.part == .evening { return 19 * 60 }
        if has(morning, s) || p.part == .morning { return 10 * 60 }
        if p.part == .afternoon { return 15 * 60 }
        return nil
    }

    // MARK: 내 일정에 대어 보기

    static func check(_ o: ReplyOffer, data: AppData, external: [Entry] = [], now: Date, calendar: Calendar = .current) -> ReplyCheck {
        let today = DayKey(now, calendar: calendar)
        func events(_ d: DayKey) -> [Entry] { data.entries(on: d, external: external, calendar: calendar).filter { $0.isEvent && !$0.allDay }.sorted { ($0.time ?? 0) < ($1.time ?? 0) } }
        func clash(_ list: [Entry], _ t: Int) -> [Entry] { list.filter { ($0.time ?? 0) < t + o.duration && ($0.end ?? 0) > t } }
        let mine = events(o.day)
        let clashes = clash(mine, o.time)
        var alt: ReplyCheck.Slot?
        if !clashes.isEmpty {
            // 같은 날 뒤로 30분씩 (밤 9시 반 시작까지) → 같은 날 앞으로 (아침 9시부터, 지금보다 뒤) → 다음 날 같은 시각
            let nowMin = o.day == today ? minuteOfDay(now, calendar: calendar) : 0
            let later = stride(from: o.time + 30, through: 21 * 60 + 30, by: 30).first { clash(mine, $0).isEmpty }
            let earlier = stride(from: o.time - 30, through: max(9 * 60, nowMin + 30), by: -30).first { clash(mine, $0).isEmpty }
            if let t = later ?? earlier { alt = .init(day: o.day, time: t) }
            else {
                let next = o.day.adding(days: 1, calendar: calendar)
                if clash(events(next), o.time).isEmpty { alt = .init(day: next, time: o.time) }
            }
        }
        return ReplyCheck(offer: o, today: today, clashes: clashes, events: mine, alt: alt)
    }

    // MARK: 말

    /// "오늘" · "내일" · "금요일" (모레부터는 요일로 — 보낸 사람도 대개 요일로 말했다)
    static func dayWord(_ d: DayKey, today: DayKey) -> String {
        switch today.days(to: d) {
        case 0: "오늘"
        case 1: "내일"
        default: Fmt.weekday[d.weekday()] + "요일"
        }
    }

    /// 말로 하는 시각: "7시" · "7시 반" · "오전 10시" · "12시"
    static func clockWord(_ m: Int) -> String {
        let h = (m / 60) % 24, min = m % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        let base = (h < 12 && h != 0 ? "오전 " : "") + "\(h12)시"
        return min == 0 ? base : min == 30 ? base + " 반" : base + " \(min)분"
    }

    /// 받침에 따라 은/는
    private static func topic(_ s: String) -> String {
        guard let last = s.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return s + "은" }
        return s + ((last.value - 0xAC00) % 28 == 0 ? "는" : "은")
    }

    /// 한 줄 판정: "금요일 19:00 — 비어 있어." · "금요일 19:00엔 ‘치과’(18:30–19:30)가 있어."
    static func verdict(_ c: ReplyCheck) -> String {
        let when = "\(dayWord(c.offer.day, today: c.today)) \(Fmt.hm(c.offer.time))"
        guard let first = c.clashes.first else { return "\(when) — 비어 있어." }
        let more = c.clashes.count > 1 ? " 외 \(c.clashes.count - 1)개" : ""
        return "\(when)엔 ‘\(first.title)’(\(Fmt.hm(first.time ?? 0))–\(Fmt.hm(first.end ?? 0)))\(more) 일정이 있어."
    }

    /// 규칙 문장 (모델이 없거나 모델 문장이 검사에서 떨어졌을 때도 이것이 나간다)
    static func drafts(_ c: ReplyCheck) -> [ReplyDraft] {
        let o = c.offer
        let day = dayWord(o.day, today: c.today), at = clockWord(o.time)
        var out: [ReplyDraft] = []
        if c.free {
            out.append(ReplyDraft(kind: .accept, text: o.polite ? "좋아요! \(day) \(at)에 봬요." : "좋아! \(day) \(at)에 봐.", fromAI: false))
        } else if let a = c.alt {
            let other = (a.day == o.day ? "" : dayWord(a.day, today: c.today) + " ") + clockWord(a.time)
            out.append(ReplyDraft(kind: .alternative, text: o.polite ? "\(day) \(at)에는 일정이 있어서요, \(topic(other)) 어떠세요?" : "\(day) \(at)엔 일정이 있어서, \(topic(other)) 어때?", fromAI: false))
        }
        out.append(ReplyDraft(kind: .decline, text: o.polite ? "죄송해요, \(topic(day)) 어려울 것 같아요. 다른 날 어떠세요?" : "미안, \(topic(day)) 어려울 것 같아. 다른 날 보자!", fromAI: false))
        return out
    }

    // MARK: 모델 문장 검사

    private static let hours = rx("(오전 |오후 )?(\\d{1,2})시( 반| \\d{1,2}분)?")
    private static let no = rx("어려|어렵|안 될|안 돼|못 |힘들|미안|죄송|다음에|다른 날")
    private static let soft = rx("미안|죄송|아쉽|아쉬")
    private static let junk = rx("[A-Za-z]{3,}|[\\x{1F300}-\\x{1FAFF}\\x{2600}-\\x{27BF}]")
    private static let politeEnd = rx("(요|니다|세요|까요|죠)[.?!~ ]*$")

    /// 모델이 쓴 답장을 받아도 되나. 정해 준 시각만 말해야 하고(다른 시각 금지), 수락은 수락답게 · 거절은 거절답게, 말투는 받은 글과 같게.
    static func vet(_ raw: String, kind: ReplyDraft.Kind, check c: ReplyCheck) -> String? {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \n\"“”'")).replacingOccurrences(of: "\n", with: " ")
        guard t.count >= 4, t.count <= 70, !has(junk, t), has(politeEnd, t) == c.offer.polite else { return nil }
        let ns = t as NSString
        let said = Set(hours.matches(in: t, range: NSRange(location: 0, length: ns.length)).compactMap { Int(ns.substring(with: $0.range(at: 2))) })
        func h12(_ m: Int) -> Int { let h = (m / 60) % 12; return h == 0 ? 12 : h }
        let offered = h12(c.offer.time)
        switch kind {
        case .accept:
            guard c.free, !has(no, t), said.isSubset(of: [offered]), said.contains(offered) || t.contains(dayWord(c.offer.day, today: c.today)) else { return nil }
        case .alternative:
            guard let a = c.alt, said.contains(h12(a.time)), said.isSubset(of: [offered, h12(a.time)]) else { return nil }
        case .decline:
            // 거절은 부드러워야 한다 — 모델은 "이번에는 어렵다."처럼 딱 잘라 쓰곤 했다. 미안함·아쉬움이 없으면 규칙 문장을 쓴다.
            guard has(no, t), has(soft, t), t.count >= 10, said.isSubset(of: [offered]) else { return nil }
        }
        return t
    }

    /// 모델에 건네는 사실 (모델이 지어낼 것이 없게 전부 적어 준다)
    static func facts(_ c: ReplyCheck) -> String {
        let o = c.offer
        var lines = ["받은 글: \(o.message)", "제안된 때: \(dayWord(o.day, today: c.today)) \(clockWord(o.time))", "말투: \(o.polite ? "존댓말" : "반말")"]
        if c.free { lines.append("내 일정: 그 시간은 비어 있다") }
        else {
            lines.append("내 일정: 그 시간에 다른 일정이 있다")
            if let a = c.alt { lines.append("대신 되는 때: \((a.day == o.day ? "" : dayWord(a.day, today: c.today) + " ") + clockWord(a.time))") }
        }
        return lines.joined(separator: "\n")
    }

    /// 수락·대안을 골랐을 때 넣을 약속
    static func item(for kind: ReplyDraft.Kind, check c: ReplyCheck, parts: DayParts, created: Date) -> Item? {
        let slot: ReplyCheck.Slot
        switch kind {
        case .accept: slot = .init(day: c.offer.day, time: c.offer.time)
        case .alternative: guard let a = c.alt else { return nil }; slot = a
        case .decline: return nil
        }
        return Item(title: c.offer.title, day: slot.day, part: parts.part(at: slot.time), time: slot.time, duration: c.offer.duration, created: created)
    }
}
