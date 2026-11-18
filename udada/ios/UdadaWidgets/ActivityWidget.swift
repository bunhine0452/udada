import ActivityKit
import SwiftUI
import WidgetKit

// 실시간 현황: 식히기는 밤 화면(거꾸로 세기), 집중은 종이 화면(앞으로 세기).

struct UdadaActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UdadaActivity.self) { context in
            WActivityLock(state: context.state, stale: context.isStale)
                .activityBackgroundTint(context.state.mode == .rest ? Ink.night : Ink.ground)
                .activitySystemActionForegroundColor(context.state.mode == .rest ? Ink.nightText : Ink.text)
                .widgetURL(WActivity.url(context.state))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { WIslandLeading(state: s) }
                DynamicIslandExpandedRegion(.trailing) { WIslandTrailing(state: s) }
                DynamicIslandExpandedRegion(.center) { WIslandCenter(state: s) }
                DynamicIslandExpandedRegion(.bottom) { WIslandBottom(state: s) }
            } compactLeading: {
                WActivityIcon(state: s)
            } compactTrailing: {
                WIslandCompactTrailing(state: s)
            } minimal: {
                WActivityIcon(state: s)
            }
            .keylineTint(WActivity.tint(s))
            .widgetURL(WActivity.url(s))
        }
    }
}

enum WActivity {
    static func label(_ s: UdadaActivity.ContentState) -> String {
        switch s.mode {
        case .rest: s.rest?.name ?? "식히기"
        case .focus: "집중"
        }
    }

    /// 아래 줄: 식히기는 방법, 집중은 할 일 이름 (사용자 글이라 시스템 글꼴)
    static func detail(_ s: UdadaActivity.ContentState) -> String {
        switch s.mode {
        case .rest: s.rest?.how ?? "잠깐 폰을 내려 둬."
        case .focus: "\(s.title) · \(Fmt.dur(s.planned)) 예정"
        }
    }

    static func symbol(_ s: UdadaActivity.ContentState) -> String {
        switch s.mode {
        case .rest: s.rest?.symbol ?? "wind"
        case .focus: "scope"
        }
    }

    /// 다이내믹 아일랜드(늘 검은 바탕)에서 읽히는 색
    static func tint(_ s: UdadaActivity.ContentState) -> Color {
        s.mode == .rest ? Ink.hex(0xBFE4D5) : Ink.hex(0x8399FF)
    }

    static func url(_ s: UdadaActivity.ContentState) -> URL {
        URL(string: s.mode == .rest ? "udada://rest" : "udada://focus")!
    }
}

struct WActivityIcon: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        Image(systemName: WActivity.symbol(state))
            .foregroundStyle(WActivity.tint(state))
    }
}

// MARK: - 다이내믹 아일랜드 영역 (하네스가 같은 부품으로 그린다)

struct WIslandLeading: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        WActivityIcon(state: state)
            .font(.title3)
            .padding(.leading, 4)
    }
}

struct WIslandTrailing: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        WActivityTimer(state: state)
            .font(Typo.num(size: 26))
            .foregroundStyle(WActivity.tint(state))
            .frame(maxWidth: 110, alignment: .trailing)
    }
}

struct WIslandCenter: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        Text(WActivity.label(state))
            .font(Typo.serif(15, relativeTo: .subheadline))
            .foregroundStyle(Ink.nightText)
            .lineLimit(1)
    }
}

struct WIslandBottom: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WActivity.detail(state))
                .font(Typo.caption)
                .foregroundStyle(Ink.nightSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            // 남은 만큼: 식히기는 줄어들고, 집중은 예정 시간까지 차오른다
            ProgressView(timerInterval: state.start...max(state.start, state.end), countsDown: state.mode == .rest) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(WActivity.tint(state))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

struct WIslandCompactTrailing: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        WActivityTimer(state: state)
            .font(Typo.num(.caption, .bold))
            .foregroundStyle(WActivity.tint(state))
            .frame(maxWidth: 48)
    }
}

/// 식히기는 끝까지 거꾸로, 집중은 시작부터 앞으로.
struct WActivityTimer: View {
    let state: UdadaActivity.ContentState
    var body: some View {
        switch state.mode {
        case .rest:
            Text(timerInterval: state.start...max(state.start, state.end), countsDown: true)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        case .focus:
            Text(timerInterval: state.start...state.start.addingTimeInterval(12 * 3600), countsDown: false)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

/// 잠금 화면 카드
struct WActivityLock: View {
    let state: UdadaActivity.ContentState
    let stale: Bool

    var body: some View {
        switch state.mode {
        case .rest: rest
        case .focus: focus
        }
    }

    private var rest: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: WActivity.symbol(state))
                        .font(.caption.weight(.semibold))
                    Text(WActivity.label(state))
                        .font(Typo.serif(15, relativeTo: .subheadline))
                }
                .foregroundStyle(Ink.mintText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Ink.mint))
                Text(stale ? "다 쉬었어. 천천히 돌아와." : (state.rest?.how ?? "잠깐 폰을 내려 둬."))
                    .font(Typo.caption)
                    .foregroundStyle(Ink.nightSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            if stale {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Ink.mintText)
            } else {
                WActivityTimer(state: state)
                    .font(Typo.num(size: 40))
                    .foregroundStyle(Ink.nightText)
                    .frame(width: 104, alignment: .trailing)
            }
        }
        .padding(16)
        // 밤 화면: 박하 칩이 어두운 쪽 색으로 읽히게
        .environment(\.colorScheme, .dark)
    }

    private var focus: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("집중")
                    .font(Typo.serif(15, relativeTo: .subheadline))
                    .foregroundStyle(Ink.text2)
                Text(state.title)
                    .font(Typo.row)
                    .foregroundStyle(Ink.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                WActivityTimer(state: state)
                    .font(Typo.num(size: 32))
                    .foregroundStyle(Ink.accent)
                    .frame(maxWidth: 120, alignment: .trailing)
            }
            ProgressView(timerInterval: state.start...state.end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Ink.accent)
            HStack {
                Text("\(Fmt.hm(minuteOfDay(state.start))) 시작")
                Spacer(minLength: 0)
                Text("\(Fmt.dur(state.planned)) 예정")
            }
            .font(Typo.num(.caption, .medium))
            .foregroundStyle(Ink.text3)
        }
        .padding(16)
    }
}

#Preview("식히기", as: .content, using: UdadaActivity()) {
    UdadaActivityWidget()
} contentStates: {
    UdadaActivity.ContentState.rest(.far, until: Date().addingTimeInterval(180))
}

#Preview("집중", as: .content, using: UdadaActivity()) {
    UdadaActivityWidget()
} contentStates: {
    UdadaActivity.ContentState.focus(title: "보고서 초안", started: Date().addingTimeInterval(-600), planned: 25)
}

#Preview("아일랜드", as: .dynamicIsland(.expanded), using: UdadaActivity()) {
    UdadaActivityWidget()
} contentStates: {
    UdadaActivity.ContentState.rest(.breath, until: Date().addingTimeInterval(60))
}
