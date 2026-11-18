import SwiftUI

/// 입체 키. 윗면 + 측면(두께) + 윗선 하이라이트. 누르면 윗면이 측면 높이만큼 내려앉고 딸깍.
struct KeyStyle: ButtonStyle {
    enum Tone { case plain, blue, dark, lit }
    var tone: Tone = .plain
    var radius: CGFloat = 14
    var depth: CGFloat = 6

    private var face: Color {
        switch tone { case .plain: Palette.body; case .blue: Palette.blue; case .dark: Palette.ink; case .lit: Color(hex: 0xE4E2DC) }
    }
    private var side: Color {
        switch tone { case .plain, .lit: Palette.edge; case .blue: Palette.blue2; case .dark: .black }
    }
    private var fg: Color { tone == .blue || tone == .dark ? .white : Palette.ink }

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background {
                ZStack {
                    // 윗면: 위는 밝게, 아래는 살짝 어둡게 — 오목한 키캡
                    shape.fill(face)
                    shape.fill(LinearGradient(colors: [.white.opacity(tone == .plain || tone == .lit ? 0.35 : 0.18), .clear, .black.opacity(0.06)],
                                              startPoint: .top, endPoint: .bottom))
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.0)], startPoint: .top, endPoint: .center), lineWidth: 1)
                }
            }
            .offset(y: down ? depth - 1 : 0)
            .background {
                // 측면(두께)과 바닥 그림자
                shape.fill(side).offset(y: depth)
                    .shadow(color: .black.opacity(down ? 0.10 : 0.22), radius: down ? 1 : 6, y: down ? 1 : 5)
            }
            .padding(.bottom, depth)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.12, dampingFraction: 0.55), value: down)
            .onChange(of: down) { _, isDown in isDown ? Feel.press() : Feel.release() }
    }
}

/// 키 위의 각인: 위에 작은 영문 태그, 아래 큰 라벨, 오른쪽 위 LED.
struct KeyLabel: View {
    var tag: String
    var title: String
    var sub: String? = nil
    var symbol: String? = nil
    var led: Bool? = nil
    var big: CGFloat = 19
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(tag).font(Fonts.ui(10, .heavy)).kerning(0.8).opacity(0.6)
                Spacer(minLength: 4)
                if let led { Led(on: led) }
                else if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).opacity(0.55) }
            }
            Spacer(minLength: 0)
            Text(title).font(Fonts.ui(big, .heavy)).kerning(-0.6).lineLimit(1).minimumScaleFactor(0.7)
            if let sub { Text(sub).font(Fonts.ui(11.5, .semibold)).opacity(0.62).lineLimit(2).minimumScaleFactor(0.85) }
        }
    }
}

struct Led: View {
    var on: Bool
    var body: some View {
        Circle()
            .fill(on ? Palette.blue : Color(hex: 0x9E9B93))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 0.5))
            .shadow(color: on ? Palette.blue.opacity(0.9) : .clear, radius: 4)
            .animation(.easeOut(duration: 0.15), value: on)
    }
}

/// 작은 둥근 기능 키 (뒤로·서랍 등)
struct SmallKey: View {
    var symbol: String
    var label: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 15, weight: .bold))
                if let label { Text(label).font(Fonts.ui(13, .heavy)) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle(radius: 12, depth: 4))
        .frame(width: label == nil ? 50 : 76, height: 50)
    }
}
