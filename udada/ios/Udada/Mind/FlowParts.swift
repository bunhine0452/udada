import SwiftUI

// 전체 화면 흐름(비우기 · 걱정 시간 · 식히기 · 집중 · 하루 닫기)이 같이 쓰는 작은 부품.

/// 흐름이 기억하는 작은 것 (쓰던 글 · 밀어서 정하기를 써 봤는지). UI 테스트(-udReset)는 실행마다 새로 시작한다.
@MainActor
enum FlowMemory {
    static let draftKey = "udada.dump.draft"
    static let swipedKey = "udada.flow.swiped"
    private static var prepared = false

    static func prepare() {
        guard !prepared else { return }
        prepared = true
        guard Launch.isUITest else { return }
        UserDefaults.standard.removeObject(forKey: draftKey)
        UserDefaults.standard.removeObject(forKey: swipedKey)
    }
}

// MARK: - 다음 흐름으로

/// 흐름 끝에서 이어지는 다음 흐름 (식히기 · 집중).
/// 덮개(fullScreenCover)를 바꾸지 않고 같은 덮개 안에서 내용만 바꾼다 — 닫히고 다시 뜨는 사이에 요청이 사라지지 않게.
enum FlowNext: Hashable {
    case rest(RestKind?)
    case focus(Entry?)
}

struct FlowNextView: View {
    var next: FlowNext

    var body: some View {
        switch next {
        case .rest: RestView()
        case .focus(let e): FocusView(entry: e)
        }
    }

    /// 다음 흐름이 시작할 때 읽을 것을 먼저 놓는다
    @MainActor static func prepare(_ next: FlowNext, store: Store) {
        if case .rest(let k) = next { store.restStart = k }
    }
}

// MARK: - 밀어서 정하기 (비우기 · 하루 닫기 카드)

/// 카드를 옆으로 밀어 정한다. 처음 움직인 방향으로 잠그고(세로 스크롤과 안 싸움), 정해지는 거리를 넘으면 딸깍.
/// 아래 버튼은 그대로 있다 — 미는 건 지름길일 뿐. VoiceOver 는 같은 동작을 동작 목록(로터)으로 쓴다.
struct FlowSwipe: ViewModifier {
    struct Side {
        var label: String
        var tint: Color
        /// 넘기면 카드가 그 방향으로 날아간다. false 면 제자리로 돌아오고 동작이 이어 받는다 (버리기의 파쇄처럼)
        var flies = true
        var action: () -> Void
    }
    var left: Side
    var right: Side
    var enabled = true
    /// 처음 한 번 살짝 밀려 보이며 밀 수 있다는 걸 알린다
    var peek = false
    var onUse: () -> Void = {}

    @State private var dx: CGFloat = 0
    @State private var axis: Axis?
    @State private var armed = false
    @State private var gone = false
    @State private var width: CGFloat = 340
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trigger: CGFloat { min(110, width * 0.3) }

    func body(content: Content) -> some View {
        let p = min(1, abs(dx) / trigger)
        return content
            .offset(x: dx)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(max(-4, min(4, dx / 28)))), anchor: .bottom)
            // 카드 뒤에 가만히 있다가 카드가 비켜나면 드러나는 이름 (글 위에 겹치지 않게)
            .background(alignment: .leading) { reveal(right, arrow: "arrow.right", leading: true).opacity(dx > 0 ? p : 0) }
            .background(alignment: .trailing) { reveal(left, arrow: "arrow.left", leading: false).opacity(dx < 0 ? p : 0) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(drag)
            .accessibilityAction(named: Text(right.label)) { if enabled { right.action() } }
            .accessibilityAction(named: Text(left.label)) { if enabled { left.action() } }
            .onAppear { if peek && !reduceMotion { nudge() } }
    }

    private func reveal(_ s: Side, arrow: String, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if !leading { Image(systemName: arrow) }
            Text(s.label)
            if leading { Image(systemName: arrow) }
        }
        .font(.system(.headline, weight: .heavy))
        .foregroundStyle(s.tint)
        .lineLimit(1)
        .scaleEffect(armed ? 1.08 : 1, anchor: leading ? .leading : .trailing)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: armed)
        .padding(.horizontal, 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { v in
                guard enabled, !gone else { return }
                if axis == nil {
                    axis = abs(v.translation.width) > abs(v.translation.height) * 1.2 ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }
                dx = v.translation.width
                let nowArmed = abs(dx) > trigger
                if nowArmed != armed { armed = nowArmed; Haptic.tick() }
            }
            .onEnded { v in
                defer { axis = nil; armed = false }
                guard enabled, !gone, axis == .horizontal else { if !gone { settle() }; return }
                let fling = v.predictedEndTranslation.width
                if dx > trigger || (dx > 40 && fling > width * 0.6) {
                    commit(right, sign: 1)
                } else if dx < -trigger || (dx < -40 && fling < -width * 0.6) {
                    commit(left, sign: -1)
                } else {
                    settle()
                }
            }
    }

    private func commit(_ s: Side, sign: CGFloat) {
        onUse()
        guard s.flies else { settle(); s.action(); return }
        gone = true
        let t = reduceMotion ? 0.12 : 0.18
        withAnimation(.easeIn(duration: t)) { dx = sign * (width + 60) }
        DispatchQueue.main.asyncAfter(deadline: .now() + t) {
            s.action()
            // 동작이 카드를 넘기지 못했으면(막혔으면) 제자리로
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if gone { gone = false; settle() } }
        }
    }

    private func settle() {
        if reduceMotion { dx = 0 } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dx = 0 } }
    }

    private func nudge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard axis == nil, dx == 0, !gone else { return }
            withAnimation(.easeInOut(duration: 0.3)) { dx = 26 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                guard axis == nil, !gone else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { dx = 0 }
            }
        }
    }
}

/// 밀어서 정할 수 있다는 작은 안내. 한 번 밀어 보면 사라진다. (VoiceOver 는 동작 목록을 쓰니 읽지 않는다)
struct FlowSwipeHint: View {
    var left: String
    var right: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(middle: true)
            row(middle: false)
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(Ink.text3)
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    private func row(middle: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.left")
            Text(left)
            Spacer(minLength: 8)
            if middle {
                Text("카드를 밀어도 돼")
                Spacer(minLength: 8)
            }
            Text(right)
            Image(systemName: "arrow.right")
        }
        .lineLimit(1)
    }
}

// MARK: - 배치

/// 내용이 짧으면 가운데, 길면(큰 글자) 스크롤
struct FlowCenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { g in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: g.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// 줄바꿈되는 가로 묶음 (칩). 한 줄에 안 들어가면 다음 줄로 — 가로 스크롤 뒤에 숨는 칩이 없게.
struct FlowWrap: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            let w = min(size.width, maxW)
            if x > 0 && x + w > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += w + spacing
            rowH = max(rowH, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            let w = min(size.width, bounds.width)
            if x > bounds.minX && x + w > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: w, height: size.height))
            x += w + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - 버리기

/// 버린 카드가 세로로 찢어져 떨어진다 (생각을 물건처럼 버리면 덜 쓴다 — Briñol 2012). 동작 줄이기면 그냥 옅어진다.
struct ShredText: View {
    var text: String
    @State private var fall = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let strips = 10

    var body: some View {
        GeometryReader { g in
            let w = g.size.width / CGFloat(strips)
            ZStack(alignment: .topLeading) {
                ForEach(0..<strips, id: \.self) { k in
                    Text(text).font(.system(.title2, weight: .bold)).foregroundStyle(Ink.text)
                        .frame(width: g.size.width, alignment: .leading)
                        .mask(Rectangle().frame(width: w - 1).offset(x: CGFloat(k) * w - g.size.width / 2 + w / 2))
                        .offset(y: fall && !reduceMotion ? 160 + CGFloat((k * 37) % 60) : 0)
                        .rotationEffect(.degrees(fall && !reduceMotion ? Double((k % 3) - 1) * 9 : 0))
                        .opacity(fall ? 0 : 1)
                        .animation(reduceMotion ? .easeOut(duration: 0.3) : .easeIn(duration: 0.6).delay(Double(k) * 0.015), value: fall)
                }
            }
        }
        .frame(height: 90)
        .onAppear { fall = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
