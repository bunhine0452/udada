import AppKit
import ServiceManagement
import SwiftUI

/// 우다다 Mac: 메뉴 막대에 '지금' 한 줄, 어디서나 ⌃⌥Space 로 한 줄 넣기, 창에는 하루 한 장.
/// 데이터는 내 iCloud 로 iPhone 과 맞춘다 (CloudSync).
@main
struct UdadaMacApp: App {
    @NSApplicationDelegateAdaptor(MacDelegate.self) private var delegate
    @State private var store: Store
    @State private var ticker: Ticker

    init() {
        let s = Store()
        let t = Ticker()
        _store = State(initialValue: s)
        _ticker = State(initialValue: t)
        MacWiring.ticker = t
        MacWiring.connect(s)
    }

    var body: some Scene {
        Window("우다다", id: "main") {
            DayWindow()
                .id(store.settings.theme) // 테마가 바뀌면 통째로 다시 그린다
                .environment(store)
                .environment(ticker)
                .preferredColorScheme(scheme)
                .onOpenURL { store.open($0) }
        }
        .defaultSize(width: 1080, height: 700)
        // 시스템 제목 막대를 없애고 종이가 창 꼭대기까지 — 신호등 버튼만 종이 위에 뜬다
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("한 줄 넣기") { QuickAddPanel.shared.toggle(store: store, ticker: ticker) }
                    .keyboardShortcut("n")
                Button("쏟아내기") { store.cover = .dump }
                    .keyboardShortcut("d")
                Button("Apple Intelligence 둘러보기") { store.showAITour = true }
                Button("말로 하기") { store.cover = .find }
                    .keyboardShortcut("f")
                Button("말로 시키기") { store.cover = .find }
                    .keyboardShortcut("k")
            }
            CommandGroup(after: .toolbar) {
                Button("오늘로") { store.selectedDay = store.today }
                    .keyboardShortcut("t")
                Button("전날") { store.selectedDay = store.selectedDay.adding(days: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("다음 날") { store.selectedDay = store.selectedDay.adding(days: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("지금 맞추기") { CloudSync.shared.refresh() }
                    .keyboardShortcut("r")
                Divider()
                Picker("테마", selection: Binding(get: { store.settings.theme }, set: { t in store.setSettings { $0.theme = t } })) {
                    ForEach(ThemeID.allCases) { Text($0.name).tag($0) }
                }
            }
        }

        MenuBarExtra {
            MenuPanel()
                .id(store.settings.theme)
                .environment(store)
                .environment(ticker)
                .preferredColorScheme(scheme)
        } label: {
            MenuLabel(store: store, ticker: ticker)
        }
        .menuBarExtraStyle(.window)
    }

    private var scheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// 앱이 뜰 때 한 번: 맞추기 · 전역 단축키 · 기기 달력
@MainActor
enum MacWiring {
    static var hotKey: HotKey?
    static var ticker: Ticker?

    static func connect(_ store: Store) { CloudSync.connect(store) }
}

final class MacDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // iCloud 가 바뀌면 조용히 깨워 준다
        NSApplication.shared.registerForRemoteNotifications()
        // 확인용(-udWindow 1440x900): 스토어 스크린샷 규격에 맞게 창 크기를 정한다
        let launch = ProcessInfo.processInfo.arguments
        if let i = launch.firstIndex(of: "-udWindow"), i + 1 < launch.count {
            let wh = launch[i + 1].split(separator: "x").compactMap { Double($0) }
            if wh.count == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    for w in NSApp.windows where w.isVisible && w.styleMask.contains(.titled) && w.frame.width > 500 {
                        let o = w.screen?.visibleFrame.origin ?? .zero
                        w.setFrame(NSRect(x: o.x + 20, y: o.y + 20, width: wh[0], height: wh[1]), display: true, animate: false)
                    }
                }
            }
        }
        // 서비스 메뉴: 아무 앱에서나 글을 고르고 '우다다로 보내기'
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        Task { @MainActor in
            guard let store = Store.live else { return }
            if !ProcessInfo.processInfo.arguments.contains("-udNoHotKey") {
                MacWiring.hotKey = HotKey { Task { @MainActor in QuickAddPanel.shared.toggle(store: store, ticker: MacWiring.ticker ?? Ticker()) } }
            }
            CalendarService.shared.refresh(store)
            if store.settings.aiOn { Brain.shared.prewarm() }
            Self.runScript(store)
            Self.runEval()
            Self.runPhotoEval()
        }
    }

    /// 사진 보기 재기: -udEvalPhotos <폴더(labels.json + png)> <결과.json> — 그림마다 글자 인식만 쓴 줄과 모델이 본 줄을 같이 적는다
    @MainActor private static func runPhotoEval() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-udEvalPhotos"), i + 2 < args.count,
              let raw = try? Data(contentsOf: URL(fileURLWithPath: args[i + 1] + "/labels.json")),
              let sets = try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
        let now = f.date(from: "2026-11-16T10:00")!
        func parsed(_ lines: [String]) -> [[String: Any]] {
            lines.map { l in
                let p = Parser.parse(l, now: now)
                return ["line": l, "title": p.title, "month": p.day?.m ?? 0, "day": p.day?.d ?? 0, "time": p.time ?? -1]
            }
        }
        Task { @MainActor in
            var out: [[String: Any]] = []
            for set in sets {
                guard let file = set["file"] as? String,
                      let img = NSImage(contentsOfFile: args[i + 1] + "/" + file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                let ocr = await TextScan.recognize(img)
                let t0 = Date()
                let seen = await Brain.shared.readPhoto(img, ocr: ocr)
                out.append(["file": file, "seconds": Date().timeIntervalSince(t0), "ai": seen.fromAI, "canSee": Brain.canSeeImages(),
                            "ocr": parsed(ocr), "model": parsed(seen.lines)])
            }
            let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
            try? data?.write(to: URL(fileURLWithPath: args[i + 2]))
            exit(0)
        }
    }

    /// 품질 재기: -udEval <묶음.json> <결과.json> — 실제 기기 안 모델로 쏟아내기를 나누고 걸린 시간과 카드를 적은 뒤 끝낸다 (Eval/run.sh)
    @MainActor private static func runEval() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-udEval"), i + 2 < args.count,
              let raw = try? Data(contentsOf: URL(fileURLWithPath: args[i + 1])),
              let sets = try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
        let now = f.date(from: "2026-11-16T10:00")! // 월요일 아침으로 고정
        Task { @MainActor in
            var out: [[String: Any]] = []
            let status = "\(Brain.shared.status)"
            for set in sets {
                if let text = set["raw"] as? String, args.contains("-udEvalStream") {
                    // 흘려 받기: 목록이 올 때마다 걸린 시간과 '모델이 다듬은 카드 수'를 적는다
                    let t0 = Date()
                    var ticks: [[String: Any]] = []
                    var last: [DumpSuggestion] = []
                    for await list in Brain.shared.organizeStream(text, today: DayKey(now), now: now) {
                        ticks.append(["t": Date().timeIntervalSince(t0), "cards": list.count, "ai": list.filter(\.fromAI).count])
                        last = list
                    }
                    out.append(["raw": text, "seconds": Date().timeIntervalSince(t0), "status": status, "ticks": ticks,
                                "cards": last.map { ["text": $0.text, "bin": $0.bin.rawValue, "ai": $0.fromAI, "day": $0.day?.description ?? ""] }])
                    continue
                }
                if let cmd = set["cmd"] as? String {
                    // 말로 시키기: 고정한 예시 하루에 대고 계획만 세운다 (적용은 안 한다)
                    let t0 = Date()
                    let plan = await Brain.shared.plan(cmd, data: Seed.day(now: now, keep: AppData()), now: now)
                    out.append(["cmd": cmd, "seconds": Date().timeIntervalSince(t0), "status": status,
                                "steps": plan.steps.map { s in
                                    ["kind": s.kind.rawValue, "target": s.target?.title ?? "", "ok": s.ok, "ai": s.fromAI, "later": s.later,
                                     "dayOffset": s.day.map { DayKey(now).days(to: $0) } ?? -99, "time": s.time ?? -1, "line": s.line] as [String: Any]
                                }])
                    continue
                }
                if let big = set["big"] as? String {
                    // 쪼개기: 걸음과 날에 놓은 결과 (마감은 묶음이 준 dueOffset, 없으면 날짜 없는 일)
                    let t0 = Date()
                    let b = await Brain.shared.breakdown(big, now: now)
                    let secs = Date().timeIntervalSince(t0)
                    let today = DayKey(now)
                    let due = (set["dueOffset"] as? Int).map { today.adding(days: $0) }
                    let pace = BreakRules.paces(today: today, due: due)[0]
                    let placed = BreakRules.place(b?.steps ?? [], pace: pace, today: today, due: due, nowPart: .morning, part: .afternoon)
                    out.append(["big": big, "seconds": secs, "status": status, "ai": b?.fromAI ?? false, "known": BreakRules.knownSteps(for: b?.subject ?? "") != nil, "subject": b?.subject ?? "",
                                "steps": b?.steps ?? [], "offsets": placed.map { today.days(to: $0.day) }, "dueOffset": set["dueOffset"] as? Int ?? -1])
                    continue
                }
                if let audio = set["audio"] as? String {
                    // 녹음에서 할 일 찾기: 파일을 받아쓰고 → 밖에서 받기. 받아쓴 글도 적어 둔다.
                    func parsed(_ lines: [String]) -> [[String: Any]] {
                        lines.map { l in
                            let p = Parser.parse(l, now: now)
                            return ["line": l, "off": p.day.map { DayKey(now).days(to: $0) } as Any? ?? NSNull(), "time": p.time ?? -1]
                        }
                    }
                    let dir = URL(fileURLWithPath: args[i + 1]).deletingLastPathComponent()
                    let t0 = Date()
                    var heard = "", fail = ""
                    do { heard = try await AudioNotes.transcribe(dir.appendingPathComponent("audio/" + audio)) } catch { fail = "\(error)" }
                    let t1 = Date()
                    let r = await Brain.shared.capture(heard, now: now)
                    out.append(["msg": set["msg"] as? String ?? audio, "heard": heard, "fail": fail, "hearSeconds": t1.timeIntervalSince(t0),
                                "seconds": Date().timeIntervalSince(t0), "status": status, "ai": r.fromAI,
                                "lines": parsed(r.lines), "rule": parsed(CaptureRules.lines(heard, now: now))])
                    continue
                }
                if let msg = set["msg"] as? String {
                    // 밖에서 받기: 뽑은 줄을 Parser 로 읽어 날짜(오늘부터 며칠)·시각까지 적는다. 규칙만의 줄도 같이.
                    func parsed(_ lines: [String]) -> [[String: Any]] {
                        lines.map { l in
                            let p = Parser.parse(l, now: now)
                            return ["line": l, "off": p.day.map { DayKey(now).days(to: $0) } as Any? ?? NSNull(), "time": p.time ?? -1]
                        }
                    }
                    let t0 = Date()
                    let r = await Brain.shared.capture(msg, now: now)
                    out.append(["msg": msg, "seconds": Date().timeIntervalSince(t0), "status": status, "ai": r.fromAI,
                                "lines": parsed(r.lines), "rule": parsed(CaptureRules.lines(msg, now: now))])
                    continue
                }
                if let q = set["sense"] as? String {
                    // 뜻으로 찾기: 고정한 기록 50개(Eval/sense-records.json)에 대고 낱말로 찾은 것과 뜻으로 넓힌 것을 같이 적는다
                    let dir = URL(fileURLWithPath: args[i + 1]).deletingLastPathComponent()
                    let recs = (try? JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("sense-records.json"))) as? [[String: Any]]) ?? []
                    var data = AppData()
                    let today = DayKey(now)
                    data.items = recs.map { r in
                        var it = Item(title: r["t"] as? String ?? "", day: (r["off"] as? Int).map { today.adding(days: $0) }, time: r["time"] as? Int,
                                      worry: r["worry"] as? Bool ?? false)
                        it.done = r["done"] as? Bool ?? false
                        return it
                    }
                    if args.contains("-udEvalVotes") {
                        // 연구용: 순서 다섯 가지로 물은 표 수와, 표를 받은 이름마다 하나씩 따로 물은 답을 적는다 (기준은 밖에서 고른다)
                        let first = await Brain.shared.find(q, data: data, today: today)
                        let titles = FindRules.candidates(first.query, data: data, today: today)
                        let votes = (try? await Brain.aiPickVotes(q, titles: titles)) ?? [:]
                        var fits: [String: Bool] = [:]
                        var off: [String: Bool] = [:]
                        for t in votes.keys where votes[t, default: 0] >= 2 {
                            fits[t] = (try? await Brain.aiFits(q, title: t)) ?? false
                            off[t] = (try? await Brain.aiUnrelated(q, title: t)) ?? true
                        }
                        out.append(["sense": q, "status": status, "words": first.query.words, "literal": Array(Set(first.hits.map(\.title))),
                                    "votes": votes, "fits": fits, "off": off])
                        continue
                    }
                    let t0 = Date()
                    let first = await Brain.shared.find(q, data: data, today: today)
                    let more = await Brain.shared.findMore(q, answer: first, data: data, today: today)
                    let uniq: ([FindHit]) -> [String] = { Array(Set($0.map(\.title))).sorted() }
                    out.append(["sense": q, "seconds": Date().timeIntervalSince(t0), "status": status, "ai": more != nil, "words": first.query.words,
                                "candidates": FindRules.candidates(first.query, data: data, today: today).count,
                                "literal": uniq(first.hits), "final": uniq((more ?? first).hits), "line": (more ?? first).line])
                    continue
                }
                if let q = set["q"] as? String {
                    // 말로 찾기: 물음 읽기만 잰다
                    let t0 = Date()
                    let r = await Brain.shared.readQuestion(q)
                    out.append(["q": q, "seconds": Date().timeIntervalSince(t0), "status": status, "ai": r.fromAI,
                                "words": r.words, "span": r.span.rawValue, "state": r.state.rawValue, "kind": r.kind.rawValue])
                    continue
                }
                guard let text = set["raw"] as? String else { continue }
                let t0 = Date()
                let cards = await Brain.shared.organize(text, today: DayKey(now), now: now)
                out.append(["raw": text, "seconds": Date().timeIntervalSince(t0), "status": status,
                            "cards": cards.map { ["text": $0.text, "bin": $0.bin.rawValue, "ai": $0.fromAI, "day": $0.day?.description ?? ""] }])
            }
            let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
            try? data?.write(to: URL(fileURLWithPath: args[i + 2]))
            exit(0)
        }
    }

    /// 확인용: -udRun add:내일 3시 치과 · done:치과 · delete:치과 — 사용자가 앱 안에서 한 것과 같은 길로 바꾼다
    @MainActor private static func runScript(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        for (i, a) in args.enumerated() where a == "-udRun" && i + 1 < args.count {
            let parts = args[i + 1].split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let hit = store.data.items.first { $0.title.contains(parts[1]) }
            switch parts[0] {
            case "add": store.quickAdd(parts[1])
            case "done": if let hit { store.change { $0.setDone(.item(hit.id), true, now: store.now) } }
            case "delete": if let hit { store.change { $0.remove(.item(hit.id)) } }
            case "dump": MacDump.seedText = parts[1]; store.cover = .dump
            case "find": store.pendingAddText = parts[1]; store.cover = .find
            case "split":
                // 그 이름의 일이 있으면 그 일의 날을 마감으로, 없으면 글에서 읽은 날
                let p = Parser.parse(parts[1], now: store.now, parts: store.settings.parts)
                let hit = store.data.items.first { $0.title == parts[1] && !$0.done }
                store.splitting = SplitRequest(title: parts[1], due: hit?.day ?? p.day, part: hit?.part ?? .afternoon)
            case "photo": MacDump.seedImage = parts[1]; store.cover = .dump
            case "capture": MacDump.seedCapture = parts[1]; store.cover = .dump
            case "audio": MacDump.seedAudio = parts[1]; store.cover = .dump
            case "focusitem": if let e = store.sheet(for: store.today).bands.flatMap(\.todos).first(where: { $0.title.contains(parts[1]) }) { store.startFocus(e) }
            case "focus": store.startFocus(nil)
            case "stopfocus": store.stopFocus(finished: true)
            default: break
            }
        }
    }

    /// 서비스 메뉴 '우다다로 보내기' (Info.plist 의 NSServices): 고른 글에서 챙길 일을 뽑아 비우기 창에 올린다
    @objc func captureService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { @MainActor in
            guard let store = Store.live else { return }
            MacDump.seedCapture = text
            store.cover = nil
            NSApp.activate(ignoringOtherApps: true)
            for w in NSApp.windows where w.canBecomeMain { w.makeKeyAndOrderFront(nil); break }
            store.cover = .dump
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            guard let store = Store.live else { return }
            store.settleNow()
            CalendarService.shared.refresh(store)
            CloudSync.shared.refresh()
        }
    }

    /// 창을 닫아도 메뉴 막대에 남는다
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }
}

// MARK: - 메뉴 막대 글자

/// ☐ 치과까지 1시간 20분  ·  집중 중이면 ● 보고서 12:40
struct MenuLabel: View {
    var store: Store
    var ticker: Ticker

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content.task {
            guard !MenuLabel.opened else { return }
            MenuLabel.opened = true
            try? await Task.sleep(for: .milliseconds(300))
            if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) { openWindow(id: "main") }
        }
    }
    private static var opened = false

    /// 표식은 앱 아이콘과 같은 「지금 우」(한 색 템플릿). 글자는 꼭 필요한 것만: 다음 약속까지 · 남은 개수 · 집중 시계.
    @ViewBuilder private var content: some View {
        let _ = ticker.minute
        Image("MenuMark")
        if let a = store.data.activeFocus {
            let _ = ticker.second
            let _ = (ticker.perSecond = true)
            Text(clockText(Int(Date().timeIntervalSince(a.started))))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        } else {
            let _ = (ticker.perSecond = false)
            let label = Self.text(store.sheet(for: store.today))
            if !label.isEmpty { Text(label).font(.system(size: 12, weight: .medium).monospacedDigit()) }
        }
    }

    /// 다음 약속이 3시간 안이면 "치과 1:20", 아니면 남은 할 일 수
    static func text(_ sheet: DaySheet) -> String {
        if let line = sheet.now, let next = line.next, line.gap <= 180 {
            return short(next.title, 8) + " " + (line.gap >= 60 ? "\(line.gap / 60):" + String(format: "%02d", line.gap % 60) : "\(line.gap)분")
        }
        return sheet.openTodos == 0 ? "" : "\(sheet.openTodos)"
    }
}

private func short(_ s: String, _ n: Int) -> String { s.count > n ? String(s.prefix(n)) + "…" : s }

// MARK: - 로그인할 때 열기

@MainActor
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
    }
}
