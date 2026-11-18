import SwiftUI
import UIKit

// 화면 부품. 누르는 곳은 전부 44pt 이상, 주요 동작은 화면 아래쪽(엄지 닿는 곳).

// MARK: - 촉감

@MainActor
enum Haptic {
    static var enabled = true
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let select = UISelectionFeedbackGenerator()
    private static let note = UINotificationFeedbackGenerator()

    static func tap() { guard enabled else { return }; light.impactOccurred(intensity: 0.7) }
    static func tick() { guard enabled else { return }; select.selectionChanged() }
    static func soft() { guard enabled else { return }; softGen.impactOccurred(intensity: 0.6) }
    static func firm() { guard enabled else { return }; rigid.impactOccurred(intensity: 0.8) }
    static func success() { guard enabled else { return }; note.notificationOccurred(.success) }
    static func warn() { guard enabled else { return }; note.notificationOccurred(.warning) }
    /// 도장: 쿵
    static func stamp() {
        guard enabled else { return }
        rigid.impactOccurred(intensity: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { softGen.impactOccurred(intensity: 0.5) }
    }
    /// 파쇄: 짧은 드르륵
    static func shred() {
        guard enabled else { return }
        for i in 0..<8 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.045) { rigid.impactOccurred(intensity: 0.5) } }
    }
}

// MARK: - 버튼

struct FillButton: ButtonStyle {
    enum Tone { case accent, ink, mint, quiet, line, night, nightLine }
    var tone: Tone = .accent
    var height: CGFloat = 54
    var full = true

    func makeBody(configuration: Configuration) -> some View {
        FillButtonBody(configuration: configuration, tone: tone, height: height, full: full)
    }
}

/// 비활성이면 흐려진다 — 누를 수 없는 버튼이 누를 수 있어 보이지 않게
private struct FillButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tone: FillButton.Tone
    let height: CGFloat
    let full: Bool
    @Environment(\.isEnabled) private var enabled

    private var bg: Color {
        switch tone {
        case .accent: Ink.accent
        case .ink: Ink.block
        case .mint: Ink.mint
        case .quiet: Ink.fill
        case .line, .nightLine: .clear
        case .night: Ink.nightText
        }
    }
    private var fg: Color {
        switch tone {
        case .accent: Ink.accentText
        case .ink: Ink.blockText
        case .mint: Ink.mintText
        case .quiet, .line: Ink.text
        case .night: Ink.night
        case .nightLine: Ink.nightText
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous)
        let pressed = configuration.isPressed
        configuration.label
            .font(Typo.button)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(maxWidth: full ? .infinity : nil, minHeight: height)
            .foregroundStyle(fg)
            .background(shape.fill(bg))
            .overlay {
                if tone == .line { shape.strokeBorder(Ink.text.opacity(0.85), lineWidth: 1.5) }
                if tone == .nightLine { shape.strokeBorder(Ink.nightSoft, lineWidth: 1.5) }
            }
            .contentShape(shape)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(enabled ? (pressed ? 0.88 : 1) : 0.38)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressed)
    }
}

/// 눌렀을 때 살짝 들어가는 일반 버튼 (행·카드)
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// 고르는 칩: 켜지면 먹색으로 꽉 찬다
struct Chip: View {
    var title: String
    var on: Bool
    var id: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tick()
            action()
        } label: {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minWidth: 48, minHeight: Metric.tap)
                .foregroundStyle(on ? Ink.sheet : Ink.text)
                .background(RoundedRectangle(cornerRadius: Metric.radiusChip, style: .continuous).fill(on ? Ink.text : Ink.fill))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(id ?? "chip.\(title)")
    }
}

/// 네모 칸: 끝내면 먹색으로 차고 체크가 박힌다. 누르는 곳은 48pt.
struct CheckBox: View {
    var done: Bool
    var tint: Color = Ink.text
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(tint.opacity(done ? 0 : 0.75), lineWidth: 2)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .scaleEffect(done ? 1 : 0.4)
                .opacity(done ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Ink.sheet)
                .scaleEffect(done ? 1 : 0.2)
                .opacity(done ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .frame(width: 48, height: 48)
        .contentShape(Rectangle())
        .animation(Motion.quick, value: done)
    }
}

struct Hairline: View {
    var color: Color = Ink.rule
    @Environment(\.displayScale) private var scale
    var body: some View { Rectangle().fill(color).frame(height: max(1 / scale, 0.5)) }
}

/// 띠 이름 세로쓰기 (아/침)
struct VerticalLabel: View {
    var text: String
    var color: Color = Ink.text
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        if size.isAccessibilitySize {
            Text(text).font(Typo.serif(17, relativeTo: .headline)).foregroundStyle(color)
        } else {
            VStack(spacing: 2) {
                ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                    Text(String(ch)).font(Typo.serif(20, relativeTo: .title3))
                }
            }
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
        }
    }
}

/// 화면 위 큰 제목 (명조)
struct ScreenTitle: View {
    var title: String
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typo.serif(30, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
            if let sub { Text(sub).font(.system(.subheadline)).foregroundStyle(Ink.text2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct SectionTitle<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}
extension SectionTitle where Trailing == EmptyView {
    init(title: String) { self.title = title; self.trailing = EmptyView() }
}

extension View {
    /// 한 겹 올라온 카드
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
    }
}

// MARK: - 토스트

struct ToastView: View {
    var toast: Toast
    var undo: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Text(toast.message)
                .font(.system(.subheadline, weight: .semibold))
                .lineLimit(2)
                .padding(.leading, 16)
                .padding(.vertical, 12)
            Spacer(minLength: 4)
            if toast.canUndo {
                Button("되돌리기", action: undo)
                    .font(.system(.subheadline, weight: .bold))
                    .underline()
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metric.tap)
                    .accessibilityIdentifier("toast.undo")
            }
        }
        .foregroundStyle(Ink.blockText)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.block))
        .padding(.horizontal, Metric.gutter)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast")
    }
}

// MARK: - 맑기 0–10

/// 0–10 칸 막대. 누르거나 끌어서 고른다. 칸마다 딸깍.
struct ScaleBar: View {
    @Binding var value: Int?
    var dark = false
    var label: String
    var low: String
    var high: String
    var id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(.subheadline, weight: .semibold))
                Spacer()
                Text(value.map { "\($0)" } ?? "—").font(Typo.num(.title3))
            }
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(0...10, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(fg.opacity((value ?? -1) >= i ? 1 : 0.14))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let v = min(10, max(0, Int((g.location.x / max(1, geo.size.width)) * 11)))
                    if v != value { value = v; Haptic.tick() }
                })
            }
            .frame(height: 44)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.system(.caption))
            .opacity(0.7)
        }
        .foregroundStyle(fg)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(value.map { "\($0)" } ?? "고르지 않음")
        .accessibilityAdjustableAction { dir in
            let v = value ?? 5
            value = dir == .increment ? min(10, v + 1) : max(0, v - 1)
        }
        .accessibilityIdentifier(id)
    }
    private var fg: Color { dark ? Ink.nightText : Ink.text }
}

// MARK: - 도장

/// 하루 닫기 도장: 겹 동그라미 + 명조 두 줄, 비스듬히 쿵.
struct Stamp: View {
    var top: String
    var bottom: String
    var shown: Bool
    var body: some View {
        ZStack {
            Circle().strokeBorder(Ink.stamp, lineWidth: 4)
            Circle().strokeBorder(Ink.stamp, lineWidth: 1.5).padding(9)
            VStack(spacing: 2) {
                Text(top).font(Typo.serif(30, relativeTo: .title))
                Text(bottom).font(Typo.num(size: 13, .semibold, relativeTo: .caption))
            }
            .foregroundStyle(Ink.stamp)
        }
        .frame(width: 148, height: 148)
        .rotationEffect(.degrees(-12))
        .scaleEffect(shown ? 1 : 1.9)
        .opacity(shown ? 0.92 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(top) 도장")
    }
}

/// 비어 있을 때 한 줄
struct Hint: View {
    var text: String
    var body: some View {
        Text(text).font(.system(.subheadline)).foregroundStyle(Ink.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}
