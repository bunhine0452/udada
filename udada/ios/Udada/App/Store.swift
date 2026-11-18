import SwiftUI
import WidgetKit

/// 앱 전체 상태. 값(AppData)을 바꾸면 바로 파일에 쓰고 위젯·알림을 새로 고친다.
/// 지우기·옮기기 같은 것은 확인 창 대신 '되돌리기' 토스트로 (DAY.md).
@MainActor
@Observable
final class Store {
    private(set) var data: AppData
    /// 기기 달력 약속 (CalendarService 가 채운다)
    var external: [Entry] = []
    var toast: Toast?
    /// 탭 이동·날짜 선택 같은 화면 상태
    var tab: AppTab = .today
    var selectedDay: DayKey
    /// 전체 화면 흐름 (식히기·집중·하루 닫기·비우기)
    var cover: Cover?

    /// 딥링크·단축어가 넘긴 넣기 줄 글 / 커서 요청 / 식히기 바로 시작 / 말로 쏟아내기 / 설정 열기
    var pendingAddText = ""
    var addFocusRequest = 0
    var restStart: RestKind?
    /// 비우기를 어떻게 시작하나 (쓰기 · 말 · 사진)
    var dumpMode: DumpMode = .text
    var showSettings = false
    /// 쪼개기 시트 (Mac — 줄 메뉴에서 연다)
    var splitting: SplitRequest?
    /// 받은 약속에 답장을 띄운다
    var reply: ReplyRequest?
    /// 한 주 풀기를 띄운다 (말이 있으면 그 말로 바로 시작)
    var replan: ReplanRequest?
    /// Apple Intelligence 둘러보기(움직이는 장면)를 띄운다
    var showAITour = false
    /// 공유로 밖에서 받아 둔 것의 수 (Inbox). 0 이면 카드가 안 보인다.
    var inboxCount = 0
    /// 비우기 화면이 열릴 때 받아 둔 것을 꺼내 읽으라는 표시
    var takeInbox = false

    /// 지금 떠 있는 Store (App Intents·알림 라우터가 앱 안에서 바로 쓰도록)
    static private(set) weak var live: Store?

    private var undoSnapshot: AppData?
    private var toastTask: Task<Void, Never>?
    let clockOffset: TimeInterval

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-udReset") { DataFile.reset(); try? FileManager.default.removeItem(at: DataFile.directory.appendingPathComponent("udada-sync.json")) }
        var d = DataFile.load()
        var offset: TimeInterval = 0
        if let i = args.firstIndex(of: "-udNow"), i + 1 < args.count {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
            if let fixed = f.date(from: args[i + 1]) { offset = fixed.timeIntervalSinceNow }
        }
        clockOffset = offset
        let now = Date().addingTimeInterval(offset)
        var dirty = args.contains("-udReset")
        if args.contains("-udSeed") { d = Seed.day(now: now, keep: d); dirty = true }
        // 확인용(-udInbox <글>): 공유 확장이 넣은 것처럼 받아 둔 것에 글 하나를 둔다. -udStuck <이름>: 그 일을 네 번 넘어온 것으로.
        if args.contains("-udReset") { Inbox.remove(Inbox.items()) }
        if let i = args.firstIndex(of: "-udInbox"), i + 1 < args.count { Inbox.put(text: args[i + 1].precomposedStringWithCanonicalMapping) }
        if let i = args.firstIndex(of: "-udStuck"), i + 1 < args.count, let k = d.items.firstIndex(where: { $0.title == args[i + 1].precomposedStringWithCanonicalMapping }) { d.items[k].moves = 4; dirty = true }
        if args.contains("-udSkipIntro") && !d.seenIntro { d.seenIntro = true; dirty = true }
        if args.contains("-udIntro") && d.seenIntro { d.seenIntro = false; dirty = true }
        // -udNoAI : UI 테스트가 기기 모델 속도에 흔들리지 않게 규칙만 쓴다
        if args.contains("-udNoAI") && d.settings.aiOn { d.settings.aiOn = false; dirty = true }
        let beforeSettle = d.items
        d.settle(now: now)
        if d.items != beforeSettle { dirty = true }
        data = d
        selectedDay = DayKey(now)
        inboxCount = Inbox.items().count
        showAITour = args.contains("-udTourPage") // 확인용: 둘러보기를 바로 띄운다
        Haptic.enabled = d.settings.haptics
        // -udTheme sand : 스크린샷·확인용으로 테마를 정해서 시작
        if let i = args.firstIndex(of: "-udTheme"), i + 1 < args.count, let t = ThemeID(rawValue: args[i + 1]) { data.settings.theme = t }
        Ink.theme = data.settings.theme
        // 실행할 때마다 쓰지 않는다 — 바뀐 게 있을 때만 (첫 화면을 빨리)
        if dirty { DataFile.save(d) }
        Store.live = self
        // -udOpen udada://dump : 스크린샷·UI 테스트용으로 그 화면에서 시작
        if let i = args.firstIndex(of: "-udOpen"), i + 1 < args.count, let u = URL(string: args[i + 1]) { open(u) }
    }

    var now: Date { Date().addingTimeInterval(clockOffset) }
    var today: DayKey { DayKey(now) }
    var settings: Settings { data.settings }

    func sheet(for day: DayKey) -> DaySheet { DayLogic.sheet(for: day, data: data, external: external, now: now) }

    // MARK: 바꾸기

    /// 값을 바꾸고 저장. undo 문구를 주면 되돌리기 토스트를 띄운다.
    func change(undo message: String? = nil, _ body: (inout AppData) -> Void) {
        let before = data
        body(&data)
        persist()
        if let message {
            undoSnapshot = before
            show(message, undo: true)
        }
    }

    func undo() {
        guard let s = undoSnapshot else { return }
        data = s
        undoSnapshot = nil
        persist()
        toast = nil
        Haptic.soft()
    }

    func setSettings(_ body: (inout Settings) -> Void) {
        body(&data.settings)
        Haptic.enabled = data.settings.haptics
        Ink.theme = data.settings.theme
        persist()
    }

    /// 다른 프로세스(위젯)가 바꾼 파일을 다시 읽는다
    func reload() {
        var d = DataFile.load()
        d.settle(now: now)
        data = d
        inboxCount = Inbox.items().count
    }

    /// 다른 기기에서 온 것을 합친 결과를 받아들인다 (iCloud 로 다시 보내지 않는다)
    func adopt(_ merged: AppData) {
        var d = merged
        d.settle(now: now)
        guard d.items != data.items || d.activeFocus != data.activeFocus || d.settings != data.settings
            || d.rests != data.rests || d.dumps != data.dumps || d.closes != data.closes || d.focus != data.focus else { return }
        data = d
        undoSnapshot = nil
        DataFile.save(d)
        WidgetCenter.shared.reloadAllTimelines()
        Notifier.reschedule(d, now: now)
        for hook in Store.afterPersist { hook(d) }
    }

    func settleNow() {
        let before = data.items
        data.settle(now: now)
        if before != data.items { persist() }
    }

    /// 저장 뒤에 부를 것 (Spotlight 색인 등 — 앱 시작 때 등록)
    static var afterPersist: [@MainActor (AppData) -> Void] = []

    private func persist() {
        DataFile.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        Notifier.reschedule(data, now: now)
        for hook in Store.afterPersist { hook(data) }
        Store.afterUserChange?(data)
    }

    /// 사용자가 앱 안에서 바꾼 직후에만 (기기 맞추기 — 지우기도 여기서만 퍼진다)
    static var afterUserChange: (@MainActor (AppData) -> Void)?

    // MARK: 토스트

    func show(_ message: String, undo: Bool = false) {
        toast = Toast(message: message, canUndo: undo)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(undo ? 5 : 2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
        }
    }

    // MARK: 자주 쓰는 동작

    func toggleDone(_ e: Entry) {
        guard !e.isExternal else { return }
        let wasDone = e.done
        change { $0.toggleDone(e.source, now: now) }
        if !wasDone { Haptic.success() } else { Haptic.tap() }
    }

    func move(_ e: Entry, to day: DayKey?, part: Part? = nil) {
        let message: String
        if let day {
            message = Fmt.ro(Fmt.day(day, today: today) + (part.map { " " + $0.name } ?? "")) + " 옮겼어"
        } else {
            message = "나중에 함에 넣었어"
        }
        change(undo: message) { $0.move(e.source, to: day, part: part) }
        Haptic.tap()
    }

    func delete(_ e: Entry, wholeSeries: Bool = false) {
        change(undo: wholeSeries ? "반복을 지웠어" : "지웠어") { $0.remove(e.source, wholeSeries: wholeSeries) }
        Haptic.tap()
    }

    func pin(_ e: Entry) {
        change { $0.pin(e.source, day: e.day) }
        Haptic.tap()
    }

    func toWorry(_ e: Entry) {
        change(undo: "걱정 상자에 넣었어") { $0.toWorry(e.source) }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var canUndo: Bool
}

enum AppTab: Hashable { case today, calendar, mind, records }

enum DumpMode: Hashable { case text, voice, photo }

/// 받은 약속에 답장을 여는 요청: 받은 글 (받아 둔 것에서 왔으면 그 파일 — 답하면 치운다)
struct ReplyRequest: Identifiable, Hashable {
    var id = UUID()
    var text: String
    var source: URL? = nil
}

/// 한 주 풀기를 여는 요청: 사용자가 한 말 (비어 있으면 화면에서 적는다)
struct ReplanRequest: Identifiable, Hashable {
    var id = UUID()
    var text = ""
}

enum Cover: Identifiable, Hashable {
    case rest
    case focus(Entry?)
    case close
    case dump
    case worry
    case gate
    /// 말로 찾기
    case find
    var id: String {
        switch self {
        case .rest: "rest"
        case .focus(let e): "focus" + (e?.id ?? "")
        case .close: "close"
        case .dump: "dump"
        case .worry: "worry"
        case .gate: "gate"
        case .find: "find"
        }
    }
}

/// 실행 인자 (UI 테스트·스크린샷용)
enum Launch {
    /// -udSpeed 60 : 식히기·집중 시계 배속
    static var speed: Double {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-udSpeed"), i + 1 < a.count, let v = Double(a[i + 1]) { return max(1, v) }
        return 1
    }
    static var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-udReset") }
}

/// 예시로 채운 하루 (스크린샷·UI 테스트·'예시로 채워 보기')
enum Seed {
    static func day(now: Date, keep: AppData) -> AppData {
        var d = keep
        let t = DayKey(now)
        func mk(_ title: String, _ day: DayKey?, _ part: Part, time: Int? = nil, dur: Int = 30, ago: Int = 0) -> Item {
            Item(title: title, day: day, part: part, time: time, duration: dur, created: now.addingTimeInterval(TimeInterval(-ago * 86400) + Double(d.items.count)))
        }
        var items: [Item] = [
            mk("메일 답장", t, .morning, dur: 15),
            mk("팀 회의", t, .morning, time: 600, dur: 60),
            mk("보고서 초안", t, .afternoon, dur: 30),
            mk("택배 보내기", t, .afternoon, dur: 15),
            mk("치과", t, .afternoon, time: 900, dur: 60),
            mk("저녁 약속", t, .evening, time: 1170, dur: 90),
            mk("빨래 개기", t, .evening, dur: 15),
            mk("장보기", t.adding(days: 1), .afternoon),
            mk("여권 갱신", nil, .afternoon, ago: 12),
            mk("책장 정리", nil, .afternoon, ago: 3),
        ]
        var water = Item(title: "물 한 잔", day: t, part: .morning, duration: 5, repeatRule: .daily)
        water.created = now.addingTimeInterval(-86400 * 5)
        items.append(water)
        items.append(Item(title: "다음 달 월세 오르면 어떡하지", worry: true))
        for i in items.indices { items[i].created = items[i].created.addingTimeInterval(Double(i)) }
        d.items = items
        return d
    }
}
