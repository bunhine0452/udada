import SwiftUI

@main
struct UdadaApp: App {
    @State private var flow = Flow()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(flow)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(Flow.self) private var flow

    var body: some View {
        ZStack {
            (flow.screen == .breath ? Palette.night : Palette.body).ignoresSafeArea()
            Group {
                switch flow.screen {
                case .intro: IntroView()
                case .home: HomeView()
                case .dump: DumpView()
                case .sort: SortView()
                case .finish: FinishView()
                case .breath: BreathView()
                case .drawer: DrawerView()
                }
            }
            .transition(.push(from: flow.forward ? .trailing : .leading))
        }
        .animation(.easeInOut(duration: 0.4), value: flow.screen == .breath)
    }
}

/// 위 막대: 브랜드 + (선택) 뒤로 + 오른쪽 무엇이든
struct TopBar<Trailing: View>: View {
    var back: (() -> Void)? = nil
    var title: String? = nil
    var dark = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let back { SmallKey(symbol: "chevron.left", action: back).accessibilityIdentifier("back").accessibilityLabel("뒤로") }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("우다다").font(Fonts.ui(21, .heavy)).kerning(-1.2)
                Text(title ?? "머릿속 정리 기계").font(Fonts.ui(11, .bold)).opacity(0.55)
            }
            .foregroundStyle(dark ? Palette.glow : Palette.ink)
            Spacer()
            trailing
        }
        .frame(height: 52)
    }
}

extension TopBar where Trailing == EmptyView {
    init(back: (() -> Void)? = nil, title: String? = nil, dark: Bool = false) {
        self.back = back; self.title = title; self.dark = dark; self.trailing = EmptyView()
    }
}

/// 종이 띠
struct PaperStrip: View {
    var label: String
    var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Fonts.mono(11, .bold)).foregroundStyle(Color(hex: 0x8A877F))
            Text(text).font(Fonts.ui(19, .heavy)).kerning(-0.6).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper)
        .shadow(color: .black.opacity(0.15), radius: 7, y: 5)
    }
}

/// 둥근 회색 판 (기록·목록)
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.body2)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.black.opacity(0.08), lineWidth: 1)))
    }
}
