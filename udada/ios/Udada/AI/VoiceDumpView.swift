import SwiftUI
import UIKit

/// 말로 쏟아내기: 말하면 글자가 바로바로 쌓이고, [다 말했어] 를 누르면 글 전체를 넘긴다.
/// 열리면 바로 듣기 시작. 큰 마이크 키로 멈춤/이어 말하기. 녹음은 저장하지 않는다.
struct VoiceDumpView: View {
    var onDone: (String) -> Void
    var onCancel: () -> Void

    init(onDone: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
    }

    @State private var voice = VoiceInput()
    @State private var finishing = false
    @State private var history: [Double] = Array(repeating: 0, count: 18)
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScreenTitle(title: "말로 쏟아내기", sub: "생각나는 대로 말해. 순서 상관없어.")
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 12)
            Hairline().padding(.horizontal, Metric.gutter)
            transcript
            Hairline().padding(.horizontal, Metric.gutter)
            controls
        }
        .background(Ink.ground.ignoresSafeArea())
        .task { await voice.start() }
        .onDisappear { voice.cancel() }
        // 권한 창이 뜨면 .inactive 가 되므로, 앱을 떠날 때만 멈춘다 (글은 남는다)
        .onChange(of: phase) { _, p in if p == .background { voice.stop() } }
        .onChange(of: voice.level) { _, v in
            history.removeFirst()
            history.append(v)
        }
        .onChange(of: voice.state) { _, s in
            if s == .listening { Haptic.soft() }
            if s != .listening { history = Array(repeating: 0, count: history.count) }
        }
    }

    // MARK: - 위

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                voice.cancel()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Ink.text2)
                    .frame(width: Metric.tap, height: Metric.tap)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("voice.close")
        }
        .padding(.horizontal, Metric.gutter - 10)
        .padding(.top, 4)
    }

    // MARK: - 받아쓴 글

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch voice.state {
                    case .denied(let why): problem(why, settings: true)
                    case .unavailable(let why): problem(why, settings: false)
                    default: EmptyView()
                    }
                    if voice.text.isEmpty {
                        Text(placeholder)
                            .font(.system(.title2))
                            .foregroundStyle(Ink.text3)
                    } else {
                        Text(voice.text)
                            .font(.system(.title2))
                            .lineSpacing(6)
                            .foregroundStyle(Ink.text)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("voice.text")
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.never)
            .onChange(of: voice.text) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
    }

    private var placeholder: String {
        switch voice.state {
        case .asking: voice.preparing != nil ? "한국어 받아쓰기를 준비하고 있어." : "마이크를 켜는 중이야."
        case .listening: "듣고 있어. 말해 봐."
        default: "아래 키를 누르고 말해 봐."
        }
    }

    private func problem(_ why: String, settings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(why)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            if settings {
                Text("마이크와 음성 인식을 켜야 말을 글자로 바꿀 수 있어.")
                    .font(Typo.meta)
                    .foregroundStyle(Ink.text2)
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(FillButton(tone: .line, height: 46, full: false))
                .accessibilityIdentifier("voice.settings")
            } else {
                Button("다시 해 보기") { Task { await voice.start() } }
                    .buttonStyle(FillButton(tone: .line, height: 46, full: false))
                    .accessibilityIdentifier("voice.retry")
            }
        }
        .card()
    }

    // MARK: - 아래: 막대 · 마이크 키 · 다시 / 다 말했어

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(note)
                    .font(Typo.meta)
                    .foregroundStyle(Ink.text3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if voice.state == .listening {
                    Text(clock)
                        .font(Typo.num(.subheadline, .semibold))
                        .foregroundStyle(remaining < 30 ? Ink.text : Ink.text3)
                        .accessibilityLabel("남은 시간 \(Int(remaining))초")
                }
            }
            HStack(spacing: 12) {
                micKey
                meterBars
            }
            HStack(spacing: 10) {
                Button("다시") { again() }
                    .buttonStyle(FillButton(tone: .quiet, full: false))
                    .frame(minWidth: 96)
                    .disabled(voice.text.isEmpty || finishing)
                    .accessibilityHint("받아쓴 글을 지우고 처음부터 말해")
                    .accessibilityIdentifier("voice.again")
                Button(finishing ? "정리하는 중…" : "다 말했어") { done() }
                    .buttonStyle(FillButton(tone: voice.state == .listening ? .ink : .accent))
                    .disabled(voice.text.isEmpty || finishing)
                    .opacity(voice.text.isEmpty ? 0.5 : 1)
                    .accessibilityIdentifier("voice.done")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var note: String {
        if voice.stoppedByLimit { return "3분이 지나서 멈췄어. 키를 누르면 이어서 들어." }
        if voice.usesServer { return "이 기기는 애플 서버에서 글자로 바꿔. 녹음은 저장하지 않아." }
        return "녹음은 저장하지 않아. 글자는 기기 안에서 바뀌어."
    }

    private var remaining: TimeInterval { max(0, VoiceInput.limit - voice.elapsed) }
    private var clock: String {
        let r = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    private var micKey: some View {
        let listening = voice.state == .listening
        let busy = voice.state == .asking
        let title: String = {
            if busy { return voice.preparing.map { "준비 중 \(Int($0 * 100))%" } ?? "준비 중" }
            if listening { return "잠깐 멈추기" }
            return voice.text.isEmpty ? "눌러서 말하기" : "이어 말하기"
        }()
        return Button {
            Haptic.tap()
            if listening { voice.stop() } else { Task { await voice.start() } }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: listening ? "pause.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(Typo.button)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(listening ? Ink.accentText : Ink.blockText)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(listening ? Ink.accent : Ink.block))
            .contentShape(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(busy || finishing)
        .accessibilityLabel(listening ? "멈추기" : "말하기")
        .accessibilityValue(listening ? "듣는 중" : "멈춤")
        .accessibilityIdentifier("voice.mic")
    }

    /// 소리 크기 막대 (최근 값이 오른쪽). 빛 번짐 없이 먹색 막대만.
    private var meterBars: some View {
        let listening = voice.state == .listening
        return HStack(alignment: .center, spacing: 3) {
            ForEach(history.indices, id: \.self) { i in
                Capsule()
                    .fill(listening ? Ink.text : Ink.rule)
                    .frame(width: 3, height: 6 + 44 * history[i])
            }
        }
        .frame(width: 18 * 6, height: 72)
        .animation(.linear(duration: 0.08), value: history)
        .accessibilityHidden(true)
    }

    // MARK: - 동작

    private func again() {
        Haptic.tick()
        let wasListening = voice.state == .listening
        voice.cancel()
        if wasListening { Task { await voice.start() } }
    }

    private func done() {
        finishing = true
        Task {
            let text = await voice.finish().trimmingCharacters(in: .whitespacesAndNewlines)
            finishing = false
            guard !text.isEmpty else { return }
            Haptic.success()
            onDone(text)
        }
    }
}
