import Foundation

/// 비우기 카드가 하루 한 장의 어디로 가는지 — 화면 없이 계산만.
/// 지금 → 지금 띠 · 날짜 → 고른 날과 띠(글에 시각이 있으면 약속) · 걱정 → 걱정 상자 · 버리기 → 아무 데도.
enum DumpPlan {
    /// 날짜 칸의 '언제': 그날 그 띠, 또는 나중에 함
    enum When: Hashable { case day(DayKey, Part), later }

    struct Option: Hashable {
        var label: String
        var when: When
        var suggested: Bool
    }

    /// 제안이 날짜 칸일 때의 '언제': 제안한 날 → 글에 쓴 날 → (둘 다 없으면) 나중에 함.
    static func suggestedWhen(_ s: DumpSuggestion, parsed: Parsed) -> When? {
        guard s.bin == .date else { return nil }
        guard let d = s.day ?? (parsed.later ? nil : parsed.day) else { return .later }
        return .day(d, s.part ?? parsed.time.map { DayParts().part(at: $0) } ?? parsed.part ?? .morning)
    }

    /// "내일 아침" · "내일 15:00" (글에 시각이 있으면 띠 대신 시각) · "나중에 함"
    static func label(_ w: When, time: Int?, today: DayKey) -> String {
        switch w {
        case .later: return "나중에 함"
        case .day(let d, let p): return Fmt.day(d, today: today) + " " + (time.map(Fmt.hm) ?? p.name)
        }
    }

    /// 날짜 칩: 제안 · 오늘 저녁 · 내일 아침 · 주말 · 다음 주 · 나중에. 같은 날·띠는 한 번만.
    static func options(for s: DumpSuggestion, parsed: Parsed, today t: DayKey) -> [Option] {
        let wd = t.weekday() // 1 일 … 7 토
        var out: [Option] = []
        func add(_ label: String, _ w: When, suggested: Bool = false) {
            guard !out.contains(where: { $0.when == w }) else { return }
            out.append(Option(label: label, when: w, suggested: suggested))
        }
        if let w = suggestedWhen(s, parsed: parsed) { add("제안 · " + label(w, time: parsed.time, today: t), w, suggested: true) }
        add("오늘 저녁", .day(t, .evening))
        add("내일 아침", .day(t.adding(days: 1), .morning))
        if (2...6).contains(wd) {
            add("이번 주말", .day(t.adding(days: 7 - wd), .morning))
        } else {
            add("다음 주말", .day(t.adding(days: wd == 7 ? 7 : 6), .morning))
        }
        let toMonday = (9 - wd) % 7
        add("다음 주", .day(t.adding(days: toMonday == 0 ? 7 : toMonday), .morning))
        add("나중에", .later)
        return out
    }

    /// 카드 → 항목. 글에 든 날짜·시각 낱말은 Parser 로 다시 읽어 제목에서 빼고, 시각이 있으면 약속으로 박는다.
    /// 지금 칸은 지금 띠의 떠 있는 할 일, 걱정은 사용자의 말 그대로 걱정 상자에.
    static func item(for s: DumpSuggestion, bin: DumpBin?, when: When?, today: DayKey, now: Date,
                     settings: Settings, created: Date, calendar: Calendar = .current) -> Item? {
        let p = Parser.parse(s.text, now: now, parts: settings.parts, calendar: calendar)
        let title = p.title.isEmpty ? s.text : p.title
        switch bin {
        case .now:
            let current = settings.parts.part(at: minuteOfDay(now, calendar: calendar))
            return Item(title: title, day: today, part: current, duration: s.duration ?? 10, created: created, fromDump: true)
        case .date:
            switch when ?? .day(today.adding(days: 1, calendar: calendar), .morning) {
            case .later:
                return Item(title: title, duration: p.duration ?? s.duration ?? settings.defaultDuration, created: created, fromDump: true)
            case .day(let d, let chosen):
                let time = p.time
                let part = time.map { settings.parts.part(at: $0) } ?? chosen
                let duration = p.duration ?? s.duration ?? (time != nil ? 60 : settings.defaultDuration)
                return Item(title: title, day: d, part: part, time: time, duration: duration, created: created,
                            repeatRule: p.repeatRule, fromDump: true)
            }
        case .worry:
            return Item(title: s.text, created: created, worry: true, fromDump: true)
        case .drop, .none:
            return nil
        }
    }
}
