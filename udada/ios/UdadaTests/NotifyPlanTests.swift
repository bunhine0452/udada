#if !NOTIFY_HARNESS
import XCTest
@testable import Udada
#else
import Foundation
#endif

// 알림 계획 (Shared/NotifyPlan.swift). 기준: 2026-11-15 (일) Asia/Seoul.
// 사례 목록은 독립 하네스(-D NOTIFY_HARNESS)와 XCTest 가 같이 쓴다.

#if !NOTIFY_HARNESS
final class NotifyPlanTests: XCTestCase {
    func testCases() {
        for c in notifyCases {
            let fails = c.run()
            XCTAssertTrue(fails.isEmpty, "[\(c.name)] " + fails.joined(separator: " / "))
        }
    }
}
#endif

// MARK: - 공통 사례

struct NotifyCase {
    let name: String
    let body: (inout [String]) -> Void
    func run() -> [String] { var f: [String] = []; body(&f); return f }
}

fileprivate let seoulCal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Seoul")!
    c.locale = Locale(identifier: "ko_KR")
    return c
}()

fileprivate let D0 = DayKey(y: 2026, m: 11, d: 15)

/// 오늘(또는 offset 일 뒤) hh:mm
fileprivate func at(_ hm: String, _ offset: Int = 0) -> Date {
    let p = hm.split(separator: ":").compactMap { Int($0) }
    return D0.adding(days: offset, calendar: seoulCal).date(minute: p[0] * 60 + p[1], calendar: seoulCal)
}

fileprivate func plan(_ d: AppData, now: String = "07:00", focus: FocusFilterState = .off) -> [PlannedNote] {
    NotifyPlan.make(d, now: at(now), calendar: seoulCal, focus: focus)
}

fileprivate var seq = 0
fileprivate func todo(_ title: String, _ part: Part, day: DayKey? = D0, done: Bool = false) -> Item {
    seq += 1
    return Item(title: title, day: day, part: part, done: done, created: Date(timeIntervalSince1970: 1_700_000_000 + Double(seq)))
}
fileprivate func event(_ title: String, _ hm: String, day: DayKey = D0, lead: Int? = nil, rule: RepeatRule? = nil) -> Item {
    let p = hm.split(separator: ":").compactMap { Int($0) }
    return Item(title: title, day: day, part: .afternoon, time: p[0] * 60 + p[1], duration: 60, repeatRule: rule, lead: lead)
}
fileprivate func data(_ items: [Item], _ edit: (inout Settings) -> Void = { _ in }) -> AppData {
    var d = AppData()
    d.items = items
    edit(&d.settings)
    return d
}

fileprivate func expect(_ f: inout [String], _ ok: Bool, _ what: @autoclosure () -> String) {
    if !ok { f.append(what()) }
}
/// 모든 계획에 공통으로 참이어야 하는 것
fileprivate func sane(_ f: inout [String], _ notes: [PlannedNote], now: String = "07:00") {
    expect(&f, notes.allSatisfy { $0.fire > at(now) }, "지난 시각이 섞임")
    expect(&f, notes.allSatisfy { $0.id.hasPrefix("ud5.") }, "id 접두어")
    expect(&f, Set(notes.map(\.id)).count == notes.count, "id 중복")
    expect(&f, notes.map(\.fire) == notes.map(\.fire).sorted(), "가까운 순 아님")
    expect(&f, notes.count <= 60, "60개 넘음")
}
fileprivate func kinds(_ n: [PlannedNote], _ k: PlannedNote.Kind) -> [PlannedNote] { n.filter { $0.kind == k } }

let notifyCases: [NotifyCase] = [
    NotifyCase(name: "빈 데이터 → 알림 없음") { f in
        let n = plan(AppData()); sane(&f, n)
        expect(&f, n.isEmpty, "got \(n.map(\.id))")
    },
    NotifyCase(name: "아침 할 일 하나 → 08:30 묶음") { f in
        let n = plan(data([todo("메일 답장", .morning)])); sane(&f, n)
        let d = kinds(n, .digest).filter { $0.fire < at("12:00") }
        expect(&f, d.count == 1, "morning digests \(d.map(\.id))")
        expect(&f, d.first?.fire == at("08:30"), "fire \(String(describing: d.first?.fire))")
        expect(&f, d.first?.title == "아침 · 할 일 1개", "title \(d.first?.title ?? "-")")
        expect(&f, d.first?.body == "메일 답장", "body \(d.first?.body ?? "-")")
        expect(&f, d.first?.url == "udada://today", "url")
        expect(&f, d.first?.thread == "ud5.digest", "thread")
    },
    NotifyCase(name: "낮 할 일 셋 → '보고서 초안 외 2개'") { f in
        let n = plan(data([todo("보고서 초안", .afternoon), todo("택배 보내기", .afternoon), todo("전화", .afternoon)])); sane(&f, n)
        let d = kinds(n, .digest).first { $0.id == "ud5.digest.2026-11-15.afternoon" }
        expect(&f, d?.title == "낮 · 할 일 3개", "title \(d?.title ?? "-")")
        expect(&f, d?.body == "보고서 초안 외 2개", "body \(d?.body ?? "-")")
    },
    NotifyCase(name: "빈 띠는 건너뜀") { f in
        let n = plan(data([todo("빨래 개기", .evening)])); sane(&f, n)
        let today = kinds(n, .digest).filter { $0.fire < at("00:00", 1) }.map(\.id)
        expect(&f, today == ["ud5.digest.2026-11-15.evening"], "today \(today)")
    },
    NotifyCase(name: "안 끝낸 일은 다음 띠·내일로 따라간다 (settle)") { f in
        let n = plan(data([todo("보고서", .afternoon)])); sane(&f, n)
        let ids = kinds(n, .digest).map(\.id)
        expect(&f, ids.contains("ud5.digest.2026-11-15.evening"), "evening carry \(ids)")
        expect(&f, ids.contains("ud5.digest.2026-11-16.morning"), "tomorrow carry \(ids)")
    },
    NotifyCase(name: "지난 묶음 시각은 안 건다") { f in
        let n = plan(data([todo("보고서", .afternoon)]), now: "13:00"); sane(&f, n, now: "13:00")
        let ids = kinds(n, .digest).map(\.id)
        expect(&f, !ids.contains("ud5.digest.2026-11-15.afternoon"), "past afternoon \(ids)")
        expect(&f, !ids.contains("ud5.digest.2026-11-15.morning"), "past morning \(ids)")
        expect(&f, ids.contains("ud5.digest.2026-11-15.evening"), "evening \(ids)")
    },
    NotifyCase(name: "끝낸 일·나중에·걱정은 묶음에 안 센다") { f in
        let n = plan(data([todo("끝낸 일", .morning, done: true), todo("나중 일", .morning, day: nil), Item(title: "걱정", worry: true)]) { $0.worryOn = false })
        sane(&f, n)
        expect(&f, n.isEmpty, "got \(n.map(\.id))")
    },
    NotifyCase(name: "반복 할 일(시각 없음)도 센다") { f in
        let n = plan(data([Item(title: "물 한 잔", day: D0.adding(days: -3, calendar: seoulCal), part: .morning, repeatRule: .daily)])); sane(&f, n)
        let ids = kinds(n, .digest).map(\.id)
        expect(&f, ids == ["ud5.digest.2026-11-15.morning", "ud5.digest.2026-11-16.morning"], "ids \(ids)")
    },
    NotifyCase(name: "한 띠에 묶음 시각 둘 → 하나만") { f in
        let n = plan(data([todo("보고서", .afternoon)]) { $0.digestTimes = [750, 800] }); sane(&f, n)
        let today = kinds(n, .digest).filter { $0.fire < at("00:00", 1) }
        expect(&f, today.count == 1 && today.first?.fire == at("12:30"), "today \(today.map(\.id))")
    },
    NotifyCase(name: "묶음 끔") { f in
        let n = plan(data([todo("보고서", .afternoon)]) { $0.digestOn = false }); sane(&f, n)
        expect(&f, n.isEmpty, "got \(n.map(\.id))")
    },
    NotifyCase(name: "약속 15:00 → 14:50 '15:00 치과 · 10분 뒤'") { f in
        let it = event("치과", "15:00")
        let n = plan(data([it])); sane(&f, n)
        let e = kinds(n, .event)
        expect(&f, e.count == 1, "count \(e.count)")
        expect(&f, e.first?.fire == at("14:50"), "fire")
        expect(&f, e.first?.body == "15:00 치과 · 10분 뒤", "body \(e.first?.body ?? "-")")
        expect(&f, e.first?.url == "udada://day/2026-11-15", "url \(e.first?.url ?? "-")")
        expect(&f, e.first?.id == "ud5.event.i:\(it.id.uuidString)", "id \(e.first?.id ?? "-")")
    },
    NotifyCase(name: "항목 미리 알림 30분 · 60분 · 0분") { f in
        let n = plan(data([event("A", "15:00", lead: 30), event("B", "16:00", lead: 60), event("C", "17:00", lead: 0)])); sane(&f, n)
        let e = kinds(n, .event)
        expect(&f, e.map(\.fire) == [at("14:30"), at("15:00"), at("17:00")], "fires")
        expect(&f, e.map(\.body) == ["15:00 A · 30분 뒤", "16:00 B · 1시간 뒤", "17:00 C · 지금"], "bodies \(e.map(\.body))")
    },
    NotifyCase(name: "설정 기본 미리 알림 바꾸기") { f in
        let n = plan(data([event("치과", "15:00")]) { $0.eventLead = 5 }); sane(&f, n)
        expect(&f, kinds(n, .event).first?.fire == at("14:55"), "fire")
    },
    NotifyCase(name: "알림 시각이 지난 약속은 건너뜀") { f in
        let n = plan(data([event("치과", "15:00"), event("저녁", "19:00")]), now: "14:55"); sane(&f, n, now: "14:55")
        expect(&f, kinds(n, .event).map(\.body) == ["19:00 저녁 · 10분 뒤"], "got \(kinds(n, .event).map(\.body))")
    },
    NotifyCase(name: "끝낸 약속 · 8일 뒤 약속은 없음") { f in
        var done = event("끝", "15:00"); done.done = true
        let n = plan(data([done, event("먼 약속", "10:00", day: D0.adding(days: 7, calendar: seoulCal)), event("6일 뒤", "10:00", day: D0.adding(days: 6, calendar: seoulCal))])); sane(&f, n)
        expect(&f, kinds(n, .event).map(\.body) == ["10:00 6일 뒤 · 10분 뒤"], "got \(kinds(n, .event).map(\.body))")
    },
    NotifyCase(name: "매일 반복 약속 → 7일치, 빠진 날은 뺀다") { f in
        var it = event("스탠드업", "09:00", rule: .daily)
        it.exceptions = [D0.adding(days: 2, calendar: seoulCal)]
        let n = plan(data([it])); sane(&f, n)
        let e = kinds(n, .event)
        expect(&f, e.count == 6, "count \(e.count)")
        expect(&f, e.first?.id == "ud5.event.o:\(it.id.uuidString):2026-11-15", "id \(e.first?.id ?? "-")")
        expect(&f, e.last?.url == "udada://day/2026-11-21", "last \(e.last?.url ?? "-")")
    },
    NotifyCase(name: "매주 월 반복 약속 → 7일 안에 하나, 원본 lead 를 쓴다") { f in
        let n = plan(data([event("요가", "19:00", lead: 20, rule: .weekly([2]))])); sane(&f, n)
        let e = kinds(n, .event)
        expect(&f, e.count == 1 && e.first?.fire == at("18:40", 1), "got \(e.map(\.id))")
    },
    NotifyCase(name: "약속 알림 끔") { f in
        let n = plan(data([event("치과", "15:00")]) { $0.eventAlertOn = false }); sane(&f, n)
        expect(&f, n.isEmpty, "got \(n.map(\.id))")
    },
    NotifyCase(name: "걱정 시간 · 2개 → 오늘·내일 21:30") { f in
        let n = plan(data([Item(title: "월세", worry: true), Item(title: "건강검진", worry: true)])); sane(&f, n)
        let w = kinds(n, .worry)
        expect(&f, w.map(\.fire) == [at("21:30"), at("21:30", 1)], "fires")
        expect(&f, w.first?.title == "걱정 시간 · 2개", "title \(w.first?.title ?? "-")")
        expect(&f, w.first?.body == "10분만 보고 다시 내려놓자.", "body")
        expect(&f, w.first?.url == "udada://worry", "url")
    },
    NotifyCase(name: "걱정 상자 비었거나 꺼짐 → 없음") { f in
        var resolved = Item(title: "끝난 걱정", worry: true); resolved.done = true
        let a = plan(data([resolved])); sane(&f, a)
        let b = plan(data([Item(title: "월세", worry: true)]) { $0.worryOn = false }); sane(&f, b)
        expect(&f, a.isEmpty && b.isEmpty, "a \(a.map(\.id)) b \(b.map(\.id))")
    },
    NotifyCase(name: "하루 닫기 → 남은 일이 있으면 21:00") { f in
        let n = plan(data([todo("보고서", .afternoon)]) { $0.closeReminderOn = true; $0.digestOn = false }); sane(&f, n)
        let c = kinds(n, .close)
        expect(&f, c.map(\.id) == ["ud5.close.2026-11-15", "ud5.close.2026-11-16"], "ids \(c.map(\.id))")
        expect(&f, c.first?.fire == at("21:00") && c.first?.body == "남은 일 1개. 자리만 정하고 닫자.", "first \(c.first?.body ?? "-")")
        expect(&f, c.first?.url == "udada://close", "url")
    },
    NotifyCase(name: "하루 닫기: 꺼짐 · 다 끝냄 · 이미 닫음") { f in
        let off = plan(data([todo("보고서", .afternoon)]) { $0.digestOn = false }); sane(&f, off)
        let allDone = plan(data([todo("보고서", .afternoon, done: true)]) { $0.closeReminderOn = true }); sane(&f, allDone)
        var closed = data([todo("보고서", .afternoon)]) { $0.closeReminderOn = true }
        closed.closes = [CloseLog(day: D0, at: at("06:00"), done: 1, tomorrow: 0, later: 0, dropped: 0)]
        let c = kinds(plan(closed), .close).map(\.id)
        expect(&f, off.isEmpty, "off \(off.map(\.id))")
        expect(&f, kinds(allDone, .close).isEmpty, "allDone \(allDone.map(\.id))")
        expect(&f, c == ["ud5.close.2026-11-16"], "closed \(c)")
    },
    NotifyCase(name: "집중 필터: 걱정 끄기") { f in
        let d = data([Item(title: "월세", worry: true), event("치과", "15:00")])
        let n = plan(d, focus: FocusFilterState(muteWorry: true)); sane(&f, n)
        expect(&f, kinds(n, .worry).isEmpty && kinds(n, .event).count == 1, "got \(n.map(\.id))")
    },
    NotifyCase(name: "집중 필터: 묶음 알림만") { f in
        let d = data([Item(title: "월세", worry: true), event("치과", "15:00"), todo("보고서", .afternoon)]) { $0.closeReminderOn = true }
        let n = plan(d, focus: FocusFilterState(digestOnly: true)); sane(&f, n)
        expect(&f, !n.isEmpty && n.allSatisfy { $0.kind == .digest }, "got \(n.map(\.id))")
        expect(&f, FocusFilterState(hideLater: true).allows(.event), "hideLater 는 알림과 무관")
    },
    NotifyCase(name: "60개 상한, 가까운 순") { f in
        var items: [Item] = []
        for day in 0..<7 { for h in 8..<20 { items.append(event("약속\(day)-\(h)", String(format: "%02d:00", h), day: D0.adding(days: day, calendar: seoulCal))) } }
        let n = plan(data(items)); sane(&f, n)
        expect(&f, n.count == 60, "count \(n.count)")
        expect(&f, n.first?.fire == at("07:50"), "first \(String(describing: n.first?.fire))")
        expect(&f, !n.contains { $0.fire >= at("00:00", 6) }, "too far kept")
    },
    NotifyCase(name: "같은 데이터 → 같은 id (다시 걸면 덮어씀)") { f in
        let d = data([todo("보고서", .afternoon), event("치과", "15:00"), Item(title: "월세", worry: true)]) { $0.closeReminderOn = true }
        let a = plan(d).map(\.id), b = plan(d).map(\.id)
        expect(&f, a == b && !a.isEmpty, "a \(a) b \(b)")
        expect(&f, Set(plan(d).map(\.kind)) == Set(PlannedNote.Kind.allCases), "모든 종류")
    },
]
