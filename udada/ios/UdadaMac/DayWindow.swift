import SwiftUI

/// 하루 한 장 창: 아침 · 낮 · 저녁이 종이 시간표처럼 나란히, 오른쪽에 나중에 함과 걱정 상자.
struct DayWindow: View {
    @Environment(Store.self) private var store
    @Environment(Ticker.self) private var ticker
    @State private var text = ""
    @FocusState private var addFocused: Bool

    private var day: DayKey { store.selectedDay }

    var body: some View {
        @Bindable var store = store
        let _ = ticker.minute
        let sheet = store.sheet(for: day)
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                header(sheet)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                VStack(alignment: .leading, spacing: 12) {
                    addRow
                    if let a = store.data.activeFocus {
                        FocusStrip(active: a)
                    } else if let line = sheet.now {
                        NowCard(line: line).padding(14).paper(12)
                    }
                    if sheet.isToday, let it = store.data.stuck(today: store.today) {
                        MacStuck(item: it).transition(Motion.rise)
                    }
                    if !sheet.allDay.isEmpty { allDay(sheet.allDay) }
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(sheet.bands) { BandColumn(band: $0, isToday: sheet.isToday) }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    // 다 끝낸 날의 한 줄은 세 칸 아래에 — 위에 끼어들어 칸을 밀어 내리지 않게
                    if sheet.isToday, sheet.allTodosDone {
                        HStack(spacing: 10) {
                            BreathDot(size: 8)
                            Text("오늘 한 장은 여기까지야.").font(Typo.serif(15)).foregroundStyle(Ink.text)
                            Text("남은 시간은 채우지 않아도 돼.").font(.system(size: 12)).foregroundStyle(Ink.text2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).frame(height: 40).paper(12)
                        .transition(.opacity)
                    }
                }
                .calm(Motion.soft, value: sheet.allTodosDone)
                .calm(Motion.soft, value: store.data.stuck(today: store.today)?.id)
                footer
            }
            .padding(.leading, 26)
            .padding(.trailing, 22)
            // 오른쪽 칸은 창 꼭대기부터 바닥까지 — 종이를 한 번 접은 것처럼 톤만 다르게
            SideRail()
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .frame(width: 256)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Ink.fill.opacity(0.55))
                .overlay(alignment: .leading) { Rectangle().fill(Ink.rule).frame(width: 1) }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 860, minHeight: 560)
        .background(Ink.ground)
        .overlay(alignment: .bottom) {
            if let t = store.toast { MacToast(toast: t).padding(.bottom, 46) }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
        .sheet(isPresented: Binding(get: { store.cover == .dump }, set: { if !$0 { store.cover = nil } })) {
            MacDump().environment(store)
        }
        .sheet(isPresented: Binding(get: { store.cover == .find }, set: { if !$0 { store.cover = nil } })) {
            MacFind().environment(store)
        }
        .sheet(item: Binding(get: { store.splitting }, set: { store.splitting = $0 })) { r in
            MacBreakdown(request: r).environment(store)
        }
        .sheet(isPresented: Binding(get: { store.showAITour }, set: { store.showAITour = $0 })) {
            AITour(onTry: { what in
                store.showAITour = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    switch what {
                    case .add: store.addFocusRequest += 1
                    case .dump: store.cover = .dump
                    case .find: store.cover = .find
                    }
                }
            }, onClose: { store.showAITour = false })
            .frame(width: 520, height: 760)
        }
        // 처음 열었을 때: 쓰는 법 네 쪽
        .sheet(isPresented: Binding(get: { !store.data.seenIntro || store.showSettings }, set: { _ in })) {
            MacWelcome().environment(store).environment(ticker)
        }
        .onChange(of: store.addFocusRequest) { _, _ in
            text = store.pendingAddText
            addFocused = true
        }
        // 보고 있는 날을 다른 기기가 이어 열 수 있게 (Handoff)
        .userActivity(Continuity.dayActivity, isActive: true) { a in
            Continuity.fill(a, day: day, today: store.today)
        }
        .onContinueUserActivity(Continuity.dayActivity) { a in
            if let d = Continuity.day(from: a) { store.selectedDay = d }
        }
    }

    // MARK: 머리

    private func header(_ sheet: DaySheet) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            Text("\(day.m)월 \(day.d)일")
                .font(Typo.serif(34))
                .foregroundStyle(Ink.text)
                .lineLimit(1)
                .fixedSize()
            Text(Fmt.weekday[day.weekday()] + "요일" + (sheet.isToday ? " · 오늘" : ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sheet.isToday ? Ink.accent : Ink.text2)
                .lineLimit(1)
                .fixedSize()
            if day != store.today {
                Button("오늘로") { store.selectedDay = store.today }
                    .buttonStyle(BarButton())
                    .transition(.opacity)
            }
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                Button { store.selectedDay = day.adding(days: -7) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(BarButton(square: true)).help("지난주")
                WeekStrip()
                Button { store.selectedDay = day.adding(days: 7) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(BarButton(square: true)).help("다음 주")
            }
            .alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 8 }
        }
        .animation(.easeOut(duration: 0.15), value: day == store.today)
    }

    private func allDay(_ entries: [Entry]) -> some View {
        HStack(spacing: 6) {
            Text("종일").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.text3)
            ForEach(entries) { e in
                Text(e.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.fill))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            SyncLine(on: store.settings.syncOn)
            Menu {
                Picker("테마", selection: Binding(get: { store.settings.theme }, set: { t in store.setSettings { $0.theme = t } })) {
                    ForEach(ThemeID.allCases) { Text("\($0.name) — \($0.note)").tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 5) {
                    ThemeSwatch(theme: store.settings.theme, size: 14)
                    Text(store.settings.theme.name).font(.system(size: 11)).foregroundStyle(Ink.text3)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("테마 바꾸기")
            .accessibilityIdentifier("footer.theme")
            Spacer()
            HStack(spacing: 4) {
                KeyCap(text: "⌃"); KeyCap(text: "⌥"); KeyCap(text: "Space")
                Text("어디서나 한 줄 넣기").font(.system(size: 11)).foregroundStyle(Ink.text3).padding(.leading, 2)
            }
        }
        .frame(height: 40)
    }

    /// 창 위쪽은 비워 둔다 — 신호등 버튼만 종이 위에 뜬다. 움직이는 것(날짜·넣기)은 그것이 바꾸는 것 옆에 둔다.
    private var topBar: some View { Color.clear.frame(height: 28) }

    /// 넣는 길 두 가지를 한 줄에: 한 줄 넣기 + 한꺼번에 쏟아내기
    private var addRow: some View {
        HStack(spacing: 10) {
            AddField(text: $text, day: day, onAdded: { store.show($0) }, focused: $addFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .paper(11)
            Button { store.cover = .dump } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 12, weight: .semibold))
                    Text("쏟아내기").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Ink.text)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.sheet))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("머릿속에 도는 걸 한꺼번에 적으면 Apple Intelligence가 칸으로 나눠 (⌘D)")
            .accessibilityIdentifier("toolbar.dump")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 창 위쪽 줄의 버튼: 종이 위에 글자만, 올리면 한 톤 어두워진다
/// 여러 번 넘어온 일 하나를 놓고 조용히 묻는다 (iPhone 의 StuckCard 와 같은 규칙)
private struct MacStuck: View {
    @Environment(Store.self) private var store
    var item: Item

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("‘\(item.title)’, \(item.moves)번 넘어왔어.").font(Typo.serif(15)).foregroundStyle(Ink.text).lineLimit(1)
                Text("일이 큰 걸 수도, 지금은 아닌 걸 수도 있어.").font(.system(size: 11.5)).foregroundStyle(Ink.text2)
            }
            Spacer(minLength: 8)
            Button("작게 쪼개기") { store.splitting = SplitRequest(title: item.title, due: nil, part: item.part); store.change { $0.keepStuck(item.id, today: store.today) } }
                .buttonStyle(MacFill(tone: .ink))
            Button("나중에 함") { withAnimation(Motion.soft) { store.change(undo: "나중에 함에 넣었어") { $0.move(.item(item.id), to: nil) } } }
                .buttonStyle(MacFill(tone: .quiet))
            Button("버리기") { withAnimation(Motion.soft) { store.change(undo: "버렸어") { $0.remove(.item(item.id)) } } }
                .buttonStyle(MacFill(tone: .quiet))
            Button("그냥 둘게") { withAnimation(Motion.soft) { store.change { $0.keepStuck(item.id, today: store.today) } } }
                .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Ink.text3)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .paper(12)
        .accessibilityIdentifier("stuck.card")
    }
}

private struct BarButton: ButtonStyle {
    var square = false
    func makeBody(configuration: Configuration) -> some View { BarBody(configuration: configuration, square: square) }

    private struct BarBody: View {
        let configuration: Configuration
        let square: Bool
        @State private var hover = false
        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.text2)
                .padding(.horizontal, square ? 0 : 10)
                .frame(width: square ? 24 : nil, height: 22)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(configuration.isPressed ? Ink.rule : (hover ? Ink.fill : .clear)))
                .contentShape(Rectangle())
                .onHover { hover = $0 }
        }
    }
}

// MARK: - 한 주 띠

/// 이번 주 일곱 날. 할 일이 있는 날은 점, 오늘은 코발트.
private struct WeekStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        let start = store.selectedDay.startOfWeek(mondayFirst: store.settings.mondayFirst)
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { i in
                let d = start.adding(days: i)
                let on = d == store.selectedDay
                Button { store.selectedDay = d } label: {
                    VStack(spacing: 2) {
                        Text(Fmt.weekday[d.weekday()]).font(.system(size: 10, weight: .medium))
                            .foregroundStyle(on ? Ink.sheet.opacity(0.75) : Ink.text3)
                        Text("\(d.d)").font(Typo.num(size: 14, .bold))
                            .foregroundStyle(on ? Ink.sheet : (d == store.today ? Ink.accent : Ink.text))
                        Circle().fill(on ? Ink.sheet : Ink.text3).frame(width: 3.5, height: 3.5)
                            .opacity(store.data.hasEntries(on: d) ? 1 : 0)
                    }
                    .frame(width: 34, height: 46)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? Ink.text : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.m)월 \(d.d)일")
            }
        }
    }
}

// MARK: - 띠 한 칸

private struct BandColumn: View {
    @Environment(Store.self) private var store
    var band: Band
    var isToday: Bool
    @State private var dropping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 좁으면 시각 범위부터 뺀다 — 띠 이름과 남은 시간은 늘 한 줄
            ViewThatFits(in: .horizontal) {
                head(range: true, long: true)
                head(range: true, long: false)
                head(range: false, long: false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Rectangle().fill(band.live ? Ink.accent : Ink.rule).frame(height: band.live ? 2 : 1).padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(band.events) { e in
                        EventBlock(entry: e, live: isToday && band.live && isNow(e))
                    }
                    if !band.events.isEmpty && !band.todos.isEmpty { Color.clear.frame(height: 3) }
                    ForEach(band.todos) { e in
                        TodoRow(entry: e)
                            .draggable(e.id)
                            .transition(Motion.row)
                    }
                    if band.isEmpty {
                        Text(band.gone ? "지나감" : "비어 있음")
                            .font(.system(size: 12)).foregroundStyle(Ink.text3)
                            .padding(.leading, 6).padding(.top, 8)
                    }
                }
                .padding(.horizontal, 8)
                .calm(Motion.soft, value: band.todos.map(\.id))
                .padding(.vertical, 10)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sheet))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.accent, lineWidth: dropping ? 2 : 0))
        .opacity(band.gone ? 0.62 : 1)
        // 끌어다 놓으면 그 띠로 옮긴다
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, let e = store.sheet(for: store.selectedDay).bands.flatMap(\.todos).first(where: { $0.id == id }),
                  e.part != band.part else { return false }
            store.move(e, to: store.selectedDay, part: band.part)
            return true
        } isTargeted: { dropping = $0 }
    }

    private func head(range: Bool, long: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(band.part.name)
                .font(Typo.serif(19))
                .foregroundStyle(band.live ? Ink.accent : (band.gone ? Ink.text3 : Ink.text))
                .fixedSize()
            if range {
                Text(Fmt.hm(band.range.lowerBound) + "–" + Fmt.hm(band.range.upperBound % 1440))
                    .font(Typo.num(size: 11, .medium)).foregroundStyle(Ink.text3)
                    .fixedSize()
            }
            Spacer(minLength: 6)
            if !band.gone, band.planned > 0 || band.live {
                Text(band.overflow > 0 ? (long ? "\(Fmt.dur(band.overflow)) 넘침" : "+\(Fmt.dur(band.overflow))")
                                       : (long ? "빈 시간 \(Fmt.dur(band.free))" : "빈 \(Fmt.dur(band.free))"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(band.overflow > 0 ? Ink.stamp : Ink.text3)
                    .fixedSize()
            }
        }
    }

    private func isNow(_ e: Entry) -> Bool {
        guard let t = e.time else { return false }
        let m = minuteOfDay(store.now)
        return t <= m && m < t + e.duration
    }
}

// MARK: - 오른쪽: 나중에 함 · 걱정 상자

private struct SideRail: View {
    @Environment(Store.self) private var store

    var body: some View {
        let later = store.data.laterItems
        let worries = store.data.worries
        VStack(alignment: .leading, spacing: 16) {
            // 말로 찾기 — 누르면 찾기 창 (⌘F)
            Button { store.cover = .find } label: {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold))
                    Text("말로 하기").font(.system(size: 12.5))
                    Spacer()
                    KeyCap(text: "⌘F")
                }
                .foregroundStyle(Ink.text3)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ink.sheet))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("물으면 찾고(“다음 주에 병원 언제야?”), 시키면 바꿔(“치과 내일로 미루고 보고서는 끝냈어”). Apple Intelligence가 읽어")
            .accessibilityIdentifier("rail.find")
            section("나중에 함", count: later.count) {
                if later.isEmpty {
                    hint("‘언젠가’, ‘나중에’라고 쓰면 여기 모여.")
                } else {
                    ForEach(later.prefix(12)) { it in
                        LaterRow(item: it)
                    }
                    if later.count > 12 { hint("외 \(later.count - 12)개") }
                }
            }
            section("걱정 상자", count: worries.count) {
                if worries.isEmpty {
                    hint("걱정은 여기 넣어 두고, 걱정 시간(\(Fmt.hm(store.settings.worryTime)))에만 꺼내 봐.")
                } else {
                    ForEach(worries.prefix(6)) { WorryRow(item: $0) }
                    hint("누르면 내 손 안의 일인지 살펴 줘. 걱정 시간은 \(Fmt.hm(store.settings.worryTime)).")
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func section<C: View>(_ title: String, count: Int, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(Typo.serif(15)).foregroundStyle(Ink.text)
                if count > 0 { Text("\(count)").font(Typo.num(size: 12, .semibold)).foregroundStyle(Ink.text3) }
            }
            Hairline()
            content()
        }
    }

    private func hint(_ s: String) -> some View {
        Text(s).font(.system(size: 11.5)).foregroundStyle(Ink.text3).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
    }
}

/// 걱정 하나. 누르면 Apple Intelligence 가 '내 손 안인지'와 아주 작은 한 걸음을 살핀다 (조언은 하지 않는다).
private struct WorryRow: View {
    @Environment(Store.self) private var store
    var item: Item
    @State private var advice: WorryAdvice?
    @State private var loading = false
    @State private var fromAI = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: look) {
                HStack(alignment: .top, spacing: 6) {
                    Text(item.title).font(.system(size: 12.5)).foregroundStyle(Ink.text).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if loading { ProgressView().controlSize(.mini) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let a = advice {
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.line).font(.system(size: 11.5)).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
                    if let step = a.step, !a.crisis {
                        Button("‘\(step)’ 오늘 할 일로") {
                            let now = store.now
                            let part = store.settings.parts.part(at: minuteOfDay(now))
                            store.change(undo: "한 걸음을 오늘에 넣었어") { $0.add(Item(title: step, day: DayKey(now), part: part, duration: 5, created: now)) }
                        }
                        .buttonStyle(MacGhost())
                    }
                    if fromAI { AppleAIBadge() }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ink.sheet))
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("내려놓기 (지우기)", role: .destructive) { store.change(undo: "내려놓았어") { $0.remove(.item(item.id)) } }
        }
    }

    private func look() {
        if advice != nil { advice = nil; return }
        loading = true
        Task {
            let ready = Brain.shared.isReady
            let a = await Brain.shared.worry(item.title)
            advice = a
            fromAI = ready && !a.crisis
            loading = false
        }
    }
}

private struct LaterRow: View {
    @Environment(Store.self) private var store
    var item: Item
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Text(item.title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.text).lineLimit(1)
            Spacer(minLength: 4)
            if hover {
                Button("오늘로") {
                    let part = store.settings.parts.part(at: minuteOfDay(store.now))
                    let today = store.today
                    store.change(undo: "오늘 \(part.name)으로 옮겼어") { $0.move(.item(item.id), to: today, part: part) }
                }
                .buttonStyle(MacGhost())
            } else {
                let age = DayLogic.age(item, today: store.today)
                if age >= 7 { Text("\(age)일째").font(.system(size: 10.5)).foregroundStyle(Ink.text3) }
            }
        }
        .frame(minHeight: 26)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .contextMenu {
            Button("지우기", role: .destructive) { store.change(undo: "지웠어") { $0.remove(.item(item.id)) } }
        }
    }
}
