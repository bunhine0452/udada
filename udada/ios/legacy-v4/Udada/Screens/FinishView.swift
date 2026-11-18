import SwiftUI

/// 끝: 지금 할 단 하나(영수증) · 칸별 개수 · 머리 소음 다시 · [숨 1분][끝].
struct FinishView: View {
    @Environment(Flow.self) private var flow
    @State private var printed = false
    private let compact = UIScreen.main.bounds.height < 700

    var body: some View {
        @Bindable var flow = flow
        let one = flow.nowItems.first?.text
        let c = flow.counts
        VStack(spacing: compact ? 10 : 14) {
            TopBar(title: "끝")
            Receipt(printed: printed) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("우다다 · 지금 할 단 하나"); Spacer(); Text(Date(), style: .time) }
                        .font(Fonts.mono(11, .bold)).foregroundStyle(Color(hex: 0x8A877F))
                    Text(one ?? "지금 할 건 없어.").font(Fonts.ui(compact ? 21 : 24, .heavy)).kerning(-0.8).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("finish.one")
                    Text(one == nil ? "전부 자리를 찾았어. 창밖 한 번 보고 와." : "2분만. 안 끝나도 돼.").font(Fonts.mono(12, .bold)).foregroundStyle(Color(hex: 0x45433E))
                    Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Color(hex: 0xB9B5AB)).frame(height: 1)
                    HStack {
                        ForEach(Bin.allCases, id: \.self) { b in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(c[b] ?? 0)").font(Fonts.mono(17, .heavy))
                                Text(b.name).font(Fonts.ui(10, .bold)).foregroundStyle(Color(hex: 0x8A877F))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
            }
            LCD(label: "머리 소음 · 아까 \(flow.before)", badge: "지금은?") {
                HStack(spacing: 14) {
                    SevenSeg(text: flow.after < 10 ? " \(flow.after)" : "\(flow.after)", height: compact ? 30 : 40)
                    ClarityBar(value: $flow.after).accessibilityIdentifier("noise.after")
                }
            }
            Text((c[.date] ?? 0) + (c[.worry] ?? 0) > 0 ? "날짜 정한 건 그때, 걱정은 매일 21:30에 알려 줄게. 머리에 안 들고 있어도 돼." : "정리함에 다 들어갔어.")
                .font(Fonts.ui(12.5, .semibold)).foregroundStyle(Palette.ink2).frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button { flow.go(.breath) } label: { KeyLabel(tag: "선택 · 1분", title: "숨 고르기", big: 16) }
                    .buttonStyle(KeyStyle())
                    .frame(width: 128)
                    .accessibilityIdentifier("breath.go")
                Button { flow.finish() } label: { KeyLabel(tag: "기록은 소음 전후만", title: "끝", big: 24) }
                    .buttonStyle(KeyStyle(tone: .blue))
                    .accessibilityIdentifier("finish.done")
            }
            .frame(height: 80)
        }
        .padding(.horizontal, 18).padding(.bottom, 8)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { printed = true; Feel.printReceipt() } }
    }
}

/// 숨 고르기 1분: 두 번 들이쉬고 길게 내쉬기 × 5 (Balban 2023). 끝나면 끝 화면으로.
struct BreathView: View {
    @Environment(Flow.self) private var flow
    @State private var start = Date()
    @State private var lastPhase = -1
    @State private var done = false
    private let seconds = BreathGauge.cycle * 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = min(seconds, ctx.date.timeIntervalSince(start) * Launch.speed)
            VStack(spacing: 16) {
                TopBar(title: "숨 고르기", dark: true)
                BreathGauge(t: t, seconds: seconds).frame(maxHeight: .infinity)
                Text("두 번 들이쉬고, 길게 내쉬기").font(Fonts.ui(19, .heavy)).foregroundStyle(Palette.glow)
                Button { close() } label: {
                    Text(t >= seconds ? "됐어" : "그만").font(Fonts.ui(16, .heavy)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(KeyStyle(tone: .dark, depth: 4))
                .frame(height: 62)
                .accessibilityIdentifier("breath.stop")
            }
            .padding(.horizontal, 18).padding(.bottom, 8)
            .onChange(of: BreathGauge.phase(t).0 + Int(t / BreathGauge.cycle) * 3) { _, p in
                if p != lastPhase { lastPhase = p; if p % 3 != 2 { Feel.breathe() } }
            }
            .task(id: t >= seconds) { if t >= seconds { Feel.done(); try? await Task.sleep(nanoseconds: 600_000_000); close() } }
        }
        .onAppear { start = Date() }
    }
    private func close() { guard !done else { return }; done = true; flow.go(.finish, forward: false) }
}

/// 실행 인자: -udSpeed 200 (숨 고르기 배속), -udReset (기록 지움)
enum Launch {
    static var speed: Double {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-udSpeed"), i + 1 < a.count, let v = Double(a[i + 1]) { return max(1, v) }
        return 1
    }
}

/// 아날로그 바늘이 폐의 양을 따라 오르내린다.
struct BreathGauge: View {
    var t: Double
    var seconds: Double
    static let inhale = 2.0, topUp = 1.0, exhale = 5.5
    static var cycle: Double { inhale + topUp + exhale }

    /// (단계 0 들숨 · 1 한 번 더 · 2 날숨, 폐의 양 0~1)
    static func phase(_ t: Double) -> (Int, Double) {
        let c = t.truncatingRemainder(dividingBy: cycle)
        if c < inhale { let x = c / inhale; return (0, 0.62 * (1 - pow(1 - x, 2))) }
        if c < inhale + topUp { let x = (c - inhale) / topUp; return (1, 0.62 + 0.38 * (1 - pow(1 - x, 2))) }
        let x = (c - inhale - topUp) / exhale
        return (2, 1 - x)
    }

    var body: some View {
        let (p, lung) = Self.phase(t)
        let total = max(1, Int(seconds / Self.cycle))
        let round = min(total, Int(t / Self.cycle) + 1)
        VStack(spacing: 18) {
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height * 0.92), r = min(s.width / 2, s.height * 0.92) - 6
                for k in 0...20 {
                    let a = (-200 + Double(k) * 11) * .pi / 180, long = k % 5 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: c.x + cos(a) * (r - (long ? 18 : 10)), y: c.y + sin(a) * (r - (long ? 18 : 10))))
                    path.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    ctx.stroke(path, with: .color(Palette.glow.opacity(long ? 0.8 : 0.35)), lineWidth: long ? 3 : 1.5)
                }
                var arc = Path()
                arc.addArc(center: c, radius: r - 30, startAngle: .degrees(-200), endAngle: .degrees(20), clockwise: false)
                ctx.stroke(arc, with: .color(Palette.glow.opacity(0.12)), lineWidth: 10)
                var fill = Path()
                fill.addArc(center: c, radius: r - 30, startAngle: .degrees(-200), endAngle: .degrees(-200 + 220 * lung), clockwise: false)
                ctx.stroke(fill, with: .color(Palette.glow.opacity(0.55)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                let a = (-200 + 220 * lung) * .pi / 180
                var needle = Path()
                needle.move(to: c); needle.addLine(to: CGPoint(x: c.x + cos(a) * (r - 14), y: c.y + sin(a) * (r - 14)))
                ctx.stroke(needle, with: .color(Color(hex: 0xF1EFE8)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(Palette.glow))
            }
            .frame(maxWidth: 340).aspectRatio(1.5, contentMode: .fit)
            Text(["코로 훅", "한 번 더 훅", "입으로 길—게"][p])
                .font(Fonts.lcd(34)).foregroundStyle(Color(hex: 0xCFDCC0))
                .contentTransition(.opacity).animation(.easeInOut(duration: 0.25), value: p)
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { k in
                    Circle().fill(k < round - 1 ? Palette.glow : .clear).overlay(Circle().stroke(Palette.glow, lineWidth: 1.5)).frame(width: 12, height: 12)
                }
            }
        }
        .accessibilityElement().accessibilityIdentifier("breath")
    }
}
