import SwiftUI

// 하루 한 장의 본문: 세 띠. 오늘 탭과 달력 탭이 같이 쓴다.

struct DaySheetView: View {
    @Environment(Store.self) private var store
    let sheet: DaySheet
    var compact = false
    var onEdit: (Entry) -> Void
    var onAddInBand: (Part) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 2) {
            if !sheet.allDay.isEmpty { AllDayStrip(entries: sheet.allDay).padding(.bottom, 8) }
            ForEach(sheet.bands) { band in
                BandView(band: band, sheet: sheet, compact: compact, onEdit: onEdit, onAdd: { onAddInBand(band.part) })
                    // 칸 사이 틈은 위쪽 여백으로 — 그 칸으로 스크롤했을 때 머리 줄에 붙지 않게
                    .padding(.top, 10)
                    // 오늘 탭이 열릴 때 지금 띠로 스크롤하는 자리
                    .id(band.live ? "live" : band.part.rawValue)
            }
        }
    }
}

/// 종일 일정 (기기 달력)
struct AllDayStrip: View {
    let entries: [Entry]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("종일").font(Typo.caption).foregroundStyle(Ink.text3)
                ForEach(entries) { e in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: e.color ?? 0x8B9691)).frame(width: 4, height: 16)
                        Text(e.title).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                    }
                    .padding(.horizontal, 10).frame(minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.fill))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("종일 일정 \(e.title)")
                }
            }
        }
    }
}

struct BandView: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let band: Band
    let sheet: DaySheet
    var compact: Bool
    var onEdit: (Entry) -> Void
    var onAdd: () -> Void
    @State private var dropTarget = false

    /// 지난 칸을 펼쳐 봤나 (끝낸 것만 남은 지난 칸은 한 줄로 접혀 있다)
    @State private var opened = false

    /// 지난 칸이고 남은 할 일이 없으면 한 줄로 접는다 — 지금과 앞으로의 칸이 화면을 차지하게
    private var folded: Bool { band.gone && (clearAtOpen ?? (band.openTodos == 0)) && band.openTodos == 0 && !opened && !compact }
    /// 이 칸을 그리기 시작했을 때 남은 일이 없었나 (그 뒤에 끝낸 것으로는 접지 않는다)
    @State private var clearAtOpen: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: folded ? 0 : 10) {
            head
            if !folded {
                // 칸의 머리 줄: 지금 칸은 코발트로 굵게
                Rectangle().fill(band.live ? Ink.accent : Ink.rule).frame(height: band.live ? 2.5 : 1)
                rows
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, folded ? 10 : (compact ? 12 : 14))
        // 칸마다 종이 한 장 — 세 칸이 한 목록으로 이어져 보이지 않게
        .background {
            RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous)
                .fill(dropTarget ? Ink.fill : (folded ? Ink.fill.opacity(0.5) : Ink.sheet))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous)
                .strokeBorder(Ink.accent.opacity(0.55), lineWidth: 1.5)
                .opacity(band.live && !folded ? 1 : 0)
        }
        .environment(\.rowGround, Ink.sheet)
        .calm(Motion.soft, value: folded)
        .onAppear { if clearAtOpen == nil { clearAtOpen = band.openTodos == 0 } }
        .onChange(of: sheet.day) { _, _ in clearAtOpen = band.openTodos == 0; opened = false }
        .onChange(of: band.gone) { _, _ in clearAtOpen = band.openTodos == 0 }
        .dropDestination(for: String.self) { ids, _ in
            guard !band.gone, let id = ids.first,
                  let e = sheet.bands.flatMap({ $0.todos }).first(where: { $0.id == id }) else { return false }
            if e.part == band.part && e.day == sheet.day { return false }
            store.move(e, to: sheet.day, part: band.part)
            return true
        } isTargeted: { on in
            let next = on && !band.gone
            if next && !dropTarget { Haptic.tick() }
            withAnimation(.easeOut(duration: 0.15)) { dropTarget = next }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(band.part.name) 띠")
        .accessibilityIdentifier("band.\(band.part.rawValue)")
    }

    /// 칸 이름은 크게 가로로 — 왼쪽 기둥의 작은 세로 글씨로는 칸이 갈리지 않았다
    @ViewBuilder private var head: some View {
        let done = band.todos.filter(\.done).count
        let title = Text(band.part.name)
            .font(Typo.serif(folded ? 18 : 26, relativeTo: .title2))
            .foregroundStyle(band.live ? Ink.accent : (band.gone ? Ink.text2 : Ink.text))
        if band.gone && band.openTodos == 0 && !compact {
            Button { withAnimation(Motion.soft) { opened.toggle() } } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    title
                    Text(band.isEmpty ? "지나감" : "지나감 · " + [band.events.isEmpty ? nil : "약속 \(band.events.count)", done > 0 ? "끝낸 것 \(done)" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(.footnote)).foregroundStyle(Ink.text3)
                    Spacer(minLength: 8)
                    if !band.isEmpty {
                        Image(systemName: "chevron.down").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                            .rotationEffect(.degrees(opened ? 180 : 0))
                    }
                }
                .frame(minHeight: folded ? 28 : 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(band.isEmpty)
            .accessibilityLabel("\(band.part.name), 지나감" + (band.isEmpty ? "" : (opened ? ", 접기" : ", 펼치기")))
            .accessibilityIdentifier("band.fold.\(band.part.rawValue)")
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    title
                    range
                    if band.live { nowTag }
                    Spacer(minLength: 8)
                    load
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) { title; range; if band.live { nowTag } }
                    load
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var nowTag: some View {
        Text("지금").font(.system(.caption2, weight: .heavy)).foregroundStyle(Ink.sheet)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Ink.accent))
            .accessibilityHidden(true)
    }

    private var range: some View {
        Text("\(String(format: "%02d", band.range.lowerBound / 60))–\(String(format: "%02d", band.range.upperBound / 60))")
            .font(Typo.num(.subheadline, .semibold))
            .foregroundStyle(Ink.text3)
            .accessibilityLabel("\(band.range.lowerBound / 60)시부터 \(band.range.upperBound / 60)시")
    }

    private var load: some View {
        Group {
            if band.gone { Text("지나감") }
            else if band.overflow > 0 { Text("\(Fmt.dur(band.overflow)) 넘쳐").fontWeight(.bold).foregroundStyle(Ink.text) }
            else if band.planned > 0 { Text("넣은 일 \(Fmt.dur(band.planned)) · 빈 \(Fmt.dur(band.free))") }
            else { Text("빈 시간 \(Fmt.dur(band.free))") }
        }
        .font(.system(.footnote))
        .foregroundStyle(Ink.text2)
        .lineLimit(2)
    }

    @ViewBuilder private var rows: some View {
        let now = band.live ? sheet.now : nil
        // 지난 약속 표시는 오늘이면 어느 띠든, 지금 줄은 지금 띠에만
        let m = sheet.isToday ? (sheet.now?.minute ?? -1) : -1
        let started = band.events.filter { now != nil && ($0.time ?? 0) <= m }
        let upcoming = band.events.filter { now == nil || ($0.time ?? 0) > m }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(started) { e in EventRow(entry: e, nowMinute: m, onTap: { onEdit(e) }) }
            if let now { NowCard(now: now).id("now") }
            if !band.todos.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(band.todos.enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Hairline().padding(.leading, 48) }
                        TodoRow(entry: e, sheet: sheet, onEdit: { onEdit(e) })
                            .transition(Motion.row)
                    }
                }
                // 끝내면 아래로, 옮기면 다른 띠로 — 줄이 제자리를 찾아 미끄러진다
                .calm(Motion.soft, value: band.todos.map(\.id))
            }
            ForEach(upcoming) { e in EventRow(entry: e, nowMinute: m, onTap: { onEdit(e) }) }
            if band.isEmpty && now == nil {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Text(band.gone ? "비어 있었어" : "비어 있어")
                        if !band.gone { Text("· 여기에 넣기").fontWeight(.semibold).foregroundStyle(Ink.text2) }
                        Spacer(minLength: 0)
                    }
                    .font(.system(.subheadline))
                    .foregroundStyle(Ink.text3)
                    .frame(minHeight: Metric.tap)
                }
                .buttonStyle(PressStyle())
                .disabled(band.gone)
                .accessibilityLabel(band.gone ? "\(band.part.name) 띠는 비어 있었어" : "\(band.part.name) 띠에 넣기")
                .accessibilityIdentifier("band.add.\(band.part.rawValue)")
            }
            if band.part == .evening && sheet.isToday && !sheet.leftovers.isEmpty && !compact {
                Button { store.cover = .close } label: {
                    HStack {
                        Text("하루 닫기")
                        Spacer(minLength: 8)
                        Text("남은 것 \(sheet.leftovers.count)").font(Typo.num(.subheadline, .semibold)).foregroundStyle(Ink.text2)
                    }
                }
                .buttonStyle(FillButton(tone: .line, height: 52))
                .padding(.top, 6)
                .accessibilityIdentifier("close.open")
            }
        }
    }
}

// MARK: - 줄

/// 할 일 한 줄: 네모 · 이름 · 길이. 오른쪽으로 밀면 끝, 왼쪽으로 밀면 내일/나중에, 길게 누르면 메뉴, 길게 눌러 끌면 다른 띠로.
struct TodoRow: View {
    @Environment(Store.self) private var store
    let entry: Entry
    let sheet: DaySheet
    var onEdit: () -> Void

    var body: some View {
        let next = TodoMoves(entry: entry, store: store)
        SwipeRow(
            leading: SwipeAction(title: entry.done ? "되살리기" : "끝", symbol: entry.done ? "arrow.uturn.backward" : "checkmark",
                                 tint: Ink.block, fg: Ink.blockText) { store.toggleDone(entry) },
            trailing: entry.done ? [] : [
                SwipeAction(title: next.nextDayTitle, symbol: "arrow.right", tint: Ink.block, fg: Ink.blockText) { next.toNextDay() },
                SwipeAction(title: "나중에", symbol: "tray", tint: Ink.fill, fg: Ink.text) { store.move(entry, to: nil) },
            ]
        ) {
            TodoRowBody(entry: entry, meta: meta, onEdit: onEdit)
        }
        .contextMenu { TodoMenu(entry: entry, sheet: sheet, onEdit: onEdit) }
        .draggable(entry.id) {
            Text(entry.title).font(Typo.row).foregroundStyle(Ink.text)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).fill(Ink.sheet))
                .overlay(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
        }
        .accessibilityAction(named: entry.done ? "되살리기" : "끝내기") { store.toggleDone(entry) }
        .modifier(MoveActions(entry: entry, sheet: sheet))
    }

    private var meta: String {
        var s = [Fmt.dur(entry.duration)]
        if entry.repeating { s.append("반복") }
        if let f = entry.movedFrom { s.append("\(Fmt.day(f, today: store.today))부터") }
        if !entry.note.isEmpty { s.append(entry.note) }
        return s.joined(separator: " · ")
    }
}

/// 할 일을 옮기는 곳들 (밀기 · 메뉴 · VoiceOver 동작이 같이 쓴다)
@MainActor private struct TodoMoves {
    let entry: Entry
    let store: Store

    /// 오늘 일이면 '내일', 다른 날이면 '다음 날'
    var nextDayTitle: String { entry.day == store.today ? "내일" : "다음 날" }
    func toNextDay() { store.move(entry, to: entry.day.adding(days: 1), part: .morning) }

    /// 그날의 다른 띠. 오늘이면 이미 지난 띠는 빼고.
    func otherBands(_ sheet: DaySheet) -> [Part] {
        sheet.bands.filter { $0.part != entry.part && !$0.gone }.map(\.part)
    }
}

/// VoiceOver 동작: 내일로 · 나중에 · 다른 띠로
private struct MoveActions: ViewModifier {
    @Environment(Store.self) private var store
    let entry: Entry
    let sheet: DaySheet
    func body(content: Content) -> some View {
        let moves = TodoMoves(entry: entry, store: store)
        let bands = moves.otherBands(sheet)
        content.accessibilityActions {
            if !entry.done {
                Button(Fmt.ro(moves.nextDayTitle)) { moves.toNextDay() }
                Button("나중에") { store.move(entry, to: nil) }
            }
            ForEach(bands) { p in
                Button("\(Fmt.ro(p.name)) 옮기기") { store.move(entry, to: entry.day, part: p) }
            }
        }
    }
}

/// 할 일 줄 안쪽. 미는 중에는 눌림을 무시한다.
struct TodoRowBody: View {
    @Environment(Store.self) private var store
    @Environment(\.swipeActive) private var swiping
    @Environment(\.rowGround) private var ground
    let entry: Entry
    let meta: String
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { if !swiping { store.toggleDone(entry) } } label: { CheckBox(done: entry.done) }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.done ? "\(entry.title), 끝냄. 되살리기" : "\(entry.title) 끝내기")
                .accessibilityIdentifier("check.\(entry.title)")
            Button { if !swiping { onEdit() } } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if entry.pinned {
                            Text("하나").font(.system(.caption, weight: .heavy)).foregroundStyle(Ink.accent)
                                .accessibilityLabel("오늘의 하나")
                        }
                        // 한 줄이면 잉크가 그어지고, 길어서 여러 줄이면 취소선
                        StruckText(text: entry.title, font: Typo.row, done: entry.done)
                            .foregroundStyle(entry.done ? Ink.text3 : Ink.text)
                            .calm(Motion.soft, value: entry.done)
                    }
                    Text(meta).font(Typo.meta).foregroundStyle(Ink.text2).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 9)
                .padding(.trailing, 4)
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("row.\(entry.title)")
            .accessibilityHint("고치기")
        }
        .frame(minHeight: Metric.rowMin)
        .background(ground)
    }
}

struct TodoMenu: View {
    @Environment(Store.self) private var store
    let entry: Entry
    let sheet: DaySheet
    var onEdit: () -> Void
    var body: some View {
        let moves = TodoMoves(entry: entry, store: store)
        let bands = moves.otherBands(sheet)
        Button { onEdit() } label: { Label("고치기", systemImage: "pencil") }
        if !entry.done {
            Button { store.pin(entry) } label: { Label(entry.pinned ? "하나에서 빼기" : "오늘의 하나로", systemImage: entry.pinned ? "pin.slash" : "pin") }
            Button { store.cover = .focus(entry) } label: { Label("집중 시작", systemImage: "timer") }
            Button { store.splitting = SplitRequest(title: entry.title, due: nil, part: entry.part) } label: {
                Label("작게 쪼개기", systemImage: "square.split.2x1")
            }
        }
        Divider()
        if !bands.isEmpty {
            Menu {
                ForEach(bands) { p in
                    Button(Fmt.ro(p.name)) { store.move(entry, to: entry.day, part: p) }
                }
            } label: { Label("다른 띠로", systemImage: "arrow.up.arrow.down") }
        }
        if entry.day != store.today {
            Button { store.move(entry, to: store.today, part: store.settings.parts.part(at: minuteOfDay(store.now))) } label: {
                Label("오늘로", systemImage: "arrow.down.to.line")
            }
        }
        if !entry.done {
            Button { moves.toNextDay() } label: { Label(Fmt.ro(moves.nextDayTitle), systemImage: "arrow.right") }
            Button { store.move(entry, to: nil) } label: { Label("나중에", systemImage: "tray") }
            Button { store.toWorry(entry) } label: { Label("걱정 상자로", systemImage: "moon") }
        }
        Divider()
        Button(role: .destructive) { store.delete(entry) } label: { Label("지우기", systemImage: "trash") }
    }
}

/// 약속: 꽉 찬 덩어리. 지난 약속은 테두리만. 기기 달력 약속은 옅은 바탕 + 달력 색 줄.
struct EventRow: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: Entry
    var nowMinute: Int
    var onTap: () -> Void

    private var past: Bool { nowMinute >= 0 && (entry.end ?? 0) <= nowMinute }
    private var current: Bool { nowMinute >= 0 && (entry.time ?? 0) <= nowMinute && !past }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                if entry.isExternal {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: entry.color ?? 0x8B9691)).frame(width: 4).padding(.vertical, 4)
                }
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        time
                        label
                    }
                } else {
                    time.frame(minWidth: 62, alignment: .leading)
                    label
                }
                Spacer(minLength: 0)
                if entry.repeating { Image(systemName: "repeat").font(.footnote.weight(.semibold)).opacity(0.6) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: Metric.rowMin, alignment: .leading)
            .foregroundStyle(fg)
            .background(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).fill(bg))
            .overlay {
                if past { RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1) }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metric.radiusBlock, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .contextMenu {
            if !entry.isExternal {
                Button { onTap() } label: { Label("고치기", systemImage: "pencil") }
                Button { store.move(entry, to: entry.day.adding(days: 1)) } label: {
                    Label(entry.day == store.today ? "내일 같은 시각으로" : "다음 날 같은 시각으로", systemImage: "arrow.right")
                }
                Divider()
                Button(role: .destructive) { store.delete(entry) } label: { Label("지우기", systemImage: "trash") }
            }
        }
        .accessibilityLabel("\(Fmt.spoken(entry.time ?? 0)) \(entry.title), \(meta)" + (entry.repeating ? ", 반복" : ""))
        .accessibilityHint(entry.isExternal ? "기기 달력 약속" : "고치기")
        .accessibilityIdentifier("event.\(entry.title)")
    }

    private var time: some View {
        Text(Fmt.hm(entry.time ?? 0)).font(Typo.num(.title2))
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title).font(Typo.row).multilineTextAlignment(.leading)
            Text(meta).font(Typo.meta).opacity(past ? 1 : 0.8)
        }
    }

    private var meta: String {
        var s = [Fmt.dur(entry.duration)]
        if current { s.insert("지금", at: 0) }
        if let c = entry.calendarName { s.append(c) }
        return s.joined(separator: " · ")
    }
    private var bg: Color { past ? .clear : entry.isExternal ? Ink.fill : Ink.block }
    private var fg: Color { past ? Ink.text3 : entry.isExternal ? Ink.text : Ink.blockText }
}

/// 지금 줄: 다음 약속까지 실제 남은 시간과 거기 들어가는 일 하나
struct NowCard: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    let now: NowLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(Fmt.hm(now.minute)).font(Typo.num(.title2)).frame(minWidth: 62, alignment: .leading)
                Text(now.headline).font(.system(.headline, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    advice
                    action
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    advice.frame(maxWidth: .infinity, alignment: .leading)
                    action
                }
            }
        }
        .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Ink.accentText)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.accent))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("now")
    }

    private var advice: some View {
        Text(now.advice).font(.system(.subheadline, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var action: some View {
        if let fit = now.fit {
            Button { store.cover = .focus(fit) } label: {
                Text("시작").font(.system(.subheadline, weight: .bold)).padding(.horizontal, 18).frame(minHeight: Metric.tap)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.accentText))
                    .foregroundStyle(Ink.accent)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("\(fit.title) 집중 시작")
            .accessibilityIdentifier("now.start")
        } else if now.current == nil {
            Button { store.cover = .rest } label: {
                Text("식히기").font(.system(.subheadline, weight: .bold)).padding(.horizontal, 14).frame(minHeight: Metric.tap)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ink.accentText.opacity(0.7), lineWidth: 1.5))
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("now.rest")
        }
    }
}

// MARK: - 줄이 놓인 바탕

/// 할 일 줄은 밀어서 끝낼 때 아래 색을 가리려고 바탕을 칠한다 — 그 색은 줄이 놓인 종이와 같아야 한다 (칸 카드 안에서는 종이색)
private struct RowGroundKey: EnvironmentKey { static let defaultValue: Color = Ink.ground }
extension EnvironmentValues {
    var rowGround: Color {
        get { self[RowGroundKey.self] }
        set { self[RowGroundKey.self] = newValue }
    }
}

// MARK: - 하루 띠

/// 화면 위에 늘 떠 있는 하루의 자: 아침 | 낮 | 저녁. 칸마다 얼마나 찼는지, 지금이 어디인지 한눈에. 누르면 그 칸으로 간다.
struct DayRuler: View {
    let sheet: DaySheet
    var onTap: (Band) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(sheet.bands) { band in
                Button { Haptic.tick(); onTap(band) } label: { segment(band) }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("\(band.part.name) 칸" + (band.live ? ", 지금" : band.gone ? ", 지나감" : "") + ", " + note(band))
                    .accessibilityIdentifier("ruler.\(band.part.rawValue)")
            }
        }
    }

    private func note(_ b: Band) -> String {
        if b.gone { return "지나감" }
        if b.overflow > 0 { return "\(Fmt.dur(b.overflow)) 넘쳐" }
        return "빈 \(Fmt.dur(b.free))"
    }

    private func segment(_ b: Band) -> some View {
        // 넣은 일 ÷ (넣은 일 + 남은 빈 시간) — 칸 머리의 '넣은 일 · 빈'과 같은 수
        let fill = b.planned + b.free > 0 ? min(1, Double(b.planned) / Double(b.planned + b.free)) : 0
        let span = max(1, b.range.upperBound - b.range.lowerBound)
        let now = b.live ? sheet.now.map { min(1, max(0, Double($0.minute - b.range.lowerBound) / Double(span))) } : nil
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(b.part.name).font(Typo.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(b.live ? Ink.accent : b.gone ? Ink.text3 : Ink.text)
                Spacer(minLength: 2)
                Text(note(b)).font(.system(.caption2, weight: b.overflow > 0 && !b.gone ? .bold : .regular))
                    .foregroundStyle(b.overflow > 0 && !b.gone ? Ink.text : Ink.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.rule).frame(height: 4)
                    // 넣은 일이 그 칸의 빈 시간을 얼마나 채웠나
                    Capsule().fill(b.gone ? Ink.text3 : (b.live ? Ink.accent : Ink.text))
                        .frame(width: g.size.width * fill, height: 4)
                    if let now {
                        // 지금: 칸 안에서의 자리 (막대 위로 솟은 눈금)
                        Capsule().fill(Ink.text).frame(width: 2.5, height: 11)
                            .offset(x: min(g.size.width - 2.5, g.size.width * now), y: 0)
                    }
                }
                .frame(height: g.size.height)
            }
            .frame(height: 11)
            .calm(Motion.soft, value: fill)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(b.live ? Ink.accentSoft : .clear))
        .contentShape(Rectangle())
    }
}
