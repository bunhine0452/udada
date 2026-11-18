import SwiftUI

/// 오늘 탭: 날짜와 주 띠(위에 고정) · 하루 요약 · 세 띠 · 맨 아래 넣기 줄
struct TodayView: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing: Entry?
    @State private var splitting: SplitRequest?
    @State private var splitID: UUID?
    /// 하루 띠에서 누른 칸 (그 칸으로 스크롤)
    @State private var jump: String?
    @State private var showLater = false
    @State private var showDayPicker = false
    @State private var presetPart: Part?
    @State private var hideLater = FocusFilterState.current.hideLater
    @FocusState private var adding: Bool

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let sheet = store.sheet(for: store.selectedDay)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("top")
                        // 큰 글자에서는 머리가 화면을 다 먹지 않게 본문과 같이 올라간다
                        if typeSize.isAccessibilitySize { header(sheet) }
                        VStack(alignment: .leading, spacing: 0) {
                            if sheet.isToday && !sheet.isEmpty { BriefLine(sheet: sheet).padding(.bottom, 12) }
                            if sheet.isEmpty { EmptyDayCard(isToday: sheet.isToday) { adding = true }.padding(.bottom, 14) }
                            if sheet.isToday, store.inboxCount > 0 { InboxCard().padding(.bottom, 14).transition(Motion.rise) }
                            // 한 번에 하나만 묻는다: 받아 둔 것이 있으면 그것 먼저
                            if sheet.isToday, store.inboxCount == 0, let it = store.data.stuck(today: store.today) {
                                StuckCard(item: it, onSplit: { splitting = SplitRequest(title: it.title, due: nil, part: it.part); splitID = it.id })
                                    .padding(.bottom, 14)
                                    .transition(Motion.rise)
                            }
                            DaySheetView(sheet: sheet, onEdit: { editing = $0 }, onAddInBand: { p in presetPart = p; adding = true })
                            if sheet.isToday, sheet.allTodosDone {
                                RestOfDayCard(done: sheet.doneTodos).padding(.top, 14).transition(Motion.rise)
                            }
                            Color.clear.frame(height: 24)
                        }
                        .padding(.horizontal, Metric.gutter)
                        .calm(Motion.soft, value: sheet.allTodosDone)
                        .calm(Motion.soft, value: store.inboxCount)
                        .calm(Motion.soft, value: store.data.stuck(today: store.today)?.id)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if typeSize.isAccessibilitySize {
                        // 머리가 같이 올라가는 큰 글자에서도 상태 막대 아래로 글자가 비치지 않게
                        Color.clear.frame(height: 0).background(Ink.ground.ignoresSafeArea(edges: .top))
                    } else {
                        header(sheet)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { DispatchQueue.main.async { reveal(sheet, proxy: proxy, animated: false) } }
                .onChange(of: store.selectedDay) { _, d in
                    reveal(store.sheet(for: d), proxy: proxy, animated: true)
                }
                .onChange(of: jump) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : Motion.page) { proxy.scrollTo(id, anchor: .top) }
                    jump = nil
                }
            }
        }
        .background(Ink.ground.ignoresSafeArea())
        // 토스트는 넣기 줄 바로 위 (적는 중이면 칩 판 위) — 미리보기를 가리지 않고, 엄지가 '되돌리기'에 닿는다
        .overlay(alignment: .bottom) {
            if editing == nil && !showLater && !showDayPicker { ToastLayer().padding(.bottom, 10) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddBar(day: store.selectedDay, focused: $adding, presetPart: $presetPart, handlesRequests: true)
        }
        .sheet(item: $editing) { e in EditSheet(entry: e) }
        .sheet(item: $splitting) { r in
            BreakdownSheet(request: r) { if let id = splitID { store.change { $0.settleStuck(id) } } }.environment(store)
        }
        .sheet(isPresented: $showLater) { LaterSheet() }
        .sheet(isPresented: $showDayPicker) { DayPickerSheet() }
        .onReceive(NotificationCenter.default.publisher(for: FocusFilterState.didChange)) { _ in
            hideLater = FocusFilterState.current.hideLater
        }
    }

    /// 오늘이면 지금 띠가 머리 바로 아래 오게, 다른 날이면 맨 위. 빈 날은 안내 카드가 보이게 맨 위에 둔다.
    private func reveal(_ sheet: DaySheet, proxy: ScrollViewProxy, animated: Bool) {
        let target: String
        // 받아 둔 것·넘어온 일·쉼 카드가 맨 위에 있으면 그것부터 보이게 지금 띠로 내려가지 않는다
        let notice = sheet.isToday && (store.inboxCount > 0 || store.data.stuck(today: store.today) != nil)
        if sheet.isToday && !sheet.isEmpty, !notice, let live = sheet.bands.first(where: \.live), live.part != .morning {
            target = "live"
        } else {
            target = "top"
        }
        if animated && !reduceMotion { withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) } }
        else { proxy.scrollTo(target, anchor: .top) }
    }

    private func header(_ sheet: DaySheet) -> some View {
        let d = store.selectedDay
        let isToday = d == store.today
        return VStack(alignment: .leading, spacing: adding ? 6 : 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    dateButton(d, isToday: isToday)
                    Spacer(minLength: 8)
                    headerButtons(isToday: isToday)
                }
                VStack(alignment: .leading, spacing: 8) {
                    dateButton(d, isToday: isToday)
                    HStack(spacing: 10) { headerButtons(isToday: isToday) }
                }
            }
            if !adding { WeekStrip() }
            // 하루 띠: 세 칸과 지금 (적는 중이거나 빈 날에는 숨긴다)
            if !adding, !sheet.isEmpty {
                DayRuler(sheet: sheet) { band in jump = band.live ? "live" : band.part.rawValue }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Ink.ground.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline() }
        .animation(.snappy, value: adding)
    }

    private func dateButton(_ d: DayKey, isToday: Bool) -> some View {
        Button { showDayPicker = true } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(d.m)월 \(d.d)일")
                    .font(Typo.num(size: adding ? 26 : 34, .heavy, relativeTo: .largeTitle))
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(Fmt.weekday[d.weekday()])요일" + (isToday ? " · 오늘" : " · \(relative(d))"))
                    .font(Typo.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(Ink.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(d.m)월 \(d.d)일 \(Fmt.weekday[d.weekday()])요일" + (isToday ? ", 오늘" : ", \(relative(d))"))
        .accessibilityHint("날짜 고르기")
        .accessibilityIdentifier("header.date")
    }

    @ViewBuilder private func headerButtons(isToday: Bool) -> some View {
        if !isToday {
            Button("오늘로") { withAnimation(.snappy) { store.selectedDay = store.today } }
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(Ink.accent)
                .lineLimit(1)
                .fixedSize()
                .frame(minHeight: Metric.tap)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .accessibilityIdentifier("header.today")
        }
        if !hideLater { laterButton }
    }

    private var laterButton: some View {
        let count = store.data.laterItems.count
        // 비어 있으면 한 톤 낮춘다 — 들어갈 수는 있지만 눈을 끌지 않게
        return Button { showLater = true } label: {
            HStack(spacing: 6) {
                Text("나중에").font(.system(.subheadline, weight: .semibold))
                Text("\(count)").font(Typo.num(.headline))
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: Metric.tap)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Ink.fill.opacity(count == 0 ? 0.6 : 1)))
            .foregroundStyle(count == 0 ? Ink.text2 : Ink.text)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(count == 0 ? "나중에 함, 비어 있음" : "나중에 함 \(count)개")
        .accessibilityIdentifier("later.open")
    }

    private func relative(_ d: DayKey) -> String {
        let n = store.today.days(to: d)
        switch n {
        case 1: return "내일"
        case 2: return "모레"
        case -1: return "어제"
        default: return n > 0 ? "\(n)일 뒤" : "\(-n)일 전"
        }
    }
}

/// 주 띠: 일곱 날. 고른 날은 먹색으로 차고(눌러 옮기면 미끄러진다), 오늘은 코발트 숫자. 옆으로 밀면 다른 주.
struct WeekStrip: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

    var body: some View {
        let sel = store.selectedDay
        let start = sel.startOfWeek(mondayFirst: store.settings.mondayFirst)
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let k = start.adding(days: i)
                let on = k == sel
                let isToday = k == store.today
                Button {
                    guard !on else { return }
                    Haptic.tick()
                    withAnimation(reduceMotion ? nil : .snappy) { store.selectedDay = k }
                } label: {
                    VStack(spacing: 3) {
                        Text(Fmt.weekday[k.weekday()]).font(.system(.caption, weight: .semibold))
                            .foregroundStyle(on ? Ink.sheet.opacity(0.8) : Ink.text3)
                        Text("\(k.d)").font(Typo.num(.title3))
                            .foregroundStyle(on ? Ink.sheet : isToday ? Ink.accent : Ink.text)
                            .contentTransition(.numericText())
                        Circle().fill(on ? Ink.sheet : Ink.text2).frame(width: 4, height: 4)
                            .opacity(hasMarks(k) ? 1 : 0)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.text)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("\(k.m)월 \(k.d)일 \(Fmt.weekday[k.weekday()])요일" + (isToday ? ", 오늘" : ""))
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("week.\(k.d)")
            }
        }
        .contentShape(Rectangle())
        // 가로로 밀 때만 잡는다 (날 버튼 위에서 시작해도). 짧고 빠르게 튕겨도 넘어가게 속도도 본다.
        .gesture(HorizontalPan(onEnded: { dx, v in
            let reach = dx + v * 0.2
            guard abs(reach) >= 40 else { return }
            Haptic.tick()
            withAnimation(reduceMotion ? nil : .snappy) { store.selectedDay = sel.adding(days: reach < 0 ? 7 : -7) }
        }))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("week.strip")
        .accessibilityAction(named: "다음 주") { store.selectedDay = sel.adding(days: 7) }
        .accessibilityAction(named: "지난주") { store.selectedDay = sel.adding(days: -7) }
    }

    /// 점은 약속이 있거나 안 끝낸 할 일이 있을 때. 매일 하는 반복 할 일만 있는 날은 점을 찍지 않는다 (날마다 찍히면 점이 아무 말도 안 한다).
    private func hasMarks(_ k: DayKey) -> Bool {
        store.data.entries(on: k, external: store.external).contains { $0.isEvent || $0.allDay || (!$0.done && !$0.repeating) }
    }
}

/// 오늘 요약 한 줄: 약속 · 할 일 · 빈 시간. 글자가 커지면 다음 줄로 흐른다.
struct BriefLine: View {
    let sheet: DaySheet
    var body: some View {
        FlowRow(spacing: 14, lineSpacing: 4) {
            stat("약속", "\(sheet.eventCount)")
            stat("할 일", "\(sheet.openTodos)")
            stat("빈 시간", Fmt.dur(sheet.freeTotal))
            if sheet.doneTodos > 0 { stat("끝냄", "\(sheet.doneTodos)") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("brief")
    }
    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label).font(.system(.footnote)).foregroundStyle(Ink.text2)
            Text(value).font(Typo.num(.headline)).foregroundStyle(Ink.text)
        }
        .fixedSize()
    }
}

/// 왼쪽부터 채우고 넘치면 다음 줄로
private struct FlowRow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let h = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: rows.map(\.width).max() ?? 0, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            if rows[rows.count - 1].width + extra > width && !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let first = rows[rows.count - 1].items.isEmpty
            rows[rows.count - 1].items.append(i)
            rows[rows.count - 1].width += first ? s.width : s.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, s.height)
        }
        return rows
    }
}

/// 아무것도 없는 날
/// 공유로 밖에서 받아 둔 것이 있을 때: 정리하면 Apple Intelligence 가 챙길 일만 골라 비우기 화면에 올린다.
struct InboxCard: View {
    @Environment(Store.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("밖에서 받아 둔 게 \(store.inboxCount)개 있어.")
                .font(Typo.serif(19, relativeTo: .title3)).foregroundStyle(Ink.text)
            Text(Brain.shared.isReady ? "이 iPhone 의 Apple Intelligence 가 챙길 일정과 할 일만 골라 줘. 넣기 전에 먼저 보여 줘."
                                     : "챙길 일정과 할 일만 골라 줘. 넣기 전에 먼저 보여 줘.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            if let ask = offerInInbox {
                Button { store.reply = ask } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.intelligence").font(.system(.footnote, weight: .semibold)).accessibilityHidden(true)
                        Text("약속을 묻는 글이 있어 · 내 일정 보고 답장 쓰기").font(.system(.subheadline, weight: .semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(.caption, weight: .semibold)).accessibilityHidden(true)
                    }
                    .foregroundStyle(Ink.accent)
                    .padding(.horizontal, 12)
                    .frame(minHeight: Metric.tap)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.accentSoft))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("inbox.reply")
            }
            HStack(spacing: 8) {
                Button("정리하기") { store.takeInbox = true; store.tab = .mind; store.dumpMode = .text; store.cover = .dump }
                    .buttonStyle(FillButton(tone: .accent, height: 44, full: false))
                    .accessibilityIdentifier("inbox.sort")
                Button("지우기") {
                    Haptic.tap()
                    withAnimation(Motion.soft) { Inbox.remove(Inbox.items()); store.inboxCount = 0 }
                }
                .buttonStyle(FillButton(tone: .quiet, height: 44, full: false))
                .accessibilityIdentifier("inbox.clear")
            }
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inbox.card")
    }

    /// 받아 둔 글 가운데 약속을 묻는 첫 글
    private var offerInInbox: ReplyRequest? {
        for u in Inbox.items() where u.pathExtension == "txt" {
            guard let t = try? String(contentsOf: u, encoding: .utf8), ReplyRules.looksLikeOffer(t, now: store.now) else { continue }
            return ReplyRequest(text: t.trimmingCharacters(in: .whitespacesAndNewlines), source: u)
        }
        return nil
    }
}

/// 여러 번 넘어온 일 하나를 놓고 조용히 묻는다. 탓하지 않는다 — 일이 큰지, 지금이 아닌지만 가린다.
struct StuckCard: View {
    @Environment(Store.self) private var store
    var item: Item
    var onSplit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("‘\(item.title)’, \(item.moves)번 넘어왔어.")
                .font(Typo.serif(19, relativeTo: .title3)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("일이 큰 걸 수도, 지금은 아닌 걸 수도 있어. 어떻게 할까?")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 2)
            Button("그냥 둘게") { withAnimation(Motion.soft) { store.change { $0.keepStuck(item.id, today: store.today) } } }
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text3)
                .frame(minHeight: Metric.tap, alignment: .leading)
                .accessibilityIdentifier("stuck.keep")
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stuck.card")
    }

    @ViewBuilder private var buttons: some View {
        Button("작게 쪼개기", action: onSplit)
            .buttonStyle(FillButton(tone: .ink, height: 44, full: false))
            .accessibilityIdentifier("stuck.split")
        Button("나중에 함") {
            Haptic.tap()
            withAnimation(Motion.soft) { store.change(undo: "나중에 함에 넣었어") { $0.move(.item(item.id), to: nil) } }
        }
        .buttonStyle(FillButton(tone: .quiet, height: 44, full: false))
        .accessibilityIdentifier("stuck.later")
        Button("버리기") {
            Haptic.tap()
            withAnimation(Motion.soft) { store.change(undo: "버렸어") { $0.remove(.item(item.id)) } }
        }
        .buttonStyle(FillButton(tone: .quiet, height: 44, full: false))
        .accessibilityIdentifier("stuck.drop")
    }
}

/// 오늘 할 일을 다 끝냈을 때: 더 채우라고 하지 않는다. 숨 쉬는 점 하나와 한 줄.
struct RestOfDayCard: View {
    var done: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            BreathDot(size: 10).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘 한 장은 여기까지야.")
                    .font(Typo.serif(19, relativeTo: .title3)).foregroundStyle(Ink.text)
                Text("\(done)개를 끝냈어. 남은 시간은 채우지 않아도 돼.")
                    .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rest.card")
    }
}

struct EmptyDayCard: View {
    @Environment(Store.self) private var store
    var isToday: Bool
    var onAdd: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isToday ? "비어 있는 하루야." : "아직 비어 있어.")
                .font(Typo.serif(20, relativeTo: .title3))
                .foregroundStyle(Ink.text)
            Text("아래에 한 줄로 적어 봐. ‘3시 치과’는 약속이 되고, ‘보고서 30분’은 지금 띠의 할 일이 돼.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 2)
        }
        .card()
        .padding(.top, 12)
    }

    @ViewBuilder private var buttons: some View {
        Button("한 줄 적기", action: onAdd)
            .buttonStyle(FillButton(tone: .ink, height: 46, full: false))
            .accessibilityIdentifier("empty.add")
        Button("머릿속 비우기") { store.tab = .mind; store.cover = .dump }
            .buttonStyle(FillButton(tone: .quiet, height: 46, full: false))
        Button("사용법") { AITour.openAt = 0; store.showAITour = true }
            .buttonStyle(FillButton(tone: .quiet, height: 46, full: false))
            .accessibilityIdentifier("empty.guide")
    }
}

/// 날짜 고르기 (머리의 날짜를 누르면). 날을 누르면 바로 그날로 간다.
struct DayPickerSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("날짜", selection: selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Ink.accent)
                .padding(.horizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Ink.sheet)
                .navigationTitle("날짜로 가기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }.accessibilityIdentifier("daypicker.close")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("오늘") { store.selectedDay = store.today; dismiss() }
                            .accessibilityIdentifier("daypicker.today")
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Ink.sheet)
    }

    /// 지역 상태 없이 고른 날에 바로 묶는다 — 열자마자 '바뀜'으로 읽혀 닫히는 일이 없게
    private var selection: Binding<Date> {
        Binding {
            store.selectedDay.date()
        } set: { d in
            let k = DayKey(d)
            guard k != store.selectedDay else { return }
            Haptic.tick()
            store.selectedDay = k
            dismiss()
        }
    }
}

/// 토스트 자리 (탭마다 아래쪽 위에)
struct ToastLayer: View {
    @Environment(Store.self) private var store
    var body: some View {
        if let t = store.toast {
            ToastView(toast: t) { store.undo() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(t.id)
        }
    }
}
