import SwiftUI

/// LCD 판: 검은 베젤 + 연두 화면 + 주사선.
struct LCD<Content: View>: View {
    var dark = false
    var label: String? = nil
    var badge: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if label != nil || badge != nil {
                HStack {
                    if let label { Text(label).font(Fonts.lcd(11)) }
                    Spacer()
                    if let badge {
                        Text(badge).font(Fonts.lcd(11)).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(dark ? Palette.glow.opacity(0.25) : Palette.seg)
                            .foregroundStyle(dark ? Palette.glow : Palette.lcd)
                    }
                }
                .opacity(0.85)
                Rectangle().fill((dark ? Palette.glow : Palette.seg).opacity(0.22)).frame(height: 1)
            }
            content
        }
        .foregroundStyle(dark ? Palette.glow : Palette.seg)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(dark ? Palette.lcdOff : Palette.lcd)
                .overlay(Scanlines().opacity(dark ? 0.5 : 1).clipShape(RoundedRectangle(cornerRadius: 8)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.ink))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.edge, lineWidth: 1))
    }
}

struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.035))); y += 3 }
        }
        .allowsHitTesting(false)
    }
}

/// 7세그먼트 숫자. 꺼진 세그먼트는 흐리게 남아 있다(진짜 LCD처럼). 숫자·':'·'+'·'-'·' '.
struct SevenSeg: View {
    var text: String
    var height: CGFloat = 60
    var color: Color = Palette.seg
    var ghost: Double = 0.09

    private static let map: [Character: [Int]] = [
        "0": [0, 1, 2, 3, 4, 5], "1": [1, 2], "2": [0, 1, 6, 4, 3], "3": [0, 1, 6, 2, 3], "4": [5, 6, 1, 2],
        "5": [0, 5, 6, 2, 3], "6": [0, 5, 4, 3, 2, 6], "7": [0, 1, 2], "8": [0, 1, 2, 3, 4, 5, 6], "9": [0, 1, 2, 3, 5, 6],
        "-": [6], " ": [],
    ]

    var body: some View {
        let w = height * 0.56, t = height * 0.12, gap = height * 0.14
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if ch == ":" {
                    VStack(spacing: height * 0.28) {
                        Rectangle().frame(width: t, height: t)
                        Rectangle().frame(width: t, height: t)
                    }
                    .frame(height: height).foregroundStyle(color)
                } else if ch == "+" {
                    ZStack {
                        Rectangle().frame(width: w * 0.7, height: t)
                        Rectangle().frame(width: t, height: w * 0.7)
                    }
                    .frame(width: w, height: height).foregroundStyle(color)
                } else {
                    Canvas { ctx, _ in
                        let on = Set(Self.map[ch] ?? [])
                        for i in 0..<7 {
                            ctx.fill(Self.segment(i, w: w, h: height, t: t), with: .color(color.opacity(on.contains(i) ? 1 : ghost)))
                        }
                    }
                    .frame(width: w, height: height)
                }
            }
        }
        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.08, d: 1, tx: height * 0.04, ty: 0)) // 살짝 기울임
        .accessibilityLabel(text)
    }

    /// 0 위 · 1 오른위 · 2 오른아래 · 3 아래 · 4 왼아래 · 5 왼위 · 6 가운데
    private static func segment(_ i: Int, w: CGFloat, h: CGFloat, t: CGFloat) -> Path {
        let g = t * 0.18, m = h / 2
        func hseg(_ y: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: g + t / 2, y: y)); p.addLine(to: CGPoint(x: g + t, y: y - t / 2))
            p.addLine(to: CGPoint(x: w - g - t, y: y - t / 2)); p.addLine(to: CGPoint(x: w - g - t / 2, y: y))
            p.addLine(to: CGPoint(x: w - g - t, y: y + t / 2)); p.addLine(to: CGPoint(x: g + t, y: y + t / 2)); p.closeSubpath()
            return p
        }
        func vseg(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: x, y: y0 + g)); p.addLine(to: CGPoint(x: x + t / 2, y: y0 + g + t / 2))
            p.addLine(to: CGPoint(x: x + t / 2, y: y1 - g - t / 2)); p.addLine(to: CGPoint(x: x, y: y1 - g))
            p.addLine(to: CGPoint(x: x - t / 2, y: y1 - g - t / 2)); p.addLine(to: CGPoint(x: x - t / 2, y: y0 + g + t / 2)); p.closeSubpath()
            return p
        }
        switch i {
        case 0: return hseg(t / 2)
        case 1: return vseg(w - t / 2, t / 2, m)
        case 2: return vseg(w - t / 2, m, h - t / 2)
        case 3: return hseg(h - t / 2)
        case 4: return vseg(t / 2, m, h - t / 2)
        case 5: return vseg(t / 2, t / 2, m)
        default: return hseg(m)
        }
    }
}

/// 0~10 막대 (탭·드래그로 값 고르기). 칸마다 한 번씩 딸깍.
struct ClarityBar: View {
    @Binding var value: Int
    var dark = false
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0...10, id: \.self) { i in
                    Rectangle().fill((dark ? Palette.glow : Palette.seg).opacity(i <= value ? 1 : 0.14))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let v = min(10, max(0, Int((g.location.x / geo.size.width) * 11)))
                if v != value { value = v; Feel.detent() }
            })
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel("맑기")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { dir in
            value = dir == .increment ? min(10, value + 1) : max(0, value - 1)
        }
    }
}

enum Clarity {
    static func word(_ v: Int) -> String {
        switch v { case 0...2: "안 돌아감"; case 3...4: "흐릿함"; case 5...6: "그럭저럭"; case 7...8: "맑음"; default: "쌩쌩" }
    }
}

/// 영수증: 슬롯에서 종이가 내려오며 찍힌다.
struct Receipt<Content: View>: View {
    var printed: Bool
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(hex: 0x151514)).frame(height: 12).padding(.horizontal, 4).zIndex(2)
            content
                .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.paper)
                .overlay(alignment: .bottom) { Zigzag().fill(Palette.paper).frame(height: 7).offset(y: 7) }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                .padding(.horizontal, 16)
                .offset(y: printed ? -6 : -60)
                .mask(Rectangle().padding(.top, 6).padding(.bottom, -40))
                .opacity(printed ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.7), value: printed)
    }
}

struct Zigzag: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let n = Int(r.width / 10); let w = r.width / CGFloat(max(n, 1))
        p.move(to: CGPoint(x: 0, y: 0))
        for i in 0..<max(n, 1) { p.addLine(to: CGPoint(x: CGFloat(i) * w + w / 2, y: r.height)); p.addLine(to: CGPoint(x: CGFloat(i + 1) * w, y: 0)) }
        p.closeSubpath(); return p
    }
}
