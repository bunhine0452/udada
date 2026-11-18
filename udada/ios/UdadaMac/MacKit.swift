import AppKit
import SwiftUI

// Mac 화면 부품. iPhone 과 같은 종이·먹·코발트, 크기는 포인터에 맞춰 촘촘하게.

// MARK: - iPhone 쪽 이름을 그대로 쓰기 위한 것들

/// Mac 에는 진동이 없다. 트랙패드가 있으면 아주 약한 톡.
@MainActor
enum Haptic {
    static var enabled = true
    private static func bump(_ p: NSHapticFeedbackManager.FeedbackPattern) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(p, performanceTime: .now)
    }
    static func tap() { bump(.generic) }
    static func tick() { bump(.alignment) }
    static func soft() { bump(.generic) }
    static func firm() { bump(.levelChange) }
    static func success() { bump(.levelChange) }
    static func warn() { bump(.generic) }
}

/// 알림은 iPhone 이 건다 (Mac 에서도 걸면 같은 알림이 두 번 온다). iPhone 알림은 Mac 에도 비친다.
@MainActor
enum Notifier {
    static var authorized = false
    static func requestPermission() async -> Bool { false }
    static func refreshStatus() async {}
    static func reschedule(_ data: AppData, now: Date) {}
    static func rescheduleNow(_ data: AppData, now: Date) async {}
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Ink.rule).frame(height: 1) }
}

// MARK: - 시계

/// 화면이 따라 움직일 시계. 분이 바뀔 때만 알린다 (집중 중에는 초마다).
@MainActor
@Observable
final class Ticker {
    private(set) var minute = 0
    private(set) var second = 0
    @ObservationIgnored var perSecond = false
    @ObservationIgnored private var timer: Timer?

    init() {
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let s = Int(Date().timeIntervalSince1970)
        if s / 60 != minute { minute = s / 60 }
        if perSecond, s != second { second = s }
    }
}

// MARK: - 부품

/// 네모 칸 (16pt). 끝내면 먹색으로 찬다.
struct MacCheck: View {
    var done: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(Ink.text.opacity(done ? 0 : 0.7), lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Ink.text)
                .scaleEffect(done ? 1 : 0.4)
                .opacity(done ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Ink.sheet)
                .opacity(done ? 1 : 0)
        }
        .frame(width: 16, height: 16)
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
        .animation(Motion.quick, value: done)
    }
}

/// 꽉 찬 버튼: 코발트(주 동작 하나) · 먹 · 조용한 면
struct MacFill: ButtonStyle {
    enum Tone { case accent, ink, quiet, night }
    var tone: Tone = .accent
    var compact = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let bg: Color = switch tone { case .accent: Ink.accent; case .ink: Ink.block; case .quiet: Ink.fill; case .night: Ink.nightText }
        let fg: Color = switch tone { case .accent: Ink.accentText; case .ink: Ink.blockText; case .quiet: Ink.text; case .night: Ink.night }
        return configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, compact ? 10 : 14)
            .frame(minHeight: compact ? 24 : 30)
            .foregroundStyle(fg)
            .background(RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous).fill(bg))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// 글자만 있는 버튼 (행 위에 올렸을 때 뜨는 동작)
struct MacGhost: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Ink.text2)
            .padding(.horizontal, 7)
            .frame(minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(configuration.isPressed ? Ink.rule : Ink.fill))
    }
}

/// 자판 한 글자 (⌃ ⌥ Space)
struct KeyCap: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Ink.text2)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(Ink.fill))
            .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
    }
}

/// 'Apple Intelligence' 꼬리표 — 기기 안 모델이 낸 결과에만 붙인다
struct AppleAIBadge: View {
    var text = "Apple Intelligence"
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "apple.intelligence").font(.system(size: 9, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Ink.accent)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(Capsule().fill(Ink.accentSoft))
    }
}

/// 맞춤 상태 한 줄: ● iPhone 과 맞춤 · 방금
struct SyncLine: View {
    var sync = CloudSync.shared
    var on: Bool

    var body: some View {
        let (dot, text) = label
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11)).foregroundStyle(Ink.text3).lineLimit(1)
        }
        .help("내 iCloud 로만 맞춰. 개발자도 볼 수 없어.")
    }

    private var label: (Color, String) {
        guard on else { return (Ink.text3, "기기 맞추기 꺼짐") }
        switch sync.phase {
        case .off: return (Ink.text3, "이 Mac 에만 있어")
        case .noAccount: return (Ink.stamp, "iCloud 로그인이 필요해")
        case .syncing: return (Ink.accent, "iPhone 과 맞추는 중")
        case .failed: return (Ink.stamp, "맞추지 못했어 · 다시 해 볼게")
        case .ok(let at):
            let s = Date().timeIntervalSince(at)
            return (Color(hex: 0x3FA37A), "iPhone 과 맞춤 · " + (s < 90 ? "방금" : s < 3600 ? "\(Int(s / 60))분 전" : "\(Int(s / 3600))시간 전"))
        }
    }
}

extension View {
    /// 종이 위 한 겹
    func paper(_ radius: CGFloat = 12) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ink.sheet))
    }
}

// MARK: - 집중 (iPhone 의 FocusView 와 같은 기록을 남긴다)

extension Store {
    func startFocus(_ e: Entry?) {
        guard data.activeFocus == nil else { return }
        var itemID: UUID?
        if let e { change { itemID = $0.materialize(e.source) } }
        let title = (e?.title ?? "").isEmpty ? "집중" : e!.title
        let active = ActiveFocus(itemID: itemID, title: title, planned: e?.duration ?? 25, started: Date())
        change { $0.activeFocus = active }
        Haptic.firm()
    }

    func stopFocus(finished: Bool) {
        guard let a = data.activeFocus else { return }
        let spent = max(1, Int((Date().timeIntervalSince(a.started) / 60).rounded()))
        let now = self.now
        let log = FocusLog(at: a.started, title: a.title, planned: a.planned, spent: spent, finished: finished)
        change { data in
            data.activeFocus = nil
            data.focus.append(log)
            if let id = a.itemID {
                data.update(id) { it in
                    it.spent = (it.spent ?? 0) + spent
                    if finished { it.done = true; it.doneAt = now }
                }
            }
        }
        show("예상 \(Fmt.dur(a.planned)) · 실제 \(Fmt.dur(spent))")
        if finished { Haptic.success() }
    }

    /// 한 줄 넣기. 넣은 자리를 말로 돌려준다 ("내일 15:00에 넣었어 · 치과")
    @discardableResult
    func quickAdd(_ text: String, on day: DayKey? = nil) -> String? {
        guard var item = AddEntryIntent.item(from: text, now: now, settings: settings) else { return nil }
        // 다른 날을 보고 있는데 날짜를 안 썼으면 보고 있는 날에
        if let day, day != today, item.day == today, Parser.parse(text, now: now, parts: settings.parts).day == nil {
            item.day = day
            if item.time == nil { item.part = .morning }
        }
        change { $0.add(item) }
        return AddEntryIntent.placed(item, today: today)
    }
}

/// 12:34 (집중 시계)
func clockText(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

/// 테마 견본 (그 테마의 색으로)
struct ThemeSwatch: View {
    var theme: ThemeID
    var size: CGFloat = 40

    var body: some View {
        let c = Ink.swatch(theme)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(c.ground)
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous).fill(c.block)
                .frame(width: size * 0.62, height: size * 0.2).offset(x: size * 0.19, y: size * 0.2)
            RoundedRectangle(cornerRadius: 1.5).fill(c.accent)
                .frame(width: size * 0.62, height: max(2.5, size * 0.07)).offset(x: size * 0.19, y: size * 0.5)
            RoundedRectangle(cornerRadius: 1.5).fill(c.text.opacity(0.35))
                .frame(width: size * 0.4, height: max(2, size * 0.055)).offset(x: size * 0.19, y: size * 0.68)
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
    }
}

/// 테마 고르기 (메뉴 막대 패널 · 창 아래에서 같이 쓴다)
struct ThemePicker: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ThemeID.allCases) { t in
                Button { store.setSettings { $0.theme = t } } label: {
                    VStack(spacing: 4) {
                        ThemeSwatch(theme: t, size: 34)
                            .overlay(RoundedRectangle(cornerRadius: 8.5, style: .continuous).strokeBorder(Ink.accent, lineWidth: store.settings.theme == t ? 2 : 0).padding(-2.5))
                        Text(t.name).font(.system(size: 10.5, weight: store.settings.theme == t ? .bold : .medium))
                            .foregroundStyle(store.settings.theme == t ? Ink.text : Ink.text3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(t.note)
                .accessibilityIdentifier("theme.\(t.rawValue)")
            }
        }
    }
}
