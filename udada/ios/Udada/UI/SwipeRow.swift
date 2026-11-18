import SwiftUI
import UIKit

extension EnvironmentValues {
    /// 줄을 미는 중이거나 열려 있으면 true — 안쪽 버튼은 이때 눌림을 무시한다
    @Entry var swipeActive = false
}

/// 밀어서 하는 동작 하나
struct SwipeAction {
    var title: String
    var symbol: String
    var tint: Color
    var fg: Color
    var action: () -> Void
}

/// 가로로만 잡는 팬 (UIKit). 처음 움직임이 세로면 시작하지 않아서 바깥 스크롤뷰가 그대로 스크롤된다.
/// SwiftUI DragGesture 는 스크롤뷰 안에서 그 위에서 시작한 세로 스크롤까지 막아 버려서(줄 위에서 끌면 화면이 안 움직임) 이걸 쓴다.
struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (_ dx: CGFloat) -> Void = { _ in }
    /// 끝: 움직인 거리와 손을 뗄 때 가로 속도(pt/s)
    var onEnded: (_ dx: CGFloat, _ velocity: CGFloat) -> Void
    /// 시스템이 가져갔을 때 (끌어 옮기기 시작 · 전화 등) — 아무것도 실행하지 않고 제자리로
    var onCancelled: () -> Void = {}

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.maximumNumberOfTouches = 1
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
        let dx = g.translation(in: g.view).x
        switch g.state {
        case .began, .changed: onChanged(dx)
        case .ended: onEnded(dx, g.velocity(in: g.view).x)
        case .cancelled, .failed: onCancelled()
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let p = g as? UIPanGestureRecognizer else { return true }
            let v = p.velocity(in: p.view)
            return abs(v.x) > abs(v.y) * 1.2
        }
    }
}

/// 줄을 옆으로 민다. 오른쪽으로 → leading 실행, 왼쪽으로 조금 → 버튼이 열림, 왼쪽 끝까지 → 첫 버튼 실행.
/// 가로로 시작한 움직임만 잡으니 세로 스크롤과 싸우지 않는다. 미는 동안과 직후에는 안쪽 버튼이 눌리지 않는다.
/// 실행 문턱을 넘으면 딸깍 + 그 동작 하나만 커져서, 손을 떼면 무엇이 일어날지 미리 보인다.
struct SwipeRow<Content: View>: View {
    var leading: SwipeAction?
    var trailing: [SwipeAction] = []
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var width: CGFloat = 320
    @State private var armed = false
    @State private var suppress = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let buttonWidth: CGFloat = 74
    private var openWidth: CGFloat { buttonWidth * CGFloat(trailing.count) }
    private var leadTrigger: CGFloat { min(110, width * 0.3) }
    /// 버튼을 연 자리와 '끝까지'의 거리를 넉넉히 둔다 — 열려다 실수로 실행되지 않게 (작은 화면일수록 중요)
    private var fullTrigger: CGFloat { max(width * 0.6, openWidth + 60) }
    private var leadArmed: Bool { offset > leadTrigger }
    private var fullArmed: Bool { offset < -fullTrigger }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if let leading, offset > 0 {
                    actionFace(leading, alignment: .leading, emphasized: leadArmed).frame(width: offset)
                }
                Spacer(minLength: 0)
                if offset < 0 {
                    HStack(spacing: 0) {
                        ForEach(Array(trailing.enumerated()), id: \.offset) { i, a in
                            Button { fire(a) } label: { actionFace(a, alignment: .center, emphasized: i == 0 && fullArmed) }
                                .buttonStyle(.plain)
                                .frame(width: trailingWidth(i))
                                .clipped()
                                .accessibilityLabel(a.title)
                        }
                    }
                    .frame(width: -offset, alignment: .trailing)
                    .clipped()
                }
            }
            content
                .environment(\.swipeActive, suppress || settled != 0)
                // 열린 줄을 누르면 닫힌다. 덮개는 줄과 같이 움직여야 옆의 버튼을 가리지 않는다.
                .overlay {
                    if settled != 0 {
                        Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                    }
                }
                .offset(x: offset)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .gesture(HorizontalPan(onChanged: changed, onEnded: ended, onCancelled: {
            armed = false
            suppress = false
            close()
        }))
    }

    private func trailingWidth(_ i: Int) -> CGFloat {
        // 끝까지 밀면 첫 버튼이 줄 전체를 차지한다 (나머지는 접힌다)
        if fullArmed { return i == 0 ? -offset : 0 }
        let extra = max(0, -offset - openWidth)
        return buttonWidth + (i == 0 ? extra : 0)
    }

    private func actionFace(_ a: SwipeAction, alignment: Alignment, emphasized: Bool) -> some View {
        ZStack(alignment: alignment) {
            a.tint
            VStack(spacing: 3) {
                Image(systemName: a.symbol).font(.system(size: 16, weight: .bold))
                    .scaleEffect(emphasized ? 1.18 : 1)
                Text(a.title).font(.system(.caption, weight: .bold)).lineLimit(1).fixedSize()
            }
            .foregroundStyle(a.fg)
            .padding(.horizontal, 16)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: emphasized)
        }
    }

    private func changed(_ dx: CGFloat) {
        suppress = true
        var x = settled + dx
        if leading == nil { x = min(x, 0) }
        if trailing.isEmpty { x = max(x, 0) }
        // 줄 너비를 넘어서는 고무줄처럼 덜 따라온다
        if abs(x) > width { x = (x > 0 ? 1 : -1) * (width + (abs(x) - width) * 0.25) }
        offset = x
        let nowArmed = x > leadTrigger || x < -fullTrigger
        if nowArmed != armed { armed = nowArmed; Haptic.tick() }
    }

    private func ended(_ dx: CGFloat, _ velocity: CGFloat) {
        defer {
            armed = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { suppress = false }
        }
        let x = offset
        let fling = x + velocity * 0.25
        if let leading, x > leadTrigger || (x > 40 && fling > width * 0.6) {
            close()
            leading.action()
        } else if let first = trailing.first, x < -fullTrigger {
            animate { offset = -width }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                first.action()
                offset = 0; settled = 0
            }
        } else if !trailing.isEmpty, x < -buttonWidth * 0.5 || fling < -openWidth {
            animate { offset = -openWidth; settled = -openWidth }
        } else {
            close()
        }
    }

    private func fire(_ a: SwipeAction) {
        close()
        a.action()
    }

    private func close() { animate { offset = 0; settled = 0 } }

    private func animate(_ body: () -> Void) {
        if reduceMotion { body() } else { withAnimation(.spring(response: 0.3, dampingFraction: 0.86), body) }
    }
}
