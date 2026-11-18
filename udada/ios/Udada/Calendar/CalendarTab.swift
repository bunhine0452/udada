import SwiftUI

/// 달력 탭: 한 달을 보고, 날을 누르면 그날의 세 띠가 아래에 열린다. 넣기 줄은 고른 날에 넣는다.
/// 옆으로 밀면 다른 달 (그달의 오늘, 없으면 1일이 골라진다). 적는 동안은 달 칸을 접어 그날 띠가 보이게 한다.
struct CalendarTab: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month = DayKey.today()
    @State private var forward = true
    @State private var editing: Entry?
    @State private var presetPart: Part?
    @FocusState private var adding: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !adding {
                    // 달이 바뀌면 옆으로 밀려 바뀌고, 적기 시작하면 위로 접힌다
                    ZStack {
                        MonthGrid(month: month, onSwipe: shiftMonth)
                            .id(DayKey(y: month.y, m: month.m, d: 1))
                            .transition(monthTransition)
                    }
                    .clipped()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Hairline(color: Ink.text.opacity(0.85)).padding(.top, 4)
                dayHeader
                DaySheetView(sheet: store.sheet(for: store.selectedDay), compact: true, onEdit: { editing = $0 }, onAddInBand: { p in
                    presetPart = p; adding = true
                })
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, Metric.gutter)
            .animation(reduceMotion ? nil : .snappy, value: adding)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ink.ground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if editing == nil { ToastLayer().padding(.bottom, 10) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddBar(day: store.selectedDay, focused: $adding, presetPart: $presetPart)
        }
        .sheet(item: $editing) { e in EditSheet(entry: e) }
        .onAppear { month = store.selectedDay }
        .onChange(of: store.selectedDay) { old, d in
            guard d.y != month.y || d.m != month.m else { return }
            forward = d > old
            withAnimation(reduceMotion ? nil : .snappy) { month = d }
        }
    }

    private var monthTransition: AnyTransition {
        reduceMotion ? .opacity : .push(from: forward ? .trailing : .leading)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 4) {
                monthTitle
                Spacer(minLength: 8)
                monthButtons
            }
            VStack(alignment: .leading, spacing: 4) {
                monthTitle
                HStack(spacing: 4) { monthButtons }
            }
        }
        .padding(.top, 8)
    }

    private var monthTitle: some View {
        Text(verbatim: "\(month.y)년 \(month.m)월").font(Typo.serif(28, relativeTo: .title))
            .foregroundStyle(Ink.text)
            .lineLimit(1)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("cal.title")
    }

    @ViewBuilder private var monthButtons: some View {
        Button { store.cover = .find } label: {
            Image(systemName: "magnifyingglass").font(.system(.body, weight: .semibold))
                .frame(width: Metric.tap, height: Metric.tap).contentShape(Rectangle())
        }
        .foregroundStyle(Ink.text)
        .accessibilityLabel("말로 찾기")
        .accessibilityIdentifier("cal.find")
        Button { shiftMonth(-1) } label: {
            Image(systemName: "chevron.left").font(.system(.body, weight: .semibold))
                .frame(width: Metric.tap, height: Metric.tap).contentShape(Rectangle())
        }
        .foregroundStyle(Ink.text)
        .accessibilityLabel("이전 달")
        .accessibilityIdentifier("cal.prev")
        Button { shiftMonth(1) } label: {
            Image(systemName: "chevron.right").font(.system(.body, weight: .semibold))
                .frame(width: Metric.tap, height: Metric.tap).contentShape(Rectangle())
        }
        .foregroundStyle(Ink.text)
        .accessibilityLabel("다음 달")
        .accessibilityIdentifier("cal.next")
        Button("오늘") {
            Haptic.tick()
            let t = store.today
            forward = t > month
            withAnimation(reduceMotion ? nil : .snappy) { store.selectedDay = t; month = t }
        }
        .font(.system(.subheadline, weight: .bold))
        .foregroundStyle(Ink.accent)
        .lineLimit(1)
        .fixedSize()
        .frame(minWidth: Metric.tap, minHeight: Metric.tap)
        .contentShape(Rectangle())
        .padding(.leading, 4)
        .accessibilityIdentifier("cal.today")
    }

    private var dayHeader: some View {
        let d = store.selectedDay
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                dayTitle(d)
                Spacer(minLength: 8)
                openDayButton
            }
            VStack(alignment: .leading, spacing: 0) {
                dayTitle(d)
                openDayButton
            }
        }
    }

    private func dayTitle(_ d: DayKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(d.m)월 \(d.d)일").font(Typo.num(.title2)).foregroundStyle(Ink.text)
            Text("\(Fmt.weekday[d.weekday()])요일" + (d == store.today ? " · 오늘" : ""))
                .font(Typo.serif(15, relativeTo: .subheadline)).foregroundStyle(Ink.text2)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var openDayButton: some View {
        Button { store.tab = .today } label: {
            HStack(spacing: 4) {
                Text("하루 한 장으로")
                Image(systemName: "chevron.right").font(.system(.caption, weight: .bold))
            }
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(Ink.text)
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: Metric.tap)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("calendar.open.day")
    }

    /// 다른 달로. 고른 날도 따라간다: 그달에 오늘이 있으면 오늘, 없으면 1일 — 아래 띠가 늘 보이는 달의 날이게.
    private func shiftMonth(_ n: Int) {
        Haptic.tick()
        let first = DayKey(y: month.y, m: month.m, d: 1)
        let next = DayKey(Calendar.current.date(byAdding: .month, value: n, to: first.date())!)
        let t = store.today
        forward = n > 0
        withAnimation(reduceMotion ? nil : .snappy) {
            month = next
            store.selectedDay = (t.y == next.y && t.m == next.m) ? t : next
        }
    }
}

/// 한 달 칸. 고른 날은 먹색으로 차고, 오늘은 코발트 숫자, 그날 일이 있으면 점(약속은 꽉 찬 점, 할 일은 빈 점).
struct MonthGrid: View {
    @Environment(Store.self) private var store
    let month: DayKey
    var onSwipe: (Int) -> Void

    var body: some View {
        let cal = Calendar.current
        let first = DayKey(y: month.y, m: month.m, d: 1)
        let count = cal.range(of: .day, in: .month, for: first.date())?.count ?? 30
        let monday = store.settings.mondayFirst
        let lead = monday ? (first.weekday() + 5) % 7 : first.weekday() - 1
        let rows = Int(ceil(Double(lead + count) / 7))
        let names = monday ? ["월", "화", "수", "목", "금", "토", "일"] : ["일", "월", "화", "수", "목", "금", "토"]
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(names, id: \.self) { n in
                    Text(n).font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { c in
                        let d = r * 7 + c - lead + 1
                        if d >= 1 && d <= count {
                            DayCell(day: DayKey(y: month.y, m: month.m, d: d))
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 52)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        // 가로로 밀 때만 잡아서, 달 칸 위에서 위아래로 끌면 화면이 그대로 스크롤된다
        .gesture(HorizontalPan(onEnded: { dx, v in
            let reach = dx + v * 0.2
            guard abs(reach) >= 40 else { return }
            onSwipe(reach < 0 ? 1 : -1)
        }))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cal.grid")
        .accessibilityAction(named: "다음 달") { onSwipe(1) }
        .accessibilityAction(named: "이전 달") { onSwipe(-1) }
    }
}

private struct DayCell: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: DayKey

    var body: some View {
        let on = day == store.selectedDay
        let isToday = day == store.today
        let entries = store.data.entries(on: day, external: store.external)
        let events = entries.filter { $0.isEvent || $0.allDay }.count
        // 반복 할 일은 날마다 점을 찍어 신호가 흐려지니 뺀다 (약속은 반복이어도 센다)
        let todos = entries.filter { !$0.isEvent && !$0.allDay && !$0.done && !$0.repeating }.count
        Button {
            guard !on else { return }
            Haptic.tick()
            withAnimation(reduceMotion ? nil : .snappy) { store.selectedDay = day }
        } label: {
            VStack(spacing: 4) {
                Text("\(day.d)").font(Typo.num(.title3))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(on ? Ink.sheet : isToday ? Ink.accent : (day < store.today ? Ink.text3 : Ink.text))
                HStack(spacing: 3) {
                    ForEach(0..<min(events, 2), id: \.self) { _ in Circle().fill(on ? Ink.sheet : Ink.text).frame(width: 5, height: 5) }
                    ForEach(0..<min(todos, 3 - min(events, 2)), id: \.self) { _ in
                        Circle().strokeBorder(on ? Ink.sheet : Ink.text2, lineWidth: 1).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Ink.text : .clear))
            .overlay {
                if isToday && !on { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ink.accent.opacity(0.5), lineWidth: 1.5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(day.m)월 \(day.d)일 \(Fmt.weekday[day.weekday()])요일" + (isToday ? ", 오늘" : "") + (events + todos > 0 ? ", 약속 \(events)개, 할 일 \(todos)개" : ""))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("cal.\(day)")
    }
}
