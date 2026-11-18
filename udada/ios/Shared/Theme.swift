import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// 우다다 v5 디자인 토큰 — 「차분한 종이 시간표」
// 종이 위에 먹색 글자. 강조색은 하나(지금 · 주 동작), 쉼은 박하. 테마는 이 규칙 안에서 색만 바꾼다 (Palette).
// 층은 그림자 대신 톤 차이로. 그라데이션 · 글래스 · 빛 번짐 없음.

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(uiColor: UIColor(hex: hex, alpha: alpha)) }
    /// 밝은 화면 / 어두운 화면 색
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}
#else
extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(nsColor: NSColor(hex: hex, alpha: alpha)) }
    /// 밝은 화면 / 어두운 화면 색
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light) })
    }
}
#endif

/// 테마 한 벌: 토큰마다 (밝은 화면, 어두운 화면).
struct Palette {
    typealias Pair = (UInt32, UInt32)
    var ground: Pair, sheet: Pair, fill: Pair, rule: Pair
    var text: Pair, text2: Pair, text3: Pair
    var block: Pair, blockText: Pair, blockText2: Pair
    var accent: Pair, accentText: Pair, accentSoft: Pair
    var mint: Pair, mintText: Pair
    var stamp: Pair

    /// 종이: 연한 회녹색 종이 · 먹 · 코발트 (처음부터 쓰던 색)
    static let paper = Palette(
        ground: (0xF1F3EE, 0x0D1311), sheet: (0xFBFCF9, 0x161E1B), fill: (0xE6EAE4, 0x1F2925), rule: (0xD8DED8, 0x29342F),
        text: (0x19221F, 0xE6EDE9), text2: (0x56645E, 0x9DABA5), text3: (0x8B9691, 0x6C7A74),
        block: (0x22302A, 0xDCE6E0), blockText: (0xF1F5F1, 0x111916), blockText2: (0xB4C2BB, 0x46544E),
        accent: (0x2E4AE3, 0x8399FF), accentText: (0xFFFFFF, 0x0A0F22), accentSoft: (0xE2E7FC, 0x1C2446),
        mint: (0xCDE8DD, 0x1E3B32), mintText: (0x1D4A3C, 0xBFE4D5), stamp: (0xD2452C, 0xFF7B5E))
    /// 모래: 따뜻한 미색 종이 · 고동 먹 · 주홍. 도장은 쪽빛 (강조가 붉어서)
    static let sand = Palette(
        ground: (0xF4EFE6, 0x15120E), sheet: (0xFCF9F3, 0x1E1A15), fill: (0xEAE3D6, 0x29241D), rule: (0xDDD5C6, 0x342E26),
        text: (0x231E18, 0xEDE6DA), text2: (0x6A5F52, 0xADA291), text3: (0x9A8F80, 0x7A7061),
        block: (0x2E2620, 0xE6DDCF), blockText: (0xF6F1E8, 0x1A1612), blockText2: (0xC4B8A6, 0x564C40),
        accent: (0xC4472B, 0xFF8A6B), accentText: (0xFFFFFF, 0x2A0E06), accentSoft: (0xF8E1D9, 0x46211A),
        mint: (0xE3E8CF, 0x2F3A22), mintText: (0x3F4A25, 0xCFDDB0), stamp: (0x2B3A8C, 0x8FA0FF))
    /// 숲: 이끼 낀 종이 · 솔잎 초록. 쉼은 하늘빛
    static let forest = Palette(
        ground: (0xEEF2EA, 0x0E1410), sheet: (0xF9FBF6, 0x161F19), fill: (0xE1E8DC, 0x1F2A22), rule: (0xD2DBCC, 0x2A372D),
        text: (0x18221B, 0xE4ECE5), text2: (0x53635A, 0x9BAB9F), text3: (0x88968C, 0x6A796E),
        block: (0x213226, 0xDAE6DC), blockText: (0xEFF5EF, 0x101A13), blockText2: (0xB2C2B6, 0x45544A),
        accent: (0x1F7A4D, 0x6FD39B), accentText: (0xFFFFFF, 0x062014), accentSoft: (0xDCEFE3, 0x173A28),
        mint: (0xD5E4F0, 0x1D3140), mintText: (0x1E4460, 0xBBD8EE), stamp: (0xD2452C, 0xFF7B5E))
    /// 자두: 연보라 종이 · 자두빛
    static let plum = Palette(
        ground: (0xF3EFF2, 0x141015), sheet: (0xFCF9FB, 0x1E1820), fill: (0xEAE3E8, 0x2A222C), rule: (0xDDD3DA, 0x362C38),
        text: (0x221A23, 0xECE4ED), text2: (0x655868, 0xAB9FAE), text3: (0x968A99, 0x776C7A),
        block: (0x2E2430, 0xE4DAE6), blockText: (0xF5EFF6, 0x18111A), blockText2: (0xC2B4C6, 0x54485A),
        accent: (0x8A3FA0, 0xD79BE8), accentText: (0xFFFFFF, 0x260A2E), accentSoft: (0xF0E0F4, 0x3A1E44),
        mint: (0xD9E9E0, 0x1F3A2E), mintText: (0x1F4A38, 0xBFE4D2), stamp: (0xD2452C, 0xFF7B5E))
    /// 먹: 무채색. 강조도 먹이고, 색은 '오늘 끝' 도장에만
    static let ink = Palette(
        ground: (0xF2F2F0, 0x101010), sheet: (0xFBFBFA, 0x1A1A1A), fill: (0xE6E6E3, 0x252525), rule: (0xD8D8D4, 0x323232),
        text: (0x1A1A1A, 0xEDEDED), text2: (0x5E5E5C, 0xA3A3A3), text3: (0x8F8F8C, 0x727272),
        block: (0x242424, 0xE4E4E4), blockText: (0xF4F4F4, 0x141414), blockText2: (0xBABABA, 0x4E4E4E),
        accent: (0x1A1A1A, 0xF2F2F2), accentText: (0xFFFFFF, 0x111111), accentSoft: (0xE4E4E1, 0x2C2C2C),
        mint: (0xE0E6E0, 0x263026), mintText: (0x2E3A2E, 0xC8D6C8), stamp: (0xD2452C, 0xFF7B5E))

    static func of(_ id: ThemeID) -> Palette {
        switch id {
        case .paper: .paper
        case .sand: .sand
        case .forest: .forest
        case .plum: .plum
        case .ink: .ink
        }
    }
}

/// 색 토큰. 화면은 Ink.text 처럼 이름으로만 쓰고, 값은 지금 테마의 Palette 에서 온다.
/// 테마를 바꾸면(Ink.theme) 다음에 그려질 때 새 색이 나온다 — 앱은 뿌리 뷰에 .id(theme) 를 걸어 다시 그린다.
enum Ink {
    private static let key = "udada.theme"
    private static var defaults: UserDefaults { UserDefaults(suiteName: DataFile.group) ?? .standard }
    private static var cached: ThemeID?

    /// 지금 테마. 앱 그룹에 적어 두어 위젯도 같은 색으로 그린다.
    static var theme: ThemeID {
        get {
            if let cached { return cached }
            let t = defaults.string(forKey: key).flatMap(ThemeID.init(rawValue:)) ?? .paper
            cached = t
            return t
        }
        set {
            cached = newValue
            defaults.set(newValue.rawValue, forKey: key)
        }
    }

    private static var p: Palette { Palette.of(theme) }
    private static func c(_ pair: Palette.Pair) -> Color { Color.dyn(pair.0, pair.1) }

    /// 앱 바탕 (종이)
    static var ground: Color { c(p.ground) }
    /// 한 겹 올라온 면 (시트 · 입력줄 · 카드)
    static var sheet: Color { c(p.sheet) }
    /// 칩 꺼짐 · 입력칸 바탕
    static var fill: Color { c(p.fill) }
    /// 가는 줄
    static var rule: Color { c(p.rule) }
    /// 글자
    static var text: Color { c(p.text) }
    static var text2: Color { c(p.text2) }
    static var text3: Color { c(p.text3) }
    /// 약속 덩어리 (박힌 것은 꽉 채운다)
    static var block: Color { c(p.block) }
    static var blockText: Color { c(p.blockText) }
    static var blockText2: Color { c(p.blockText2) }
    /// 강조: 지금 · 다음에 누를 것 하나
    static var accent: Color { c(p.accent) }
    static var accentText: Color { c(p.accentText) }
    static var accentSoft: Color { c(p.accentSoft) }
    /// 쉼
    static var mint: Color { c(p.mint) }
    static var mintText: Color { c(p.mintText) }
    /// 하루 닫기 도장
    static var stamp: Color { c(p.stamp) }
    /// 쉬는 화면 (밤) — 테마와 상관없이 어둡다
    static let night = Color(hex: 0x0B1210)
    static let nightText = Color(hex: 0xDCE8E2)
    static let nightSoft = Color(hex: 0x7F928B)
    static let nightLine = Color(hex: 0x23302B)

    static func hex(_ v: UInt32) -> Color { Color(hex: v) }

    /// 테마를 고르는 화면의 견본 (그 테마의 색으로, 지금 테마와 상관없이)
    static func swatch(_ id: ThemeID) -> (ground: Color, sheet: Color, text: Color, accent: Color, block: Color) {
        let q = Palette.of(id)
        return (c(q.ground), c(q.sheet), c(q.text), c(q.accent), c(q.block))
    }
}

enum Typo {
    static let serifName = "GowunBatang-Bold"

    /// 부드러운 명조 — 띠 이름 · 화면 제목 · 큰 문장 (앱이 쓰는 글에만. 사용자 글은 시스템 글꼴)
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(serifName, size: size, relativeTo: style)
    }
    /// 좁은 숫자 — 시각 · 날짜 · 개수
    static func num(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, design: .default, weight: weight).width(.condensed).monospacedDigit()
    }
    static func num(size: CGFloat, _ weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .body) -> Font {
        #if canImport(UIKit)
        return .system(size: UIFontMetrics(forTextStyle: style.uiStyle).scaledValue(for: size), weight: weight).width(.condensed).monospacedDigit()
        #else
        return .system(size: size, weight: weight).width(.condensed).monospacedDigit()
        #endif
    }

    static let title = Font.system(.title2, weight: .bold)
    static let row = Font.system(.body, weight: .semibold)
    static let meta = Font.system(.footnote)
    static let label = Font.system(.subheadline, weight: .semibold)
    static let button = Font.system(.headline, weight: .semibold)
    static let caption = Font.system(.caption, weight: .medium)
}

#if canImport(UIKit)
extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
#endif

// MARK: - 모션
// 한 가지 성격만: 튀지 않고 가라앉는다. 빠르기 셋(작은 반응 · 줄의 드나듦 · 화면 바뀜)과 숨 하나.
// '동작 줄이기'를 켜면 .calm 이 자리 이동 없이 바로 바꾼다.
enum Motion {
    /// 눌림 · 체크 같은 작은 반응
    static let quick = Animation.spring(response: 0.26, dampingFraction: 0.84)
    /// 줄이 들어오고 나가고 자리를 바꿀 때
    static let soft = Animation.spring(response: 0.42, dampingFraction: 0.9)
    /// 카드·화면이 바뀔 때
    static let page = Animation.spring(response: 0.56, dampingFraction: 0.92)
    /// 숨 한 번 들이쉬는 길이 (기다림 · 쉼)
    static let breath = Animation.easeInOut(duration: 4.2)

    /// 아래에서 살짝 올라오며 나타나고, 그 자리에서 옅어지며 사라진다
    static var rise: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity.combined(with: .scale(scale: 0.98)))
    }
    /// 줄 하나가 접히듯 드나든다
    static var row: AnyTransition { .opacity.combined(with: .scale(scale: 0.97, anchor: .leading)) }
}

private struct Calm<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    var animation: Animation
    var value: V
    func body(content: Content) -> some View { content.animation(reduce ? nil : animation, value: value) }
}

extension View {
    /// 값이 바뀔 때 부드럽게 (동작 줄이기를 켰으면 바로)
    func calm<V: Equatable>(_ animation: Animation = Motion.soft, value: V) -> some View { modifier(Calm(animation: animation, value: value)) }
}

/// 끝낸 일 위에 잉크가 왼쪽에서 오른쪽으로 그어진다 (한 줄 글에만 — 여러 줄이면 그냥 취소선을 쓴다).
struct InkStrike: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    var on: Bool
    var color: Color = Ink.text3
    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            GeometryReader { g in
                Capsule().fill(color)
                    .frame(width: on ? g.size.width : 0, height: 1.5)
                    .offset(y: g.size.height / 2)
                    .animation(reduce ? nil : .easeOut(duration: 0.34), value: on)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// 끝내면 잉크가 그어지는 할 일 이름. 한 줄이면 왼쪽에서 오른쪽으로 긋고, 여러 줄이면 취소선을 쓴다.
/// 한 줄인지는 재서 정한다 — 끝낼 때 글자 뷰를 갈아 끼우면(ViewThatFits) 긋는 움직임이 끊기고 통째로 나타난다.
struct StruckText: View {
    var text: String
    var font: Font
    var done: Bool
    var lineLimit: Int? = nil
    @State private var height: CGFloat = 0
    @State private var lineHeight: CGFloat = 0

    private var oneLine: Bool { lineHeight > 0 && height < lineHeight * 1.5 }

    var body: some View {
        Text(text).font(font)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .strikethrough(done && !oneLine, color: Ink.text3)
            // 글자의 높이와 같은 글꼴 한 줄의 높이를 재서 한 줄인지 가린다 (preference 로 — 숨긴 뷰의 onAppear 는 믿을 수 없다)
            .background { GeometryReader { g in Color.clear.preference(key: TextHeightKey.self, value: g.size.height) } }
            .onPreferenceChange(TextHeightKey.self) { height = $0 }
            .background {
                Text("가").font(font).lineLimit(1).fixedSize().hidden()
                    .background { GeometryReader { g in Color.clear.preference(key: LineHeightKey.self, value: g.size.height) } }
            }
            .onPreferenceChange(LineHeightKey.self) { lineHeight = $0 }
            .modifier(InkStrike(on: done && oneLine))
    }
}

private struct TextHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct LineHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// 천천히 숨 쉬는 먹점. 기다림·쉼의 자리에 돌아가는 표시 대신 쓴다. 동작 줄이기를 켰으면 가만히 있다.
struct BreathDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    var size: CGFloat = 10
    var color: Color = Ink.accent
    @State private var out = false
    var body: some View {
        Circle().fill(color)
            .frame(width: size, height: size)
            .scaleEffect(reduce ? 1 : (out ? 1 : 0.55))
            .opacity(reduce ? 0.8 : (out ? 0.9 : 0.35))
            .frame(width: size, height: size)
            .onAppear { if !reduce { withAnimation(Motion.breath.repeatForever(autoreverses: true)) { out = true } } }
            .accessibilityHidden(true)
    }
}

enum Metric {
    static let gutter: CGFloat = 20
    static let radiusBlock: CGFloat = 12
    static let radiusCard: CGFloat = 22
    static let radiusButton: CGFloat = 16
    static let radiusChip: CGFloat = 10
    static let rowMin: CGFloat = 52
    static let tap: CGFloat = 44
}

extension Part {
    /// 세로쓰기용 (한 글자씩)
    var vertical: [String] { name.map(String.init) }
}
