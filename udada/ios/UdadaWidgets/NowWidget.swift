import SwiftUI
import WidgetKit

// 잠금 화면 「지금」: 다음 약속까지 남은 시간 · 오늘 할 일 끝낸 만큼 · 한 줄 요약.

struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "udada.now", provider: WDayProvider()) { entry in
            NowWidgetView(entry: entry)
                .containerBackground(Ink.ground, for: .widget)
                .widgetURL(WLink.today)
        }
        .configurationDisplayName("지금")
        .description("다음 약속까지 남은 시간과 오늘 할 일.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NowWidgetView: View {
    let entry: WDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View { NowWidgetContent(entry: entry, family: family) }
}

struct NowWidgetContent: View {
    let entry: WDayEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular: WNowCircular(sheet: entry.sheet)
        case .accessoryInline: Text(WNowText.inline(entry.sheet))
        default: WNowRectangular(entry: entry)
        }
    }
}

enum WNowText {
    /// 15:00 치과 · 할 일 3 — 이름이 길면 줄여서 뒤쪽 개수가 잘리지 않게
    static func inline(_ sheet: DaySheet) -> String {
        let todos = sheet.openTodos > 0 ? "할 일 \(sheet.openTodos)" : "할 일 없음"
        if let cur = sheet.now?.current { return "\(short(cur.title)) 중 · \(todos)" }
        if let next = sheet.now?.next, let t = next.time { return "\(Fmt.hm(t)) \(short(next.title)) · \(todos)" }
        return "약속 없음 · \(todos)"
    }

    static func short(_ s: String, _ n: Int = 8) -> String {
        s.count <= n ? s : String(s.prefix(n - 1)) + "…"
    }
}

/// 잠금 화면 사각: 약속 이름 / 시각 · 남은 시간 / 할 일
struct WNowRectangular: View {
    let entry: WDayEntry

    var body: some View {
        let sheet = entry.sheet
        VStack(alignment: .leading, spacing: 0) {
            if let cur = sheet.now?.current, let end = cur.end {
                title(cur.title)
                timeLine(lead: "\(Fmt.hm(end))까지", target: wDate(sheet.day, minute: end), tail: "남음")
                todoLine(sheet)
            } else if let next = sheet.now?.next, let t = next.time {
                title(next.title)
                timeLine(lead: Fmt.hm(t), target: wDate(sheet.day, minute: t), tail: "뒤")
                todoLine(sheet)
            } else {
                title("남은 약속 없음")
                Text(entry.wantsClose ? "하루 닫고 쉬자." : (sheet.now?.advice ?? "할 일 \(sheet.openTodos)"))
                    .font(Typo.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ s: String) -> some View {
        Text(s).font(.headline).widgetAccentable().lineLimit(1)
    }

    private func timeLine(lead: String, target: Date, tail: String) -> some View {
        WCountdown(from: entry.date, to: target, font: Typo.num(.subheadline, .bold), color: .primary,
                   lead: Text(lead + " · ").font(Typo.num(.subheadline, .medium)).foregroundStyle(.secondary),
                   tail: Text(" " + tail).font(Typo.caption).foregroundStyle(.secondary))
    }

    private func todoLine(_ sheet: DaySheet) -> some View {
        Text(sheet.openTodos > 0 ? "할 일 \(sheet.openTodos)개 남음" : "할 일 다 끝냈어")
            .font(Typo.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// 잠금 화면 원: 고리 = 끝낸 만큼, 가운데 = 남은 할 일 (다 끝내면 체크)
struct WNowCircular: View {
    let sheet: DaySheet

    var body: some View {
        let total = sheet.openTodos + sheet.doneTodos
        Gauge(value: Double(sheet.doneTodos), in: 0...Double(max(1, total))) {
            Text("할 일")
        } currentValueLabel: {
            if total > 0 && sheet.openTodos == 0 {
                Image(systemName: "checkmark")
                    .font(.title3.weight(.bold))
            } else {
                VStack(spacing: -1) {
                    Text("\(sheet.openTodos)")
                        .font(Typo.num(.title2, .bold))
                    Text("할 일")
                        .font(Typo.num(.caption2, .semibold))
                }
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

#Preview("잠금 · 사각", as: .accessoryRectangular) {
    NowWidget()
} timeline: {
    WSample.entry(now: WSample.at(560))
    WSample.entry(now: WSample.at(1400))
}

#Preview("잠금 · 원", as: .accessoryCircular) {
    NowWidget()
} timeline: {
    WSample.entry(now: WSample.at(800))
}

#Preview("잠금 · 한 줄", as: .accessoryInline) {
    NowWidget()
} timeline: {
    WSample.entry(now: WSample.at(800))
}
