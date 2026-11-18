import SwiftUI
import WidgetKit

// 위젯 부품: 약속 덩어리 · 할 일 줄 · 띠 머리. 색·글꼴은 Ink / Typo 만.
// 강조/투명(잠금·StandBy·틴트) 모드에서는 꽉 찬 면이 뭉개지므로 테두리로 바꾼다.

/// 약속: 꽉 채운 먹색 덩어리. 시각은 좁은 숫자.
struct WEventBlock: View {
    let entry: Entry
    var showDuration = false
    var font: Font = Typo.caption
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.radiusBlock * 0.6, style: .continuous)
        let full = mode == .fullColor
        HStack(spacing: 5) {
            if let t = entry.time {
                Text(Fmt.hm(t))
                    .font(Typo.num(.caption2, .semibold))
                    .foregroundStyle(full ? Ink.blockText2 : Ink.text2)
            }
            Text(entry.title)
                .font(font)
                .fontWeight(.semibold)
                .foregroundStyle(full ? Ink.blockText : Ink.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showDuration {
                Text(Fmt.dur(entry.duration))
                    .font(Typo.num(.caption2, .medium))
                    .foregroundStyle(full ? Ink.blockText2 : Ink.text2)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if full { shape.fill(Ink.block) } else { shape.strokeBorder(Ink.text, lineWidth: 1) }
        }
        .widgetAccentable(!full)
    }
}

/// 할 일: 열린 줄 + 네모 칸. 줄 전체가 끝내기 버튼 (위젯 안에서 바로 돈다).
struct WTodoRow: View {
    let entry: Entry
    var showDuration = false
    var font: Font = Typo.caption

    var body: some View {
        Button(intent: ToggleEntryIntent(entryID: entry.id)) {
            HStack(spacing: 5) {
                Image(systemName: entry.done ? "checkmark.square.fill" : "square")
                    .font(font)
                    .foregroundStyle(entry.done ? Ink.text3 : Ink.text2)
                    .widgetAccentable()
                Text(entry.title)
                    .font(font)
                    .foregroundStyle(entry.done ? Ink.text3 : Ink.text)
                    .strikethrough(entry.done, color: Ink.text3)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if showDuration && !entry.done {
                    Text(Fmt.dur(entry.duration))
                        .font(Typo.num(.caption2, .medium))
                        .foregroundStyle(Ink.text3)
                        .lineLimit(1)
                        .wSecondary()
                }
            }
            .wSecondary(entry.done ? 0.45 : 1)
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 띠 안의 줄: 약속은 시각 순으로 먼저, 그다음 할 일. 끝낸 할 일은 뒤로.
func wRows(_ band: Band) -> [Entry] {
    band.events + band.todos.filter { !$0.done } + band.todos.filter(\.done)
}

/// 한 줄 그리기
struct WRow: View {
    let entry: Entry
    var showDuration = false
    var font: Font = Typo.caption

    var body: some View {
        if entry.isEvent {
            WEventBlock(entry: entry, showDuration: showDuration, font: font)
        } else {
            WTodoRow(entry: entry, showDuration: showDuration, font: font)
        }
    }
}

/// 띠 이름 (명조). 지금 띠는 코발트.
struct WBandName: View {
    let band: Band
    var size: CGFloat = 14

    var body: some View {
        Text(band.part.name)
            .font(Typo.serif(size, relativeTo: .subheadline))
            .foregroundStyle(band.live ? Ink.accent : (band.gone ? Ink.text3 : Ink.text))
            .widgetAccentable(band.live)
            .lineLimit(1)
    }
}

/// "+2"
struct WMore: View {
    let count: Int
    var body: some View {
        if count > 0 {
            Text("+\(count)")
                .font(Typo.num(.caption2, .semibold))
                .foregroundStyle(Ink.text3)
                .wSecondary()
        }
    }
}

/// 남은 시간: 「40분」「1시간 10분」. 분 단위라 초가 째깍거리지 않는다 (앱의 Fmt.dur 와 같은 모양).
/// 분은 올림으로 보이게 끝을 59초 미룬다 — 2분 50초 남으면 「3분」.
/// 살아 있는 시간 글은 위젯에서 가로를 다 차지하려 들기 때문에, 앞뒤 글과 한 Text 로 이어 붙인다
/// (HStack 으로 나란히 두면 옆 글이 0 폭으로 밀리거나 큰 틈이 생긴다 — 시뮬레이터 실제 위젯에서 확인).
struct WCountdown: View {
    let from: Date
    let to: Date
    var font: Font
    var color: Color = Ink.accent
    var lead: Text? = nil
    var tail: Text? = nil

    var body: some View {
        let end = to.addingTimeInterval(59)
        let n = Text(.currentDate, format: .timer(countingDownIn: min(from, end)..<end, showsHours: true, maxFieldCount: 2, maxPrecision: .seconds(60)))
            .font(font)
            .foregroundStyle(color)
        ((lead ?? Text(verbatim: "")) + n + (tail ?? Text(verbatim: "")))
            .lineLimit(1)
            // 앱이 한국어만 쓰니 기기 언어가 달라도 「40분」으로
            .environment(\.locale, Locale(identifier: "ko_KR"))
    }
}

/// 강조(틴트) 모드에서는 색이 다 한 색이 되므로, 보조 글자는 투명도로 층을 지킨다
struct WSecondary: ViewModifier {
    var level: Double = 0.6
    @Environment(\.widgetRenderingMode) private var mode
    func body(content: Content) -> some View {
        content.opacity(mode == .accented ? level : 1)
    }
}

extension View {
    func wSecondary(_ level: Double = 0.6) -> some View { modifier(WSecondary(level: level)) }
}

/// 누를 것 하나 (적기 · 하루 닫기): 종이 위에선 꽉 찬 코발트, 강조/투명 모드에선 테두리
struct WPill: View {
    let title: String
    let symbol: String
    var filled = true
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let solid = filled && mode == .fullColor
        Label(title, systemImage: symbol)
            .font(Typo.label)
            .foregroundStyle(solid ? Ink.accentText : (filled ? Ink.accent : Ink.text))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if solid { Capsule().fill(Ink.accent) } else { Capsule().strokeBorder(filled ? Ink.accent : Ink.text, lineWidth: 1.2) }
            }
            .widgetAccentable(filled)
    }
}

/// 11월 15일 (일)
func wDateLabel(_ k: DayKey) -> String { "\(k.m)월 \(k.d)일 (\(Fmt.weekday[k.weekday()]))" }

/// 다음/지금 약속의 시각
func wDate(_ k: DayKey, minute: Int) -> Date { k.date(minute: minute) }
