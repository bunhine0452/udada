#if !LOGIC_HARNESS
import XCTest
@testable import Udada
#else
import Foundation
#endif

// 하루 계산 (Shared/DayLogic.swift + Model.swift 의 날짜·반복·저장). 기준: 2026-11-15 (일) 14:20 Asia/Seoul.
// 사례 목록은 독립 하네스(-D LOGIC_HARNESS)와 XCTest 가 같이 쓴다.

#if !LOGIC_HARNESS
final class DayLogicTests: XCTestCase {
    func testCases() {
        for c in logicCases {
            let fails = c.run()
            XCTAssertTrue(fails.isEmpty, "[\(c.name)] " + fails.joined(separator: " / "))
        }
    }
}
#endif

// MARK: - 도우미

struct LogicCase {
    let name: String
    let body: (inout [String]) -> Void
    func run() -> [String] { var f: [String] = []; body(&f); return f }
}

fileprivate func cal(_ tz: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tz)!
    c.locale = Locale(identifier: "ko_KR")
    return c
}
fileprivate let seoul = cal("Asia/Seoul")
fileprivate let ny = cal("America/New_York")

fileprivate func k(_ s: String) -> DayKey { DayKey(string: s)! }
fileprivate let D0 = k("2026-11-15")

/// "14:20" → 2026-11-15 14:20, 또는 "2026-11-16 05:00"
fileprivate func at(_ s: String, _ c: Calendar = seoul) -> Date {
    let full = s.count <= 5 ? "2026-11-15 " + s : s
    let p = full.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" }).compactMap { Int($0) }
    return c.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: p[3], minute: p[4]))!
}

fileprivate func t(_ n: Double) -> Date { Date(timeIntervalSinceReferenceDate: 800_000_000 + n) }

fileprivate func todo(_ title: String, _ day: DayKey? = D0, _ part: Part = .afternoon, dur: Int = 30, created: Double = 0, pinned: Bool = false) -> Item {
    Item(title: title, day: day, part: part, duration: dur, created: t(created), pinned: pinned)
}
/// "15:00" 약속
fileprivate func event(_ title: String, _ hm: String, dur: Int = 60, day: DayKey = D0) -> Item {
    let p = hm.split(separator: ":").compactMap { Int($0) }
    let m = p[0] * 60 + p[1]
    return Item(title: title, day: day, part: DayParts().part(at: m), time: m, duration: dur)
}
fileprivate func series(_ title: String, _ rule: RepeatRule, start: DayKey, time: Int? = nil, part: Part = .morning) -> Item {
    Item(title: title, day: start, part: part, time: time, duration: 20, repeatRule: rule, lead: 5)
}
fileprivate func data(_ items: [Item], _ edit: (inout Settings) -> Void = { _ in }) -> AppData {
    var d = AppData(); d.items = items; edit(&d.settings); return d
}
fileprivate func ext(_ id: String, _ title: String, day: DayKey = D0, time: Int? = nil, dur: Int = 60, allDay: Bool = false) -> Entry {
    Entry(source: .external(id: id), title: title, day: day, part: time.map { DayParts().part(at: $0) } ?? .morning,
          time: time, duration: dur, done: false, allDay: allDay)
}

fileprivate func expect(_ f: inout [String], _ ok: Bool, _ what: @autoclosure () -> String) { if !ok { f.append(what()) } }
fileprivate func eq<T: Equatable>(_ f: inout [String], _ got: T, _ want: T, _ what: String = "") {
    if got != want { f.append("\(what) got \(got) want \(want)") }
}

/// 반복이 그날 하루치를 내놓는 날들 (from…to)
fileprivate func hits(_ d: AppData, _ from: String, _ to: String, _ c: Calendar = seoul) -> [String] {
    var out: [String] = []
    var day = k(from)
    while day <= k(to) {
        if !d.entries(on: day, calendar: c).isEmpty { out.append(day.description) }
        day = day.adding(days: 1, calendar: c)
    }
    return out
}
fileprivate func occ(_ s: Item, _ day: DayKey) -> Entry.Source { .occurrence(series: s.id, day: day) }
fileprivate func children(_ d: AppData, of s: Item) -> [Item] { d.items.filter { $0.seriesID == s.id } }
fileprivate func band(_ sh: DaySheet, _ p: Part) -> Band { sh.bands.first { $0.part == p }! }
fileprivate func titles(_ es: [Entry]) -> [String] { es.map(\.title) }

// MARK: - 사례

let logicCases: [LogicCase] = repeatCases + mutateCases + settleCases + sheetCases + nowCases + dayKeyCases + codableCases

// MARK: 반복 펼치기

fileprivate let repeatCases: [LogicCase] = [
    LogicCase(name: "매일: 시작일 전엔 없음, 하루치 모양") { f in
        let s = series("약", .daily, start: k("2026-11-10"), time: 480)
        let d = data([s])
        eq(&f, hits(d, "2026-11-08", "2026-11-12"), ["2026-11-10", "2026-11-11", "2026-11-12"])
        let e = d.entries(on: D0, calendar: seoul)
        eq(&f, e.count, 1, "count")
        guard let o = e.first else { return }
        eq(&f, o.source, occ(s, D0), "source")
        expect(&f, o.repeating && !o.done && !o.pinned && o.time == 480 && o.duration == 20 && o.day == D0 && o.part == .morning, "shape \(o)")
        eq(&f, o.id, "o:" + s.id.uuidString + ":2026-11-15", "id")
        eq(&f, o.itemID, s.id, "itemID")
    },
    LogicCase(name: "평일: 월–금만") { f in
        let d = data([series("출근", .weekdaysOnly, start: k("2026-11-09"))])
        eq(&f, hits(d, "2026-11-08", "2026-11-15"), ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13"])
    },
    LogicCase(name: "주말: 토·일만") { f in
        let d = data([series("빨래", .weekendsOnly, start: k("2026-11-01"))])
        eq(&f, hits(d, "2026-11-12", "2026-11-17"), ["2026-11-14", "2026-11-15"])
    },
    LogicCase(name: "매주 월·수, 빈 요일이면 시작 요일") { f in
        let d = data([series("수영", .weekly([4, 2]), start: k("2026-11-04"))])
        eq(&f, hits(d, "2026-11-01", "2026-11-18"), ["2026-11-04", "2026-11-09", "2026-11-11", "2026-11-16", "2026-11-18"])
        let e = data([series("모임", RepeatRule(kind: .weekly), start: k("2026-11-12"))]) // 목
        eq(&f, hits(e, "2026-11-10", "2026-11-27"), ["2026-11-12", "2026-11-19", "2026-11-26"])
        eq(&f, RepeatRule.weekly([4, 2]).weekdays, [2, 4], "sorted")
    },
    LogicCase(name: "매달 31일: 30일 달·2월은 말일") { f in
        let d = data([series("카드값", .monthly(31), start: k("2026-01-31"))])
        let want = ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30"]
        eq(&f, hits(d, "2026-01-01", "2026-06-30"), want, "jan–jun")
        eq(&f, hits(d, "2026-11-01", "2026-12-31"), ["2026-11-30", "2026-12-31"], "nov–dec")
        eq(&f, hits(d, "2028-02-01", "2028-03-01"), ["2028-02-29"], "leap feb")
        eq(&f, hits(d, "2025-12-01", "2025-12-31"), [], "before start")
    },
    LogicCase(name: "매달 30일·29일: 2월, 윤년 2028") { f in
        eq(&f, hits(data([series("a", .monthly(30), start: k("2026-11-30"))]), "2027-02-01", "2027-03-31"), ["2027-02-28", "2027-03-30"])
        eq(&f, hits(data([series("b", .monthly(29), start: k("2026-01-01"))]), "2026-02-01", "2026-02-28"), ["2026-02-28"])
        eq(&f, hits(data([series("b", .monthly(29), start: k("2026-01-01"))]), "2028-02-01", "2028-02-29"), ["2028-02-29"])
    },
    LogicCase(name: "매달: 날짜 없으면 시작일, 시작 전 달은 없음") { f in
        let d = data([series("월세", RepeatRule(kind: .monthly), start: k("2026-11-20"))])
        eq(&f, hits(d, "2026-11-01", "2026-12-31"), ["2026-11-20", "2026-12-20"])
        let e = data([series("관리비", .monthly(15), start: k("2026-11-20"))])
        eq(&f, hits(e, "2026-11-01", "2026-12-31"), ["2026-12-15"])
    },
    LogicCase(name: "N일마다: 시작부터 세고, 해를 넘김") { f in
        eq(&f, hits(data([series("물", .interval(3), start: k("2026-11-10"))]), "2026-11-07", "2026-11-17"), ["2026-11-10", "2026-11-13", "2026-11-16"])
        eq(&f, hits(data([series("주간", .interval(7), start: k("2026-12-28"))]), "2026-12-29", "2027-01-11"), ["2027-01-04", "2027-01-11"])
        eq(&f, RepeatRule.interval(0).every, 1, "min 1")
        eq(&f, hits(data([series("x", RepeatRule(kind: .interval, every: nil), start: k("2026-11-14"))]), "2026-11-13", "2026-11-15"), ["2026-11-14", "2026-11-15"], "nil every")
    },
    LogicCase(name: "N일마다: 뉴욕 서머타임 앞뒤 (2026-03-08, 11-01)") { f in
        eq(&f, hits(data([series("a", .interval(2), start: k("2026-03-06"))]), "2026-03-06", "2026-03-11", ny), ["2026-03-06", "2026-03-08", "2026-03-10"])
        eq(&f, hits(data([series("b", .interval(2), start: k("2026-10-30"))]), "2026-10-30", "2026-11-04", ny), ["2026-10-30", "2026-11-01", "2026-11-03"])
        eq(&f, hits(data([series("c", .weekdaysOnly, start: k("2026-03-01"))]), "2026-03-06", "2026-03-10", ny), ["2026-03-06", "2026-03-09", "2026-03-10"])
    },
    LogicCase(name: "예외 날은 빠짐") { f in
        var s = series("약", .daily, start: k("2026-11-10"))
        s.exceptions = [k("2026-11-15")]
        eq(&f, hits(data([s]), "2026-11-14", "2026-11-16"), ["2026-11-14", "2026-11-16"])
    },
    LogicCase(name: "끝낸 하루치는 끝낸 채로 하나만") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.setDone(occ(s, D0), true, now: at("09:00"))
        let e = d.entries(on: D0, calendar: seoul)
        eq(&f, e.count, 1, "count")
        guard let one = e.first, let cid = children(d, of: s).first?.id else { f.append("no child"); return }
        eq(&f, one.source, .item(cid), "source")
        expect(&f, one.done && one.repeating, "done/repeating \(one)")
        eq(&f, d.entries(on: D0.adding(days: 1, calendar: seoul), calendar: seoul).first?.source, occ(s, D0.adding(days: 1, calendar: seoul)), "tomorrow")
    },
    LogicCase(name: "걱정·나중에는 빠지고, 끝낸 일은 남음") { f in
        var w = todo("월세 걱정"); w.worry = true
        var done = todo("끝낸 일"); done.done = true
        let d = data([w, todo("나중", nil), done, todo("어제", k("2026-11-14")), todo("오늘")])
        eq(&f, titles(d.entries(on: D0, calendar: seoul)), ["끝낸 일", "오늘"])
        eq(&f, d.laterItems.map(\.title), ["나중"], "later")
        eq(&f, d.worries.map(\.title), ["월세 걱정"], "worries")
    },
    LogicCase(name: "기기 달력 약속은 그날 것만 합쳐짐") { f in
        let d = data([todo("보고서")])
        let es = d.entries(on: D0, external: [ext("x1", "회의", time: 600), ext("x2", "내일 회의", day: k("2026-11-16"), time: 600)], calendar: seoul)
        eq(&f, titles(es), ["보고서", "회의"])
        expect(&f, es.last?.isExternal == true && es.last?.itemID == nil, "external")
    },
    LogicCase(name: "달력 점: 끝낸 일·걱정은 안 찍고 반복은 찍음") { f in
        var done = todo("끝"); done.done = true
        var w = todo("걱정"); w.worry = true
        eq(&f, data([done, w]).hasEntries(on: D0, calendar: seoul), false, "done/worry")
        eq(&f, data([series("s", .weekendsOnly, start: k("2026-11-01"))]).hasEntries(on: D0, calendar: seoul), true, "series")
        eq(&f, data([series("s", .weekdaysOnly, start: k("2026-11-01"))]).hasEntries(on: D0, calendar: seoul), false, "series miss")
        eq(&f, data([series("물", .daily, start: k("2026-11-01"))]).hasEntries(on: D0, calendar: seoul), false, "daily todo series no dot")
    },
]

// MARK: 바꾸기

fileprivate let mutateCases: [LogicCase] = [
    LogicCase(name: "떼어 내기: 예외 한 번, 새 항목 모양, 두 번째는 같은 항목") { f in
        let s = series("약", .daily, start: k("2026-11-10"), time: 480)
        var d = data([s])
        guard let a = d.materialize(occ(s, D0)) else { f.append("nil"); return }
        eq(&f, d.item(s.id)?.exceptions, [D0], "exceptions")
        guard let c = d.item(a) else { f.append("no child"); return }
        expect(&f, c.seriesID == s.id && c.occurrence == D0 && c.day == D0 && c.time == 480 && c.duration == 20 && c.part == .morning
               && c.lead == 5 && c.repeatRule == nil && !c.done, "child \(c)")
        let b = d.materialize(occ(s, D0))
        eq(&f, b, a, "second id")
        eq(&f, d.items.count, 2, "items")
        eq(&f, d.item(s.id)?.exceptions, [D0], "exceptions after 2nd")
    },
    LogicCase(name: "떼어 내기: 항목·없는 항목·달력·없는 반복") { f in
        let it = todo("a")
        var d = data([it])
        eq(&f, d.materialize(.item(it.id)), it.id, "item")
        eq(&f, d.materialize(.item(UUID())), nil, "missing")
        eq(&f, d.materialize(.external(id: "x")), nil, "external")
        eq(&f, d.materialize(.occurrence(series: UUID(), day: D0)), nil, "missing series")
        eq(&f, d.items.count, 1, "unchanged")
    },
    LogicCase(name: "끝내기: 하루치 → doneAt, 되돌리면 doneAt 지움") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.setDone(occ(s, D0), true, now: at("09:00"))
        guard let c = children(d, of: s).first else { f.append("no child"); return }
        expect(&f, c.done && c.doneAt == at("09:00"), "done \(c)")
        d.setDone(.item(c.id), false, now: at("10:00"))
        expect(&f, d.item(c.id)?.done == false && d.item(c.id)?.doneAt == nil, "undone")
        d.setDone(.external(id: "x"), true)
        eq(&f, d.items.count, 2, "external no-op")
    },
    LogicCase(name: "토글: 같은 하루치를 두 번 눌러도 항목 하나 (위젯 늦은 화면)") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.toggleDone(occ(s, D0), now: at("09:00"))
        d.toggleDone(occ(s, D0), now: at("09:01"))
        let cs = children(d, of: s)
        eq(&f, cs.count, 1, "children")
        eq(&f, d.item(s.id)?.exceptions.count, 1, "exceptions")
        expect(&f, cs.first?.done == true, "still done")
        eq(&f, d.entries(on: D0, calendar: seoul).count, 1, "entries")
        guard let c = cs.first else { return }
        d.toggleDone(.item(c.id), now: at("09:02"))
        eq(&f, d.item(c.id)?.done, false, "item toggle off")
        d.toggleDone(.item(c.id), now: at("09:03"))
        expect(&f, d.item(c.id)?.done == true && d.item(c.id)?.doneAt == at("09:03"), "item toggle on")
        d.toggleDone(.item(UUID()))
        eq(&f, d.items.count, 2, "missing no-op")
    },
    LogicCase(name: "옮기기: 다른 날로 약속은 시각 유지, movedFrom 지움") { f in
        var e = event("치과", "15:00"); e.movedFrom = k("2026-11-10")
        var d = data([e])
        d.move(.item(e.id), to: k("2026-11-17"), part: .morning)
        let m = d.item(e.id)!
        expect(&f, m.day == k("2026-11-17") && m.time == 900 && m.part == .afternoon && m.movedFrom == nil, "moved \(m)")
    },
    LogicCase(name: "옮기기: 나중에로 시각·하나 지움, 할 일은 띠 바꿈") { f in
        var e = event("치과", "15:00"); e.pinned = true
        let a = todo("보고서")
        var d = data([e, a])
        d.move(.item(e.id), to: nil)
        let m = d.item(e.id)!
        expect(&f, m.day == nil && m.time == nil && !m.pinned && !m.worry && m.isLater, "later \(m)")
        eq(&f, d.laterItems.map(\.title), ["치과"], "later list")
        d.move(.item(a.id), to: D0, part: .evening)
        eq(&f, d.item(a.id)?.part, .evening, "band")
        d.move(.item(a.id), to: nil, part: .morning)
        expect(&f, d.item(a.id)?.part == .morning && d.item(a.id)?.day == nil, "later with part")
    },
    LogicCase(name: "옮기기: 걱정에서 꺼내면 걱정 아님") { f in
        var w = todo("걱정", nil); w.worry = true
        var d = data([w])
        d.move(.item(w.id), to: D0, part: .evening)
        let m = d.item(w.id)!
        expect(&f, !m.worry && m.day == D0 && m.part == .evening, "\(m)")
    },
    LogicCase(name: "옮기기: 반복 하루치를 내일로") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        let tmr = k("2026-11-16")
        d.move(occ(s, D0), to: tmr, part: .evening)
        let c = children(d, of: s)
        expect(&f, c.count == 1 && c[0].day == tmr && c[0].occurrence == D0 && c[0].part == .evening, "child \(c)")
        eq(&f, d.entries(on: D0, calendar: seoul).count, 0, "today")
        eq(&f, d.entries(on: tmr, calendar: seoul).count, 2, "tomorrow child + own occurrence")
    },
    LogicCase(name: "옮기기: 하나 있는 날로 가면 하나를 넘기지 않음") { f in
        let a = todo("A", D0, pinned: true)
        let b = todo("B", k("2026-11-16"), pinned: true)
        let c = todo("C", D0, created: 1)
        var d = data([a, b, c])
        d.move(.item(a.id), to: k("2026-11-16"))
        eq(&f, d.items.filter { $0.day == k("2026-11-16") && $0.pinned }.map(\.title), ["B"], "one pin")
        d.pin(.item(c.id), day: D0)
        d.move(.item(c.id), to: k("2026-11-17"))
        eq(&f, d.item(c.id)?.pinned, true, "keeps pin on empty day")
        d.move(.item(c.id), to: k("2026-11-17"), part: .evening)
        eq(&f, d.item(c.id)?.pinned, true, "same day band change keeps pin")
    },
    LogicCase(name: "지우기: 항목, 하루치 하나, 반복 전체") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        let a = todo("a")
        var d = data([s, a])
        d.remove(.item(a.id))
        eq(&f, d.item(a.id) == nil, true, "item")
        d.remove(occ(s, D0))
        eq(&f, d.item(s.id)?.exceptions, [D0], "one")
        d.remove(occ(s, D0))
        eq(&f, d.item(s.id)?.exceptions, [D0], "one again")
        d.remove(.external(id: "x"))
        eq(&f, d.items.count, 1, "external no-op")
    },
    LogicCase(name: "지우기: 반복 전체는 안 끝낸 하루치까지, 끝낸 것은 남김") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.setDone(occ(s, k("2026-11-13")), true, now: at("2026-11-13 09:00"))
        d.move(occ(s, k("2026-11-14")), to: k("2026-11-20"))
        d.remove(occ(s, D0), wholeSeries: true)
        expect(&f, d.item(s.id) == nil, "series gone")
        eq(&f, d.items.map(\.occurrence), [k("2026-11-13")], "kept done only")
        eq(&f, d.entries(on: k("2026-11-20"), calendar: seoul).count, 0, "moved undone gone")
    },
    LogicCase(name: "지우기: 떼어 낸 하루치로 반복 전체 → 다른 안 끝낸 하루치도") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.setDone(occ(s, k("2026-11-13")), true, now: at("2026-11-13 09:00"))
        d.move(occ(s, k("2026-11-14")), to: k("2026-11-20"))
        guard let cid = d.materialize(occ(s, D0)) else { f.append("nil"); return }
        d.remove(.item(cid), wholeSeries: true)
        expect(&f, d.item(s.id) == nil, "series gone")
        eq(&f, d.items.map(\.occurrence), [k("2026-11-13")], "kept done only")
    },
    LogicCase(name: "지우기: 원본 항목으로 반복 전체 → 안 끝낸 하루치도") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.move(occ(s, k("2026-11-14")), to: k("2026-11-20"))
        d.remove(.item(s.id), wholeSeries: true)
        eq(&f, d.items.count, 0, "all gone \(d.items.map(\.title))")
    },
    LogicCase(name: "지우기: 이미 떼어 낸 하루치를 늦은 화면에서 하나만 지움") { f in
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([s])
        d.move(occ(s, D0), to: D0, part: .evening)
        d.remove(occ(s, D0))
        eq(&f, children(d, of: s).count, 0, "child removed")
        eq(&f, d.entries(on: D0, calendar: seoul).count, 0, "nothing today")
    },
    LogicCase(name: "오늘의 하나: 그날 하나만, 다시 누르면 빠짐") { f in
        let a = todo("A"), b = todo("B", created: 1), other = todo("내일 것", k("2026-11-16"), pinned: true)
        var d = data([a, b, other])
        d.pin(.item(a.id), day: D0)
        d.pin(.item(b.id), day: D0)
        eq(&f, d.items.filter { $0.day == D0 && $0.pinned }.map(\.title), ["B"], "only B")
        eq(&f, d.item(other.id)?.pinned, true, "other day untouched")
        d.pin(.item(b.id), day: D0)
        eq(&f, d.items.filter { $0.day == D0 && $0.pinned }.count, 0, "unpinned")
        let s = series("약", .daily, start: k("2026-11-10"))
        d.add(s)
        d.pin(occ(s, D0), day: D0)
        eq(&f, children(d, of: s).map(\.pinned), [true], "occurrence pinned")
        d.pin(.external(id: "x"), day: D0)
        eq(&f, children(d, of: s).map(\.pinned), [true], "external no-op")
    },
    LogicCase(name: "걱정 상자로: 날·시각·하나 지움, 하루치는 떼어 냄") { f in
        var e = event("면접", "15:00"); e.pinned = true
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([e, s])
        d.toWorry(.item(e.id))
        let w = d.item(e.id)!
        expect(&f, w.worry && w.day == nil && w.time == nil && !w.pinned && !w.isLater, "\(w)")
        eq(&f, d.worries.map(\.title), ["면접"], "worries")
        eq(&f, d.laterItems.count, 0, "not later")
        d.toWorry(occ(s, D0))
        expect(&f, children(d, of: s).first?.worry == true && d.item(s.id)?.exceptions == [D0], "occurrence")
        eq(&f, d.entries(on: D0, calendar: seoul).count, 0, "entries")
    },
    LogicCase(name: "하루 닫기: 내일 아침 / 나중에 / 안 해") { f in
        var a = todo("A", D0, .evening); a.movedFrom = k("2026-11-12")
        let e = event("회의", "19:00"), b = todo("B"), c = todo("C")
        let s = series("약", .daily, start: k("2026-11-10"))
        var d = data([a, e, b, c, s])
        d.apply(.tomorrow, to: .item(a.id), today: D0, calendar: seoul)
        d.apply(.tomorrow, to: .item(e.id), today: D0, calendar: seoul)
        d.apply(.later, to: .item(b.id), today: D0, calendar: seoul)
        d.apply(.drop, to: .item(c.id), today: D0, calendar: seoul)
        d.apply(.drop, to: occ(s, D0), today: D0, calendar: seoul)
        let ta = d.item(a.id)!, te = d.item(e.id)!
        expect(&f, ta.day == k("2026-11-16") && ta.part == .morning && ta.movedFrom == nil, "tomorrow \(ta)")
        expect(&f, te.day == k("2026-11-16") && te.time == 1140 && te.part == .evening, "event \(te)")
        expect(&f, d.item(b.id)?.isLater == true, "later")
        expect(&f, d.item(c.id) == nil, "drop")
        eq(&f, d.item(s.id)?.exceptions, [D0], "drop occurrence")
        var g = data([todo("말일", k("2026-12-31"))])
        g.apply(.tomorrow, to: .item(g.items[0].id), today: k("2026-12-31"), calendar: seoul)
        eq(&f, g.items[0].day, k("2027-01-01"), "year end")
    },
]

// MARK: 지난 할 일 옮기기

fileprivate let settleCases: [LogicCase] = [
    LogicCase(name: "지난 날 할 일 → 오늘 지금 띠, 원래 날 기록 (처음 것만)") { f in
        let a = todo("A", k("2026-11-13"), .morning)
        var b = todo("B", k("2026-11-14"), .evening); b.movedFrom = k("2026-11-10")
        var d = data([a, b])
        d.settle(now: at("14:20"), calendar: seoul)
        let ta = d.item(a.id)!, tb = d.item(b.id)!
        expect(&f, ta.day == D0 && ta.part == .afternoon && ta.movedFrom == k("2026-11-13"), "A \(ta)")
        expect(&f, tb.day == D0 && tb.part == .afternoon && tb.movedFrom == k("2026-11-10"), "B \(tb)")
        let e = d.entries(on: D0, calendar: seoul).first { $0.title == "A" }
        eq(&f, e?.movedFrom, k("2026-11-13"), "entry movedFrom")
    },
    LogicCase(name: "오늘 지난 띠 → 지금 띠, movedFrom 없음, 뒤 띠는 그대로") { f in
        let a = todo("아침", D0, .morning), b = todo("저녁", D0, .evening), c = todo("낮", D0, .afternoon)
        var d = data([a, b, c])
        d.settle(now: at("14:20"), calendar: seoul)
        expect(&f, d.item(a.id)?.part == .afternoon && d.item(a.id)?.movedFrom == nil, "morning")
        eq(&f, d.item(b.id)?.part, .evening, "evening")
        eq(&f, d.item(c.id)?.part, .afternoon, "afternoon")
    },
    LogicCase(name: "건드리지 않음: 끝낸 일·약속·걱정·반복·떼어 낸 하루치·나중에·앞날") { f in
        let past = k("2026-11-13")
        var done = todo("끝", past, .morning); done.done = true
        let ev = event("지난 약속", "09:00", day: past)
        var w = todo("걱정", past); w.worry = true
        let s = series("약", .daily, start: past)
        var d = data([done, ev, w, s, todo("나중", nil), todo("앞날", k("2026-11-20"), .morning)])
        d.move(occ(s, k("2026-11-14")), to: k("2026-11-14"), part: .morning) // 떼어 낸 하루치
        let before = d.items
        d.settle(now: at("14:20"), calendar: seoul)
        eq(&f, d.items, before, "unchanged")
    },
    LogicCase(name: "새벽(06시 전)은 아침으로 친다") { f in
        let a = todo("어제 저녁", D0, .evening)
        var d = data([a])
        d.settle(now: at("2026-11-16 05:00"), calendar: seoul)
        let m = d.item(a.id)!
        expect(&f, m.day == k("2026-11-16") && m.part == .morning && m.movedFrom == D0, "\(m)")
        eq(&f, DayParts().part(at: 0), .morning, "00:00")
        eq(&f, DayParts().part(at: 359), .morning, "05:59")
        eq(&f, DayParts().part(at: 720), .afternoon, "12:00")
        eq(&f, DayParts().part(at: 1080), .evening, "18:00")
        eq(&f, DayParts().part(at: 1439), .evening, "23:59")
    },
    LogicCase(name: "띠 경계를 바꾸면 그 경계로") { f in
        let edit: (inout Settings) -> Void = { $0.parts.afternoonStart = 600; $0.parts.eveningStart = 960 }
        let a = todo("아침", D0, .morning), b = todo("낮", D0, .afternoon)
        var d = data([a, b], edit)
        d.settle(now: at("09:30"), calendar: seoul)
        expect(&f, d.item(a.id)?.part == .morning && d.item(b.id)?.part == .afternoon, "09:30 untouched")
        d.settle(now: at("16:30"), calendar: seoul)
        expect(&f, d.item(a.id)?.part == .evening && d.item(b.id)?.part == .evening, "16:30 → evening")
        var p = DayParts(); p.afternoonStart = 600; p.eveningStart = 960
        eq(&f, p.range(.afternoon), 600..<960, "range")
    },
    LogicCase(name: "두 번 해도 같음") { f in
        var d = data([todo("A", k("2026-11-13"), .morning), todo("B", D0, .morning)])
        d.settle(now: at("14:20"), calendar: seoul)
        let once = d.items
        d.settle(now: at("14:20"), calendar: seoul)
        eq(&f, d.items, once)
    },
    LogicCase(name: "옮겨 와도 오늘의 하나는 하나") { f in
        let old = todo("어제 하나", k("2026-11-14"), pinned: true)
        let today = todo("오늘 하나", D0, pinned: true)
        var d = data([old, today])
        d.settle(now: at("14:20"), calendar: seoul)
        eq(&f, d.items.filter { $0.day == D0 && $0.pinned }.map(\.title), ["오늘 하나"], "one pin")
        let a = todo("13일 하나", k("2026-11-13"), pinned: true), b = todo("14일 하나", k("2026-11-14"), pinned: true)
        var g = data([a, b])
        g.settle(now: at("14:20"), calendar: seoul)
        eq(&f, g.items.filter { $0.day == D0 && $0.pinned }.count, 1, "two past pins → one")
        let solo = todo("혼자", k("2026-11-14"), pinned: true)
        var h = data([solo])
        h.settle(now: at("14:20"), calendar: seoul)
        eq(&f, h.items[0].pinned, true, "lone pin kept")
    },
]

// MARK: 한 장

fileprivate let sheetCases: [LogicCase] = [
    LogicCase(name: "띠 나누기: 약속은 시각으로, 할 일은 띠로") { f in
        var odd = event("저녁 약속", "19:00"); odd.part = .morning
        let d = data([event("새벽", "05:00"), event("늦은 아침", "11:30"), event("정오", "12:00"), odd, todo("빨래", D0, .evening), todo("메일", D0, .morning)])
        let sh = DayLogic.sheet(for: D0, data: d, now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, titles(band(sh, .morning).events), ["새벽", "늦은 아침"], "morning events")
        eq(&f, titles(band(sh, .morning).todos), ["메일"], "morning todos")
        eq(&f, titles(band(sh, .afternoon).events), ["정오"], "afternoon")
        eq(&f, titles(band(sh, .evening).events), ["저녁 약속"], "evening events")
        eq(&f, titles(band(sh, .evening).todos), ["빨래"], "evening todos")
        eq(&f, sh.bands.map(\.part), Part.allCases, "order")
        eq(&f, band(sh, .afternoon).range, 720..<1080, "range")
    },
    LogicCase(name: "정렬: 약속은 시각·제목, 할 일은 하나 먼저 그다음 넣은 순") { f in
        let d = data([event("나", "13:00"), event("가", "13:00"), event("다", "12:30"),
                      todo("셋째", created: 3), todo("첫째", created: 1), todo("하나", created: 9, pinned: true), todo("둘째", created: 2)])
        let sh = DayLogic.sheet(for: D0, data: d, now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, titles(band(sh, .afternoon).events), ["다", "가", "나"], "events")
        eq(&f, titles(band(sh, .afternoon).todos), ["하나", "첫째", "둘째", "셋째"], "todos")
    },
    LogicCase(name: "지난 띠·지금 띠: 오늘만") { f in
        let d = data([])
        let sh = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul)
        eq(&f, sh.bands.map(\.gone), [true, false, false], "gone")
        eq(&f, sh.bands.map(\.live), [false, true, false], "live")
        expect(&f, sh.isToday && sh.now != nil, "today")
        let other = DayLogic.sheet(for: k("2026-11-16"), data: d, now: at("14:20"), calendar: seoul)
        expect(&f, !other.isToday && other.now == nil && other.bands.allSatisfy { !$0.gone && !$0.live }, "other day")
        let dawn = DayLogic.sheet(for: D0, data: d, now: at("05:00"), calendar: seoul)
        eq(&f, dawn.bands.map(\.live), [true, false, false], "dawn live")
        eq(&f, dawn.bands.map(\.gone), [false, false, false], "dawn gone")
        eq(&f, band(dawn, .morning).free, 360, "dawn free counts from 06:00")
        let edge = DayLogic.sheet(for: D0, data: d, now: at("12:00"), calendar: seoul)
        eq(&f, edge.bands.map(\.gone), [true, false, false], "12:00 gone")
        eq(&f, edge.bands.map(\.live), [false, true, false], "12:00 live")
    },
    LogicCase(name: "빈 시간: 다른 날은 띠 전체에서 약속을 뺌") { f in
        let sh = DayLogic.sheet(for: D0, data: data([event("병원", "09:00")]), now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, sh.bands.map(\.free), [300, 360, 360])
        eq(&f, sh.freeTotal, 1020, "total")
    },
    LogicCase(name: "빈 시간: 띠 경계를 넘는 약속은 두 띠 다에서 뺌") { f in
        let sh = DayLogic.sheet(for: D0, data: data([event("점심", "11:30", dur: 60), event("저녁", "17:00", dur: 120)]), now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, sh.bands.map(\.free), [330, 270, 300])
        let late = DayLogic.sheet(for: D0, data: data([event("밤샘", "23:00", dur: 120), event("새벽", "05:30", dur: 60)]), now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, late.bands.map(\.free), [330, 360, 300], "day edges")
    },
    LogicCase(name: "빈 시간: 겹치는 약속은 한 번만 뺌") { f in
        let sh = DayLogic.sheet(for: D0, data: data([event("가", "09:00"), event("나", "09:30"), event("다", "09:40", dur: 10)]), now: at("2026-11-14 10:00"), calendar: seoul)
        eq(&f, band(sh, .morning).free, 270)
    },
    LogicCase(name: "빈 시간: 오늘은 지금부터, 반쯤 지난 약속은 남은 만큼") { f in
        let d = data([event("회의", "14:00"), event("아침 회의", "09:00")])
        let sh = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul)
        eq(&f, sh.bands.map(\.free), [0, 180, 360])
        let sh2 = DayLogic.sheet(for: D0, data: data([event("지난", "13:00")]), now: at("14:20"), calendar: seoul)
        eq(&f, band(sh2, .afternoon).free, 220, "past event")
    },
    LogicCase(name: "넣은 일·넘침: 안 끝낸 할 일만 셈") { f in
        var done = todo("끝", dur: 30); done.done = true
        var items = [todo("A", dur: 120), todo("B", dur: 90), done]
        var sh = DayLogic.sheet(for: D0, data: data(items), now: at("14:20"), calendar: seoul)
        var b = band(sh, .afternoon)
        expect(&f, b.planned == 210 && b.free == 220 && b.overflow == 0, "fits \(b.planned)/\(b.free)")
        items.append(todo("C", dur: 30))
        sh = DayLogic.sheet(for: D0, data: data(items), now: at("14:20"), calendar: seoul)
        b = band(sh, .afternoon)
        expect(&f, b.planned == 240 && b.overflow == 20, "overflow \(b.planned)/\(b.overflow)")
        eq(&f, sh.plannedTotal, 240, "total")
        eq(&f, band(sh, .morning).overflow, 0, "gone band")
    },
    LogicCase(name: "종일 약속은 따로, 띠에 안 들어감") { f in
        let sh = DayLogic.sheet(for: D0, data: data([]), external: [ext("h", "휴가", allDay: true), ext("m", "회의", time: 600)], now: at("14:20"), calendar: seoul)
        eq(&f, titles(sh.allDay), ["휴가"], "allDay")
        eq(&f, titles(sh.bands.flatMap(\.events)), ["회의"], "bands")
        expect(&f, !sh.isEmpty, "not empty")
        expect(&f, DayLogic.sheet(for: D0, data: data([]), now: at("14:20"), calendar: seoul).isEmpty, "empty")
    },
    LogicCase(name: "하루 닫기 남은 것: 반복·끝낸 일·약속 빼고") { f in
        let s = series("약", .daily, start: k("2026-11-10"), part: .evening)
        let s2 = series("물", .daily, start: k("2026-11-10"), part: .evening)
        var done = todo("끝"); done.done = true
        var d = data([s, s2, done, todo("남은 일", D0, .evening), event("약속", "19:00")])
        d.move(occ(s2, D0), to: D0, part: .afternoon) // 떼어 낸 하루치
        let sh = DayLogic.sheet(for: D0, data: d, now: at("21:00"), calendar: seoul)
        eq(&f, titles(sh.leftovers), ["남은 일"])
        eq(&f, sh.openTodos, 3, "open")
        eq(&f, sh.doneTodos, 1, "done")
        eq(&f, sh.eventCount, 1, "events")
        eq(&f, band(sh, .evening).openTodos, 2, "band open")
    },
]

// MARK: 지금 줄

fileprivate let nowCases: [LogicCase] = [
    LogicCase(name: "약속 중: 남은 시간 머리줄") { f in
        let d = data([event("회의", "14:00"), todo("메일", dur: 10)])
        guard let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now else { f.append("nil"); return }
        eq(&f, n.current?.title, "회의", "current")
        eq(&f, n.headline, "회의 중 · 40분 남음", "headline")
        eq(&f, n.advice, "끝나면 숨 한 번 쉬고 다음으로.", "advice")
        eq(&f, n.minute, 860, "minute")
    },
    LogicCase(name: "다음 약속까지: 하나 먼저 들어감") { f in
        let d = data([event("치과", "15:00"), todo("긴 일", dur: 60, created: 1), todo("메일", dur: 15, created: 2), todo("하나", dur: 30, created: 3, pinned: true)])
        guard let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now else { f.append("nil"); return }
        expect(&f, n.next?.title == "치과" && n.gap == 40 && n.current == nil, "next \(String(describing: n.next?.title)) gap \(n.gap)")
        eq(&f, n.headline, "치과까지 40분", "headline")
        eq(&f, n.fit?.title, "하나", "fit")
        eq(&f, n.advice, "‘하나’ 30분, 지금 들어가.", "advice")
    },
    LogicCase(name: "하나가 안 들어가면 들어가는 첫 일") { f in
        let d = data([event("치과", "15:00"), todo("긴 일", dur: 60, created: 1), todo("메일", dur: 15, created: 2), todo("하나", dur: 60, created: 3, pinned: true)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        eq(&f, n?.fit?.title, "메일")
    },
    LogicCase(name: "끝낸 일·다른 띠 일은 안 고름") { f in
        var done = todo("끝", dur: 10); done.done = true
        let d = data([event("치과", "15:00"), done, todo("저녁 일", D0, .evening, dur: 10)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        expect(&f, n?.fit == nil, "fit \(String(describing: n?.fit?.title))")
        eq(&f, n?.advice, "비어 있어. 쉬어도 돼.", "advice")
    },
    LogicCase(name: "짧은 틈: 새로 시작하기엔 짧아") { f in
        let d = data([event("통화", "14:35", dur: 15), todo("보고서", dur: 30)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        expect(&f, n?.gap == 15 && n?.fit == nil, "gap \(String(describing: n?.gap))")
        eq(&f, n?.advice, "새로 시작하기엔 짧아. 숨 한 번.", "advice")
    },
    LogicCase(name: "남은 일이 틈보다 김") { f in
        let d = data([event("회의", "16:00"), todo("보고서", dur: 120)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        eq(&f, n?.advice, "남은 일이 1시간 40분보다 길어. 조금만 해도 돼.", "advice")
    },
    LogicCase(name: "다음 약속 없음 → 하루 끝까지") { f in
        let d = data([event("아침 회의", "09:00"), todo("보고서", dur: 120)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        expect(&f, n?.next == nil && n?.current == nil && n?.gap == 580, "gap \(String(describing: n?.gap))")
        eq(&f, n?.headline, "남은 약속 없음", "headline")
        eq(&f, n?.fit?.title, "보고서", "fit")
        let empty = DayLogic.sheet(for: D0, data: data([]), now: at("14:20"), calendar: seoul).now
        eq(&f, empty?.advice, "비어 있어. 쉬어도 돼.", "empty")
    },
    LogicCase(name: "하루 닫기 시각 뒤 남은 약속 없음 → 새 일 권하지 않음") { f in
        let d = data([todo("보고서", D0, .evening, dur: 10)])
        let n = DayLogic.sheet(for: D0, data: d, now: at("23:50"), calendar: seoul).now
        expect(&f, n?.fit == nil, "late fit \(String(describing: n?.fit?.title))")
        eq(&f, n?.advice, "늦었어. 남은 건 하루 닫기로 자리만 정하자.", "late advice")
        let empty = DayLogic.sheet(for: D0, data: data([]), now: at("21:30"), calendar: seoul).now
        eq(&f, empty?.advice, "오늘은 여기까지. 푹 쉬어.", "late empty")
        let early = DayLogic.sheet(for: D0, data: d, now: at("20:50"), calendar: seoul).now
        eq(&f, early?.fit?.title, "보고서", "before close time still suggests")
        let withEvent = DayLogic.sheet(for: D0, data: data([event("야간 통화", "23:55", dur: 5), todo("보고서", D0, .evening, dur: 2)]), now: at("23:00"), calendar: seoul).now
        eq(&f, withEvent?.fit?.title, "보고서", "upcoming event keeps normal advice")
    },
    LogicCase(name: "정각에 시작하는 약속은 '중', 끝 시각엔 다음으로") { f in
        let d = data([event("회의", "14:20", dur: 30), event("치과", "16:00")])
        let n = DayLogic.sheet(for: D0, data: d, now: at("14:20"), calendar: seoul).now
        expect(&f, n?.current?.title == "회의" && n?.next?.title == "치과", "\(String(describing: n?.current?.title)) / \(String(describing: n?.next?.title))")
        let n2 = DayLogic.sheet(for: D0, data: d, now: at("14:50"), calendar: seoul).now
        expect(&f, n2?.current == nil && n2?.gap == 70, "end \(String(describing: n2?.gap))")
    },
    LogicCase(name: "종일 약속은 지금 줄에 안 끼어듦, 기기 달력 약속은 끼어듦") { f in
        let n = DayLogic.sheet(for: D0, data: data([]), external: [ext("h", "휴가", allDay: true), ext("m", "외부 회의", time: 900, dur: 30)], now: at("14:20"), calendar: seoul).now
        eq(&f, n?.next?.title, "외부 회의", "next")
        eq(&f, n?.headline, "외부 회의까지 40분", "headline")
    },
]

// MARK: 날짜 키

fileprivate let dayKeyCases: [LogicCase] = [
    LogicCase(name: "더하기: 달·해·윤년을 넘김 (서울·뉴욕)") { f in
        for c in [seoul, ny] {
            let z = c.timeZone.identifier
            eq(&f, k("2026-11-30").adding(days: 1, calendar: c), k("2026-12-01"), z)
            eq(&f, k("2026-12-31").adding(days: 1, calendar: c), k("2027-01-01"), z)
            eq(&f, k("2027-01-01").adding(days: -1, calendar: c), k("2026-12-31"), z)
            eq(&f, k("2028-02-28").adding(days: 1, calendar: c), k("2028-02-29"), z)
            eq(&f, k("2026-02-28").adding(days: 1, calendar: c), k("2026-03-01"), z)
            eq(&f, k("2026-11-15").adding(days: 365, calendar: c), k("2027-11-15"), z)
            eq(&f, k("2026-03-07").adding(days: 1, calendar: c), k("2026-03-08"), z + " dst")
            eq(&f, k("2026-03-08").adding(days: 1, calendar: c), k("2026-03-09"), z + " dst")
            eq(&f, k("2026-11-01").adding(days: 1, calendar: c), k("2026-11-02"), z + " dst")
            eq(&f, k("2026-11-02").adding(days: -1, calendar: c), k("2026-11-01"), z + " dst")
        }
    },
    LogicCase(name: "며칠 차이: 앞뒤·해 넘김·서머타임") { f in
        for c in [seoul, ny] {
            let z = c.timeZone.identifier
            eq(&f, k("2026-11-15").days(to: k("2026-12-25"), calendar: c), 40, z)
            eq(&f, k("2026-12-25").days(to: k("2026-11-15"), calendar: c), -40, z)
            eq(&f, k("2026-12-31").days(to: k("2027-01-01"), calendar: c), 1, z)
            eq(&f, k("2026-03-07").days(to: k("2026-03-09"), calendar: c), 2, z + " spring")
            eq(&f, k("2026-03-08").days(to: k("2026-03-09"), calendar: c), 1, z + " spring day")
            eq(&f, k("2026-10-31").days(to: k("2026-11-02"), calendar: c), 2, z + " fall")
            eq(&f, k("2026-11-01").days(to: k("2026-11-02"), calendar: c), 1, z + " fall day")
            eq(&f, k("2026-01-01").days(to: k("2027-01-01"), calendar: c), 365, z + " year")
            eq(&f, k("2028-01-01").days(to: k("2029-01-01"), calendar: c), 366, z + " leap year")
            eq(&f, D0.days(to: D0, calendar: c), 0, z + " same")
        }
    },
    LogicCase(name: "요일") { f in
        for c in [seoul, ny] {
            eq(&f, k("2026-11-15").weekday(calendar: c), 1, "sun")
            eq(&f, k("2026-11-16").weekday(calendar: c), 2, "mon")
            eq(&f, k("2026-11-21").weekday(calendar: c), 7, "sat")
            eq(&f, k("2028-02-29").weekday(calendar: c), 3, "leap tue")
            eq(&f, k("2026-03-08").weekday(calendar: c), 1, "dst sun")
            eq(&f, k("2026-11-01").weekday(calendar: c), 1, "dst sun")
        }
    },
    LogicCase(name: "주의 첫날: 월요일 시작·일요일 시작") { f in
        for c in [seoul, ny] {
            let z = c.timeZone.identifier
            eq(&f, k("2026-11-15").startOfWeek(mondayFirst: true, calendar: c), k("2026-11-09"), z + " sun/mon")
            eq(&f, k("2026-11-16").startOfWeek(mondayFirst: true, calendar: c), k("2026-11-16"), z + " mon/mon")
            eq(&f, k("2026-11-21").startOfWeek(mondayFirst: true, calendar: c), k("2026-11-16"), z + " sat/mon")
            eq(&f, k("2026-11-15").startOfWeek(mondayFirst: false, calendar: c), k("2026-11-15"), z + " sun/sun")
            eq(&f, k("2026-11-16").startOfWeek(mondayFirst: false, calendar: c), k("2026-11-15"), z + " mon/sun")
            eq(&f, k("2026-11-21").startOfWeek(mondayFirst: false, calendar: c), k("2026-11-15"), z + " sat/sun")
            eq(&f, k("2026-12-02").startOfWeek(mondayFirst: true, calendar: c), k("2026-11-30"), z + " month")
            eq(&f, k("2027-01-01").startOfWeek(mondayFirst: false, calendar: c), k("2026-12-27"), z + " year")
            eq(&f, k("2026-03-08").startOfWeek(mondayFirst: true, calendar: c), k("2026-03-02"), z + " spring mon")
            eq(&f, k("2026-03-10").startOfWeek(mondayFirst: true, calendar: c), k("2026-03-09"), z + " spring mon2")
            eq(&f, k("2026-03-10").startOfWeek(mondayFirst: false, calendar: c), k("2026-03-08"), z + " spring sun")
            eq(&f, k("2026-11-01").startOfWeek(mondayFirst: false, calendar: c), k("2026-11-01"), z + " fall sun")
            eq(&f, k("2026-11-03").startOfWeek(mondayFirst: true, calendar: c), k("2026-11-02"), z + " fall mon")
        }
    },
    LogicCase(name: "Date ↔ DayKey: 자정 앞뒤, 서머타임 달 전체 왕복") { f in
        eq(&f, DayKey(at("2026-03-08 23:59", ny), calendar: ny), k("2026-03-08"), "ny late")
        eq(&f, DayKey(at("2026-11-01 00:00", ny), calendar: ny), k("2026-11-01"), "ny midnight")
        eq(&f, DayKey(at("2026-11-15 23:30", ny), calendar: seoul), k("2026-11-16"), "same instant, seoul")
        for c in [seoul, ny] {
            var day = k("2026-03-01")
            while day < k("2026-03-15") || (day >= k("2026-10-25") && day < k("2026-11-08")) {
                if DayKey(day.date(calendar: c), calendar: c) != day { f.append("round \(day) \(c.timeZone.identifier)") }
                day = day == k("2026-03-14") ? k("2026-10-25") : day.adding(days: 1, calendar: c)
            }
        }
        eq(&f, minuteOfDay(at("2026-03-08 10:00", ny), calendar: ny), 600, "wall clock on spring day")
        eq(&f, minuteOfDay(at("2026-11-01 10:00", ny), calendar: ny), 600, "wall clock on fall day")
    },
    LogicCase(name: "문자열·비교") { f in
        eq(&f, DayKey(y: 2026, m: 1, d: 5).description, "2026-01-05", "pad")
        eq(&f, DayKey(string: "2026-11-15"), DayKey(y: 2026, m: 11, d: 15), "parse")
        expect(&f, DayKey(string: "nope") == nil && DayKey(string: "2026-11") == nil && DayKey(string: "2026-11-15-1") == nil, "bad")
        expect(&f, k("2026-12-31") < k("2027-01-01") && k("2026-11-09") < k("2026-11-10") && k("2026-09-30") < k("2026-10-01"), "order")
        eq(&f, D0.id, "2026-11-15", "id")
    },
]

// MARK: 저장

fileprivate func roundTrip(_ d: AppData) throws -> AppData {
    try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(d))
}
fileprivate func decode(_ json: String) throws -> AppData {
    try JSONDecoder().decode(AppData.self, from: Data(json.utf8))
}

fileprivate let codableCases: [LogicCase] = [
    LogicCase(name: "AppData 왕복: 모든 필드") { f in
        var s = series("약", .weekly([2, 6]), start: k("2026-11-10"), time: 480)
        s.exceptions = [k("2026-11-13")]
        var d = data([s, todo("나중", nil)]) {
            $0.aiOn = false; $0.gateOn = false; $0.mondayFirst = false; $0.parts.eveningStart = 1020
            $0.hiddenCalendars = ["회사"]; $0.appearance = .dark; $0.digestTimes = [480]
        }
        d.setDone(occ(s, k("2026-11-16")), true, now: at("09:00"))
        var w = todo("걱정", nil); w.worry = true; w.fromDump = true; w.note = "메모"; w.spent = 12; w.lead = 0; w.movedFrom = k("2026-11-01")
        d.add(w)
        d.rests = [RestLog(at: at("10:00"), kind: .walk, seconds: 600, before: 3, after: 7)]
        d.dumps = [DumpLog(at: at("11:00"), before: 8, after: 4, now: 1, dated: 2, worry: 3, dropped: 4)]
        d.closes = [CloseLog(day: D0, at: at("21:00"), done: 3, tomorrow: 1, later: 1, dropped: 0)]
        d.focus = [FocusLog(at: at("13:00"), title: "보고서", planned: 30, spent: 41, finished: true)]
        d.activeFocus = ActiveFocus(itemID: s.id, title: "약", planned: 20, started: at("14:00"))
        d.seenIntro = true
        d.briefedDay = D0
        do {
            let r = try roundTrip(d)
            eq(&f, r.items, d.items, "items")
            eq(&f, r.settings, d.settings, "settings")
            expect(&f, r.rests == d.rests && r.dumps == d.dumps && r.closes == d.closes && r.focus == d.focus, "logs")
            expect(&f, r.activeFocus == d.activeFocus && r.seenIntro && r.briefedDay == D0 && r.version == 5, "misc")
            eq(&f, r.entries(on: k("2026-11-16"), calendar: seoul).map(\.done), [true], "entries after reload")
        } catch { f.append("threw \(error)") }
    },
    LogicCase(name: "빈 JSON → 기본값") { f in
        do {
            let r = try decode("{}")
            expect(&f, r.version == 5 && r.items.isEmpty && r.rests.isEmpty && !r.seenIntro && r.activeFocus == nil && r.briefedDay == nil, "defaults")
            eq(&f, r.settings, Settings(), "settings")
        } catch { f.append("threw \(error)") }
    },
    LogicCase(name: "옛 파일: 새 필드가 없어도 기본값으로 읽음") { f in
        let json = """
        {"version":5,"seenIntro":true,
         "items":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"치과","day":"2026-11-15","time":900,"created":800000000},
                  {"title":"약","day":"2026-11-10","repeatRule":{"kind":"daily"}}],
         "settings":{"mondayFirst":false,"parts":{"eveningStart":1020}},
         "rests":[{"at":800000000,"kind":"breath","seconds":60}],
         "unknownFutureField":[1,2,3]}
        """
        do {
            let r = try decode(json)
            eq(&f, r.items.count, 2, "items")
            guard r.items.count == 2 else { return }
            let a = r.items[0], b = r.items[1]
            eq(&f, a.id.uuidString, "6F9619FF-8B86-D011-B42D-00C04FC964FF", "id")
            expect(&f, a.part == .afternoon && a.duration == 30 && !a.done && a.doneAt == nil && !a.fromDump && a.exceptions.isEmpty
                   && !a.worry && !a.pinned && a.seriesID == nil && a.occurrence == nil && a.lead == nil && a.note == "", "item defaults \(a)")
            expect(&f, b.repeatRule == .daily && b.repeatRule?.weekdays == [] && b.exceptions.isEmpty, "rule \(String(describing: b.repeatRule))")
            let s = r.settings
            expect(&f, !s.mondayFirst && s.aiOn && s.gateOn && s.digestTimes == [510, 750, 1110] && s.defaultDuration == 30, "settings")
            expect(&f, s.parts.eveningStart == 1020 && s.parts.morningStart == 360 && s.parts.afternoonStart == 720 && s.parts.dayEnd == 1440, "parts")
            expect(&f, r.briefedDay == nil && r.seenIntro, "briefedDay")
            eq(&f, r.rests.first?.before, nil, "rest before")
            eq(&f, r.entries(on: D0, calendar: seoul).count, 2, "entries")
        } catch { f.append("threw \(error)") }
    },
    LogicCase(name: "망가진 날짜 문자열은 실패 (조용히 바꾸지 않음)") { f in
        for bad in ["\"garbage\"", "\"2026/11/15\"", "\"2026-11\"", "20261115"] {
            if (try? decode("{\"items\":[{\"title\":\"a\",\"day\":\(bad)}]}")) != nil { f.append("accepted day \(bad)") }
        }
        if (try? decode("{\"briefedDay\":\"어제\"}")) != nil { f.append("accepted briefedDay") }
        if (try? JSONDecoder().decode([DayKey].self, from: Data("[\"2026-11-15\"]".utf8))) != [D0] { f.append("good key") }
    },
]
