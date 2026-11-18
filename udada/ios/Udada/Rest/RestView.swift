import SwiftUI
import UserNotifications

/// 식히기: 고르면 바로 시작. 쉬는 동안 화면은 밤색으로 뒤집히고 볼 게 없다 (폰으로 쉬면 가장 덜 쉬어진다 — Kang 2019).
/// 타이머가 쉬라고 하지 않는다. 내가 누른다 (스스로 정한 휴식이 기분·집중이 더 좋았다 — 2026 Behav. Sci.).
/// 쉬는 화면은 기기 설정과 상관없이 늘 밤이다 — 밝은 모드에서도 어두운 모드에서도 같은 색.
struct RestView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    enum Phase: Equatable { case pick, run, end }
    @State private var phase: Phase = .pick
    @State private var kind: RestKind = .breath
    @State private var start = Date()
    @State private var end = Date()
    @State private var before: Int?
    @State private var after: Int?
    @State private var logged = false
    @State private var run = UUID()

    private var nextUp: Entry? {
        let s = store.sheet(for: store.today)
        return s.now?.fit ?? s.bands.first { $0.live }?.todos.first { !$0.done }
    }

    var body: some View {
        ZStack {
            (phase == .pick ? Ink.ground : Ink.night).ignoresSafeArea()
            switch phase {
            case .pick: pick.transition(.opacity)
            case .run: running.transition(.opacity)
            case .end: ending.transition(.opacity)
            }
        }
        .environment(\.colorScheme, phase == .pick ? scheme : .dark)
        .statusBarHidden(phase != .pick)
        .animation(.easeInOut(duration: 0.45), value: phase)
        .onAppear {
            if let k = store.restStart { store.restStart = nil; begin(k) }
        }
        .task(id: run) {
            guard phase == .run, kind == .breath else { return }
            await breathRhythm(from: start, total: end.timeIntervalSince(start))
        }
        .onDisappear { cleanUp() }
    }

    // MARK: 고르기

    private var pick: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("안 쉴래") { dismiss() }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("rest.cancel")
            }
            .padding(.horizontal, Metric.gutter)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenTitle(title: "얼마나 쉴래?", sub: "고르면 바로 시작해. 화면은 안 봐도 돼.")
                    VStack(spacing: 10) {
                        ForEach(RestKind.allCases) { k in option(k) }
                    }
                    ScaleBar(value: $before, label: "지금 머리 맑기 (선택)", low: "안 돌아감", high: "쌩쌩", id: "rest.before")
                        .padding(.top, 4)
                    if let n = nextUp {
                        // 쉬러 가기 전 '돌아오면 먼저' 한 줄이 주의 잔여를 줄인다 (Leroy & Glomb 2018)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("돌아오면 먼저").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                            Text("‘\(n.title)’ · \(Fmt.dur(n.duration))").font(.system(.headline)).foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("적어 뒀으니 잊어도 돼.").font(.system(.footnote)).foregroundStyle(Ink.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func option(_ k: RestKind) -> some View {
        Button { begin(k) } label: {
            HStack(alignment: .center, spacing: 16) {
                Text("\(k.minutes)분").font(Typo.num(size: 34, .heavy, relativeTo: .largeTitle))
                    .lineLimit(1).fixedSize()
                    .frame(minWidth: 76, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(k.name).font(.system(.headline, weight: .bold))
                    Text(k.why).font(.system(.footnote)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Ink.text)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(k == .breath ? Ink.mint : Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).strokeBorder(Ink.rule, lineWidth: k == .breath ? 0 : 1))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(k.minutes)분 \(k.name)")
        .accessibilityHint(k.how)
        .accessibilityIdentifier("rest.\(k.rawValue)")
    }

    // MARK: 쉬는 중

    private static let breathWords = ["코로 훅 들이쉬고", "한 번 더 훅", "입으로 길—게 내쉬고"]

    /// 숨 원만 매 프레임 그린다. 멀리 보기·걷기는 시계만 1초에 한 번 (기다리는 화면에서 움직임이 돌지 않게)
    @ViewBuilder private var running: some View {
        if kind == .breath {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in runFace(ctx.date) }
        } else {
            TimelineView(.periodic(from: start, by: 1.0 / Launch.speed)) { ctx in runFace(ctx.date) }
        }
    }

    private func runFace(_ now: Date) -> some View {
        let elapsed = now.timeIntervalSince(start) * Launch.speed
        let total = end.timeIntervalSince(start)
        let left = max(0, total - max(0, elapsed))
        return VStack(spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    Text(kind.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.nightSoft)
                    Spacer()
                    if kind == .breath {
                        // 숨 고르기는 원이 주인공 — 시계는 구석에 작게
                        Text(clock(left)).font(Typo.num(.title3, .semibold)).foregroundStyle(Ink.nightSoft)
                            .accessibilityLabel("남은 시간 \(Int(left.rounded(.up)))초")
                            .accessibilityIdentifier("rest.clock")
                    }
                }
                Spacer(minLength: 0)
                if kind == .breath {
                    // 첫 숨 전 1.5초: 화면이 밤으로 바뀌는 동안 자리를 잡는다
                    let (p, lung) = elapsed < 0 ? (-1, 0.0) : Self.breath(elapsed)
                    VStack(spacing: 28) {
                        Text(p < 0 ? "편하게 앉아." : Self.breathWords[p])
                            .font(Typo.serif(26, relativeTo: .title2))
                            .foregroundStyle(Ink.nightText)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .id(p)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: p)
                            .accessibilityAddTraits(.updatesFrequently)
                            .accessibilityIdentifier("rest.breath.word")
                        BreathPacer(lung: lung)
                            .frame(maxWidth: 270, maxHeight: 270)
                    }
                } else {
                    Text(clock(left))
                        .font(Typo.num(size: 92, .bold, relativeTo: .largeTitle))
                        .foregroundStyle(Ink.nightText)
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .accessibilityLabel("남은 시간 \(Int((left / 60).rounded(.up)))분")
                        .accessibilityIdentifier("rest.clock")
                    Text(kind.how).font(Typo.serif(22, relativeTo: .title2)).foregroundStyle(Ink.nightText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("끝나면 진동이 울려. 화면은 꺼져도 돼.").font(.system(.footnote)).foregroundStyle(Ink.nightSoft)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
                Button("그만") { finish() }
                    .buttonStyle(FillButton(tone: .nightLine))
                    .accessibilityIdentifier("rest.stop")
            }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .onChange(of: left <= 0) { _, done in if done { finish() } }
    }

    // MARK: 끝

    private var ending: some View {
        VStack(spacing: 0) {
            FlowCenteredScroll {
                VStack(alignment: .leading, spacing: 22) {
                    Text("끝. 돌아왔어.").font(Typo.serif(30, relativeTo: .largeTitle)).foregroundStyle(Ink.nightText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("rest.done")
                    ScaleBar(value: $after, dark: true, label: "지금 머리는?", low: "안 돌아감", high: "쌩쌩", id: "rest.after")
                    if let b = before, let a = after {
                        Text(a > b ? "맑기 \(b) → \(a). 몸이 먼저 식었어." : a == b ? "맑기 그대로 \(a). 그래도 쉬었어." : "맑기 \(b) → \(a). 오늘은 더 쉬어도 돼.")
                            .font(.system(.subheadline)).foregroundStyle(Ink.nightSoft)
                    }
                    if let n = nextUp {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("먼저 할 것").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.nightSoft)
                            Text("‘\(n.title)’ · \(Fmt.dur(n.duration))").font(.system(.title3, weight: .bold)).foregroundStyle(Ink.nightText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            HStack(spacing: 10) {
                Button("한 번 더") {
                    log()
                    before = after ?? before
                    begin(kind)
                }
                .buttonStyle(FillButton(tone: .nightLine))
                .accessibilityIdentifier("rest.again")
                Button("돌아가기") { log(); dismiss() }
                    .buttonStyle(FillButton(tone: .night))
                    .accessibilityIdentifier("rest.back")
            }
            .padding(.horizontal, Metric.gutter)
        }
        .padding(.bottom, 12)
    }

    // MARK: 동작

    private func begin(_ k: RestKind) {
        kind = k
        start = Date().addingTimeInterval(k == .breath ? Self.lead / Launch.speed : 0)
        end = start.addingTimeInterval(Double(k.minutes * 60))
        after = nil
        logged = false
        phase = .run
        run = UUID()
        if k == .breath { BreathTouch.prepare() } else { Haptic.firm() }
        UIApplication.shared.isIdleTimerDisabled = (k == .breath)
        let realEnd = start.addingTimeInterval(Double(k.minutes * 60) / Launch.speed)
        LiveActivity.startRest(k, until: realEnd)
        scheduleEndAlert(at: realEnd, kind: k)
    }

    private func finish() {
        guard phase == .run else { return }
        Haptic.success()
        UIApplication.shared.isIdleTimerDisabled = false
        LiveActivity.end()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.alertID])
        end = min(end, Date())
        phase = .end
    }

    /// 쉰 기록은 한 번만 (10초 안 된 건 안 남긴다)
    private func log() {
        guard !logged else { return }
        logged = true
        let secs = min(kind.minutes * 60, max(0, Int(min(Date(), end).timeIntervalSince(start) * Launch.speed)))
        guard secs >= 10 else { return }
        // 시계는 실제 시각으로 재고, 기록은 앱의 '지금'(-udNow 포함)으로 — 그 주에 들어가게
        let entry = RestLog(at: start.addingTimeInterval(store.clockOffset), kind: kind, seconds: secs, before: before, after: after)
        store.change { $0.rests.append(entry) }
    }

    /// 화면이 닫힐 때: 쉬는 중에 다른 화면이 덮어도 쉰 만큼은 남긴다
    private func cleanUp() {
        if phase == .run {
            LiveActivity.end()
            end = min(end, Date())
            log()
        }
        if phase == .end { log() }
        UIApplication.shared.isIdleTimerDisabled = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.alertID])
    }

    private static let alertID = "udrest.end"

    /// 화면이 꺼져 있어도 끝을 알린다 (알림 허락이 있을 때만)
    private func scheduleEndAlert(at date: Date, kind: RestKind) {
        let c = UNMutableNotificationContent()
        c.title = "다 쉬었어"
        c.body = kind == .walk ? "천천히 돌아와. 먼저 할 것만 보면 돼." : "천천히 돌아와."
        c.sound = .default
        c.userInfo = ["url": "udada://today"]
        let t = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.alertID, content: c, trigger: t))
    }

    private func clock(_ s: Double) -> String {
        let n = Int(s.rounded(.up))
        return String(format: "%d:%02d", n / 60, n % 60)
    }

    // MARK: 숨

    /// 두 번 들이쉬고 길게 내쉬기 (Balban 2023): 2초 · 1초 · 5.5초. 시작 전 1.5초는 자리 잡기.
    static let inhale = 2.0, top = 1.0, exhale = 5.5, lead = 1.5

    static func breath(_ t: Double) -> (Int, Double) {
        let c = t.truncatingRemainder(dividingBy: inhale + top + exhale)
        if c < inhale { let x = c / inhale; return (0, 0.62 * (1 - pow(1 - x, 2))) }
        if c < inhale + top { let x = (c - inhale) / top; return (1, 0.62 + 0.38 * (1 - pow(1 - x, 2))) }
        return (2, 1 - (c - inhale - top) / exhale)
    }

    /// 숨이 바뀌는 바로 그 순간에 톡 — 화면 갱신을 기다리지 않고 시계로 맞춘다.
    /// 들이쉬기 · 한 번 더 · 내쉬기 시작마다 한 번씩. 화면이 꺼졌다 켜져 늦게 깨면 지난 박자는 건너뛴다.
    private func breathRhythm(from start: Date, total: Double) async {
        let marks = [0, Self.inhale, Self.inhale + Self.top]
        let cycle = Self.inhale + Self.top + Self.exhale
        var k = 0
        while !Task.isCancelled {
            let t = Double(k / 3) * cycle + marks[k % 3]
            guard t < total else { return }
            let at = start.addingTimeInterval(t / Launch.speed)
            let early = at.timeIntervalSinceNow - 0.12
            if early > 0 { try? await Task.sleep(for: .seconds(early)) }
            BreathTouch.prepare()
            let wait = at.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, phase == .run else { return }
            if wait > -0.15 { BreathTouch.play(k % 3) }
            k += 1
        }
    }
}

/// 숨 박자 촉감: 들이쉬기는 또렷하게, 한 번 더는 짧게, 내쉬기는 옅게
@MainActor
private enum BreathTouch {
    private static let gen = UIImpactFeedbackGenerator(style: .soft)
    static func prepare() { if Haptic.enabled { gen.prepare() } }
    static func play(_ phase: Int) {
        guard Haptic.enabled else { return }
        gen.impactOccurred(intensity: [0.8, 0.5, 0.3][phase])
    }
}

/// 숨 원: 종이 위에 그린 동그라미. 바깥 실선 = 가득, 점선 = 첫 숨, 안의 박하 원이 숨을 따라 차고 빠진다.
/// 동작 줄이기면 크기는 그대로 두고 진하기로만 숨을 보인다.
private struct BreathPacer: View {
    var lung: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let seed = 0.16

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            let first = Self.seed + (1 - Self.seed) * 0.62
            let size = reduceMotion ? first : Self.seed + (1 - Self.seed) * lung
            ZStack {
                Circle().stroke(Ink.nightSoft.opacity(0.6), lineWidth: 1)
                Circle().stroke(Ink.nightSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .frame(width: d * first, height: d * first)
                Circle().fill(Ink.mint)
                    .overlay(Circle().stroke(Ink.mintText.opacity(0.55), lineWidth: 1))
                    .frame(width: d * size, height: d * size)
                    .opacity(reduceMotion ? 0.35 + 0.65 * lung : 1)
            }
            .frame(width: d, height: d)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
