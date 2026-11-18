import SwiftUI
import WidgetKit

// 홈 화면 「오늘」: 작게(지금) · 중간(세 띠) · 크게(하루 한 장).

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "udada.today", provider: WDayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(Ink.ground, for: .widget)
        }
        .configurationDisplayName("오늘")
        .description("다음 약속까지 남은 시간과 세 띠의 할 일.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayWidgetView: View {
    let entry: WDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View { TodayWidgetContent(entry: entry, family: family) }
}

/// 크기를 밖에서 받는 본문 (미리보기 하네스가 크기별로 그릴 수 있게)
struct TodayWidgetContent: View {
    let entry: WDayEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                if entry.sheet.isEmpty { WEmptyDay(entry: entry, small: true) } else { WNowSmall(entry: entry) }
            case .systemMedium:
                if entry.sheet.isEmpty { WEmptyDay(entry: entry, small: false) } else { WBandsMedium(entry: entry) }
            default:
                // 큰 위젯은 비어 있어도 세 띠의 틀을 보인다 — 하루 한 장이 어떻게 생겼는지 바로 보이게
                WDayLarge(entry: entry)
            }
        }
        .widgetURL(url)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// 작은 위젯은 통째로 한 버튼: 빈 날엔 적기, 닫을 때엔 하루 닫기
    private var url: URL {
        guard family == .systemSmall else { return WLink.today }
        if entry.sheet.isEmpty { return WLink.add }
        return entry.wantsClose ? WLink.close : WLink.today
    }
}

// MARK: - 빈 하루

struct WEmptyDay: View {
    let entry: WDayEntry
    let small: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(wDateLabel(entry.sheet.day))
                .font(Typo.num(.caption, .semibold))
                .foregroundStyle(Ink.text2)
                .wSecondary()
            Spacer(minLength: 0)
            Text("비어 있어.\n한 줄 적어 봐.")
                .font(Typo.serif(small ? 17 : 19, relativeTo: .title3))
                .foregroundStyle(Ink.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if small {
                WPill(title: "적기", symbol: "plus")
            } else {
                Link(destination: WLink.add) { WPill(title: "적기", symbol: "plus") }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - 작게: 지금

struct WNowSmall: View {
    let entry: WDayEntry

    var body: some View {
        let sheet = entry.sheet
        let now = sheet.now
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("지금")
                    .font(Typo.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(Ink.accent)
                    .widgetAccentable()
                Spacer(minLength: 0)
                if let live = sheet.bands.first(where: \.live) {
                    Text(live.part.name)
                        .font(Typo.serif(12, relativeTo: .caption))
                        .foregroundStyle(Ink.text3)
                        .wSecondary()
                }
            }
            Spacer(minLength: 6)
            if let cur = now?.current, let end = cur.end {
                WEventBlock(entry: cur, font: Typo.label)
                countdown(to: wDate(sheet.day, minute: end), label: "남음")
                Spacer(minLength: 6)
                caption(now?.advice ?? "")
            } else if let next = now?.next, let t = next.time {
                WEventBlock(entry: next, font: Typo.label)
                countdown(to: wDate(sheet.day, minute: t), label: "뒤")
                Spacer(minLength: 6)
                if let fit = now?.fit {
                    // 이 틈에 들어가는 일: 칸을 누르면 위젯에서 바로 끝난다
                    Text("이 틈에")
                        .font(Typo.caption)
                        .foregroundStyle(Ink.text3)
                        .wSecondary()
                    WTodoRow(entry: fit, showDuration: true, font: Typo.caption)
                        .padding(.horizontal, -2)
                } else {
                    caption(now?.advice ?? "")
                }
            } else {
                Text(entry.wantsClose ? "오늘 약속 끝" : "남은 약속 없음")
                    .font(Typo.label)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sheet.openTodos)")
                        .font(Typo.num(size: 30))
                        .foregroundStyle(Ink.text)
                        .widgetAccentable()
                    Text(sheet.openTodos == 0 ? "다 끝냈어" : "할 일 남음")
                        .font(Typo.caption)
                        .foregroundStyle(Ink.text2)
                        .wSecondary()
                }
                Spacer(minLength: 6)
                if entry.wantsClose {
                    WPill(title: "하루 닫기", symbol: "seal", filled: false)
                } else {
                    caption(now?.advice ?? "")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func caption(_ s: String) -> some View {
        Text(s)
            .font(Typo.caption)
            .foregroundStyle(Ink.text2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .wSecondary()
    }

    private func countdown(to target: Date, label: String) -> some View {
        WCountdown(from: entry.date, to: target, font: Typo.num(size: 30),
                   tail: Text(" " + label).font(Typo.caption).foregroundStyle(Ink.text2))
            .widgetAccentable()
            .minimumScaleFactor(0.6)
            .padding(.top, 4)
    }
}

// MARK: - 중간: 세 띠

struct WBandsMedium: View {
    let entry: WDayEntry
    private let perBand = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(wDateLabel(entry.sheet.day))
                    .font(Typo.num(.caption, .semibold))
                    .foregroundStyle(Ink.text2)
                    .wSecondary()
                if let cur = entry.sheet.now?.current, let end = cur.end {
                    Text("·").font(Typo.caption).foregroundStyle(Ink.text3).wSecondary()
                    WUntil(title: cur.title, from: entry.date, to: wDate(entry.sheet.day, minute: end), joint: " 끝까지 ")
                } else if let next = entry.sheet.now?.next, let t = next.time {
                    Text("·").font(Typo.caption).foregroundStyle(Ink.text3).wSecondary()
                    WUntil(title: next.title, from: entry.date, to: wDate(entry.sheet.day, minute: t))
                }
                Spacer(minLength: 0)
                Link(destination: WLink.add) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Ink.text2)
                        .frame(width: 28, height: 18, alignment: .trailing)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(entry.sheet.bands) { band in
                    column(band)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func column(_ band: Band) -> some View {
        let rows = wRows(band)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                WBandName(band: band, size: 14)
                Spacer(minLength: 0)
                WMore(count: rows.count - perBand)
            }
            .padding(.bottom, 1)
            WBandRule(live: band.live)
            if rows.isEmpty {
                Text(band.gone ? "지났어" : "비어 있어")
                    .font(Typo.caption)
                    .foregroundStyle(Ink.text3)
                    .wSecondary()
                    .padding(.vertical, 3)
            }
            ForEach(rows.prefix(perBand)) { e in
                WRow(entry: e)
            }
        }
        .opacity(band.gone ? 0.55 : 1)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - 크게: 하루 한 장

struct WDayLarge: View {
    let entry: WDayEntry
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let sheet = entry.sheet
        let footer = sheet.isEmpty || closeEvening
        // 줄 수: 큰 글씨면 덜 (위젯은 .xLarge 까지만 키운다)
        let budget = (entry.compact ? 6 : 8) - (footer ? 1 : 0) - (typeSize > .large ? 2 : 0)
        let allot = wAllot(sheet.bands, budget: budget)
        VStack(alignment: .leading, spacing: entry.compact ? 6 : 8) {
            header(sheet)
            ForEach(sheet.bands) { band in
                section(band, show: allot[band.part] ?? 0)
            }
            Spacer(minLength: 0)
            if sheet.isEmpty {
                Link(destination: WLink.add) {
                    footerButton("한 줄 적어 봐", symbol: "plus", tint: Ink.accent)
                }
            } else if closeEvening {
                Link(destination: WLink.close) {
                    footerButton("하루 닫기", symbol: "seal", tint: Ink.text)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 닫을 때가 됐으면 (닫기 알림 1시간 전부터)
    private var closeEvening: Bool {
        guard let m = entry.sheet.now?.minute else { return false }
        return m >= entry.closeFrom
    }

    private func footerButton(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(Typo.label)
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: Metric.radiusChip, style: .continuous)
                .strokeBorder(tint.opacity(0.85), lineWidth: 1.2)
        }
        .widgetAccentable()
    }

    private func header(_ sheet: DaySheet) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(wDateLabel(sheet.day))
                    .font(Typo.num(.subheadline, .bold))
                    .foregroundStyle(Ink.text)
                if let cur = sheet.now?.current, let end = cur.end {
                    WUntil(title: cur.title, from: entry.date, to: wDate(sheet.day, minute: end), joint: " 끝까지 ")
                } else if let next = sheet.now?.next, let t = next.time {
                    WUntil(title: next.title, from: entry.date, to: wDate(sheet.day, minute: t))
                } else if !sheet.isEmpty {
                    Text(sheet.openTodos == 0 ? "할 일 다 끝냈어" : "남은 약속 없음 · 할 일 \(sheet.openTodos)")
                        .font(Typo.caption)
                        .foregroundStyle(Ink.text2)
                        .wSecondary()
                }
            }
            Spacer(minLength: 0)
            Link(destination: WLink.add) { WAddDot() }
        }
    }

    private func section(_ band: Band, show: Int) -> some View {
        let rows = wRows(band)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                WBandName(band: band, size: 15)
                if band.live {
                    Text("지금")
                        .font(Typo.caption)
                        .foregroundStyle(Ink.accent)
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                WMore(count: rows.count - show)
                Text("\(Fmt.hm(band.range.lowerBound))–\(Fmt.hm(band.range.upperBound))")
                    .font(Typo.num(.caption2, .medium))
                    .foregroundStyle(Ink.text3)
                    .wSecondary()
            }
            WBandRule(live: band.live)
                .padding(.bottom, 2)
            if rows.isEmpty {
                Text(band.gone ? "지났어" : "비어 있어")
                    .font(Typo.caption)
                    .foregroundStyle(Ink.text3)
                    .wSecondary()
                    .padding(.vertical, 2)
            }
            ForEach(rows.prefix(show)) { e in
                WRow(entry: e, showDuration: true, font: Typo.meta)
            }
        }
        .opacity(band.gone ? 0.55 : 1)
    }
}

/// 큰 위젯의 적기 버튼: 종이 위에선 코발트 원, 강조/투명 모드에선 테두리 원
struct WAddDot: View {
    @Environment(\.widgetRenderingMode) private var mode
    var body: some View {
        let full = mode == .fullColor
        Image(systemName: "plus")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(full ? Ink.accentText : Ink.accent)
            .frame(width: 30, height: 30)
            .background {
                if full { Circle().fill(Ink.accent) } else { Circle().strokeBorder(Ink.accent, lineWidth: 1.2) }
            }
            .widgetAccentable()
    }
}

/// 「치과까지 40분」: 이름은 미리 줄여 숫자가 잘리지 않게
struct WUntil: View {
    let title: String
    let from: Date
    let to: Date
    var joint = "까지 "
    var body: some View {
        WCountdown(from: from, to: to, font: Typo.num(.caption, .bold),
                   lead: Text(WNowText.short(title, 12) + joint).font(Typo.caption).foregroundStyle(Ink.text2))
            .widgetAccentable()
    }
}

/// 띠 밑줄: 지금 띠는 코발트로 조금 굵게
struct WBandRule: View {
    let live: Bool
    var body: some View {
        Rectangle()
            .fill(live ? Ink.accent : Ink.rule)
            .frame(height: live ? 1.5 : 1)
            .widgetAccentable(live)
    }
}

/// 큰 위젯의 줄 나누기: 띠마다 한 줄씩(빈 띠의 '비어 있어'도 한 줄) 먼저 주고,
/// 다음은 아직 안 지난 띠의 약속(박힌 것이 먼저 보여야 한다), 남는 줄은 지금 띠 → 다가올 띠 → 지난 띠 순으로 채운다.
func wAllot(_ bands: [Band], budget: Int) -> [Part: Int] {
    var out: [Part: Int] = [:]
    var left = budget
    for b in bands {
        out[b.part] = min(wRows(b).count, 1)
        left -= 1
    }
    func rank(_ b: Band) -> Int { b.live ? 0 : (b.gone ? 2 : 1) }
    let order = bands.sorted { rank($0) < rank($1) }
    func grow(_ b: Band, to want: Int) {
        let extra = max(0, min(want - (out[b.part] ?? 0), left))
        out[b.part, default: 0] += extra
        left -= extra
    }
    for b in order where !b.gone { grow(b, to: b.events.count) }
    for b in order { grow(b, to: wRows(b).count) }
    return out
}

// MARK: - 미리보기

#Preview("작게", as: .systemSmall) {
    TodayWidget()
} timeline: {
    WSample.entry(now: WSample.at(560))
    WSample.entry(now: WSample.at(1140))
    WDay.entry(data: AppData(), at: WSample.at(560), compact: false)
}

#Preview("중간", as: .systemMedium) {
    TodayWidget()
} timeline: {
    WSample.entry(now: WSample.at(800))
}

#Preview("크게", as: .systemLarge) {
    TodayWidget()
} timeline: {
    WSample.entry(now: WSample.at(800))
    WSample.entry(now: WSample.at(1150))
}
