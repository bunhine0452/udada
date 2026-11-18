import SwiftUI

// 움직이는 사용법의 부품. 장면은 '시각 t 의 순수 함수'다 — 같은 t 면 같은 그림이 나온다.
// 그래서 박자를 초 단위로 정확히 짤 수 있고(손가락이 닿는 순간에 눌리고, 눌린 뒤에 날아간다), 어느 순간이든 멈춰서 확인할 수 있다.
// 무대는 320×400 의 고정 좌표계이고 화면 크기에 맞춰 통째로 줄고 는다. 색·글꼴은 Shared/Theme.swift 의 것만 (iPhone · Mac 공용).

/// 장면 안의 시각 (초)
struct Beat {
    var t: Double

    /// a 초부터 d 초 동안 0→1, 천천히 떠나 천천히 닿는다
    func p(_ a: Double, _ d: Double = 0.5) -> Double {
        let x = lin(a, d)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    /// 빨리 떠나 천천히 닿는다 (날아가 앉는 것)
    func land(_ a: Double, _ d: Double = 0.5) -> Double { 1 - pow(1 - lin(a, d), 3) }
    func lin(_ a: Double, _ d: Double) -> Double { d <= 0 ? (t >= a ? 1 : 0) : min(1, max(0, (t - a) / d)) }
    func on(_ a: Double) -> Bool { t >= a }
    /// a 에 눌렀다 뗀다: 0→1→0 (0.36초)
    func press(_ a: Double) -> Double { sin(lin(a - 0.1, 0.36) * .pi) }
    /// a 에 톡 튀어나온다: 0→1.12→1
    func pop(_ a: Double) -> Double {
        let x = lin(a, 0.34)
        guard x > 0 else { return 0 }
        let c = 1.70158 * 1.4
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
}

func mix(_ a: CGFloat, _ b: CGFloat, _ p: Double) -> CGFloat { a + (b - a) * CGFloat(p) }

extension View {
    /// 무대 좌표에 놓는다 (왼쪽 위 기준)
    func at(_ x: CGFloat, _ y: CGFloat, w: CGFloat? = nil, h: CGFloat? = nil, align: Alignment = .leading) -> some View {
        frame(width: w, height: h, alignment: align).offset(x: x, y: y)
    }
    /// 살짝 올라오며 나타난다
    func show(_ p: Double, rise: CGFloat = 8) -> some View { opacity(p).offset(y: CGFloat(1 - p) * rise) }
}

/// 320×400 무대. 안의 것은 ZStack(왼쪽 위)에 .at 으로 놓는다.
struct GuideStage<Content: View>: View {
    static var size: CGSize { CGSize(width: 320, height: 400) }
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width / 320, g.size.height / 400)
            ZStack(alignment: .topLeading) { content }
                .frame(width: 320, height: 400, alignment: .topLeading)
                .scaleEffect(s, anchor: .center)
                .frame(width: g.size.width, height: g.size.height)
        }
    }
}

// MARK: - 손가락

/// 화면을 누르는 손가락. 자리(keys)를 시각 순서로 지나가고, taps 의 순간에 눌린다. holds 동안은 누른 채 끈다.
struct GuideFinger: View {
    var beat: Beat
    var keys: [(Double, CGPoint)]
    var taps: [Double] = []
    var holds: [ClosedRange<Double>] = []
    var dark = false

    var body: some View {
        guard let first = keys.first, let last = keys.last else { return AnyView(EmptyView()) }
        let pos = position
        let down = max(taps.map { beat.press($0) }.max() ?? 0, holds.contains { $0.contains(beat.t) } ? 1 : 0)
        let seen = beat.lin(first.0, 0.25) * (1 - beat.lin(last.0 + 0.35, 0.3))
        let ink = dark ? Ink.nightText : Ink.text
        return AnyView(
            ZStack {
                // 눌린 자리에서 퍼지는 고리 한 번
                ForEach(taps.indices, id: \.self) { i in
                    let r = beat.lin(taps[i], 0.5)
                    Circle().strokeBorder(Ink.accent, lineWidth: 1.5)
                        .frame(width: 26 + 30 * r, height: 26 + 30 * r)
                        .opacity(r > 0 && r < 1 ? 0.7 * (1 - r) : 0)
                }
                Circle().fill(ink.opacity(0.14 + 0.16 * down))
                    .overlay(Circle().strokeBorder(ink.opacity(0.55), lineWidth: 1.5))
                    .frame(width: 26, height: 26)
                    .scaleEffect(1 - 0.2 * down)
            }
            .frame(width: 60, height: 60)
            .offset(x: pos.x - 30, y: pos.y - 30)
            .opacity(seen)
            .allowsHitTesting(false)
        )
    }

    private var position: CGPoint {
        var from = keys[0]
        for k in keys.dropFirst() {
            if beat.t <= k.0 {
                let p = beat.p(from.0, k.0 - from.0)
                return CGPoint(x: mix(from.1.x, k.1.x, p), y: mix(from.1.y, k.1.y, p))
            }
            from = k
        }
        return from.1
    }
}

// MARK: - 작은 부품 (진짜 화면을 줄여 놓은 것)

/// 할 일 한 줄. check 0→1 이면 네모가 차고 잉크가 그어진다. plate 면 종이 조각(카드)처럼 뜬다.
struct GTodo: View {
    var text: String
    var check: Double = 0
    var tag: String? = nil
    var tagPop: Double = 1
    var plate = false
    var size: CGFloat = 13.5

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(Ink.text.opacity(0.7 * (1 - check)), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(Ink.text).scaleEffect(0.4 + 0.6 * check).opacity(check)
                Image(systemName: "checkmark").font(.system(size: 8.5, weight: .heavy)).foregroundStyle(Ink.sheet).opacity(check)
            }
            .frame(width: 16, height: 16)
            Text(text).font(.system(size: size, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(check > 0.5 ? Ink.text3 : Ink.text)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Ink.text3).frame(width: g.size.width * check, height: 1.5).offset(y: g.size.height / 2)
                    }
                }
            Spacer(minLength: 0)
            if let tag { GTag(text: tag).scaleEffect(tagPop).opacity(min(1, tagPop)) }
        }
        .padding(.horizontal, plate ? 10 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if plate {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.sheet)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
            }
        }
    }
}

/// 코발트 꼬리표 (어디로 가는지)
struct GTag: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .bold)).foregroundStyle(Ink.accent).lineLimit(1).fixedSize()
            .padding(.horizontal, 6).frame(height: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Ink.accentSoft))
    }
}

/// 약속 덩어리 (먹색으로 꽉 찬다)
struct GBlock: View {
    var when: String
    var title: String
    var body: some View {
        HStack(spacing: 10) {
            Text(when).font(Typo.num(size: 13.5, .bold)).fixedSize()
            Text(title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Ink.blockText)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.block))
    }
}

/// 칸 카드 (종이 한 장). live 0→1 이면 코발트 테두리가 선다.
struct GPaper: View {
    var live: Double = 0
    var radius: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ink.sheet)
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.accent, lineWidth: 1.5).opacity(live))
    }
}

/// 칸 머리: 이름(명조) · 시간대 · '지금'
struct GBandHead: View {
    var name: String
    var range: String
    var live: Double = 0
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ZStack(alignment: .leading) {
                Text(name).font(Typo.serif(20)).foregroundStyle(Ink.text).opacity(1 - live)
                Text(name).font(Typo.serif(20)).foregroundStyle(Ink.accent).opacity(live)
            }
            Text(range).font(Typo.num(size: 12, .semibold)).foregroundStyle(Ink.text3)
            Text("지금").font(.system(size: 9.5, weight: .heavy)).foregroundStyle(Ink.accentText)
                .padding(.horizontal, 6).frame(height: 16).background(Capsule().fill(Ink.accent))
                .scaleEffect(live).opacity(live)
            Spacer(minLength: 0)
        }
    }
}

/// 화면 맨 아래 넣기 줄: Apple Intelligence 버튼 · 적는 칸 · 넣기. 무대의 (0, 344) 에 놓는다.
struct GBar: View {
    var text: String
    var caret = false
    var pressed: Double = 0
    var aiPressed: Double = 0
    var button = "넣기"
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.intelligence").font(.system(size: 15, weight: .semibold)).foregroundStyle(Ink.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.accentSoft))
                .scaleEffect(1 - 0.08 * aiPressed)
            HStack(spacing: 1) {
                if text.isEmpty && !caret {
                    Text("적기 · 예) 내일 3시 치과").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.text3)
                } else {
                    Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text).lineLimit(1).truncationMode(.head)
                    if caret { Rectangle().fill(Ink.accent).frame(width: 1.5, height: 16) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.fill))
            Text(button).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Ink.blockText)
                .frame(width: 50, height: 36)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.block))
                .scaleEffect(1 - 0.08 * pressed).opacity(1 - 0.2 * pressed)
        }
        .padding(.horizontal, 14)
        .frame(width: 320, height: 56)
        .background(Ink.sheet)
        .overlay(alignment: .top) { Rectangle().fill(Ink.rule).frame(height: 1) }
    }
}

/// "Apple Intelligence" 이름표
struct GAIMark: View {
    var text = "Apple Intelligence"
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "apple.intelligence").font(.system(size: 9.5, weight: .semibold))
            Text(text).font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(Ink.accent).lineLimit(1).fixedSize()
        .padding(.horizontal, 7).frame(height: 19)
        .background(Capsule().fill(Ink.accentSoft))
    }
}

/// 되돌리기 토스트
struct GToast: View {
    var text: String
    var pressed: Double = 0
    var body: some View {
        HStack {
            Text(text).font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 4)
            Text("되돌리기").font(.system(size: 12, weight: .bold)).underline().opacity(1 - 0.4 * pressed)
        }
        .foregroundStyle(Ink.blockText)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.block))
    }
}

/// 글자를 하나씩 친다: a 초부터 한 글자에 per 초
func typed(_ s: String, _ beat: Beat, from a: Double, per: Double = 0.13) -> String {
    let n = Int(max(0, (beat.t - a) / per))
    return String(s.prefix(n))
}
