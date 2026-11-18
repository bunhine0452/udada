import SwiftUI

// 설정: 익숙한 iOS 설정 표(Form)를 종이 색으로만 다시 칠했다.

struct SettingsView: View {
    /// '소개 다시 보기' — 띄운 쪽(기록)이 시트를 내린 뒤 소개로 바꾼다
    var replayIntro: () -> Void = {}

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                BandSection(store: store)
                SettingsAlertSection(store: store)
                SettingsCalendarSection(store: store)
                SettingsSyncSection(store: store)
                AISection(store: store)
                SiriSection()
                GateSection(store: store)
                FeelSection(store: store)
                SettingsDataSection(store: store)
                SettingsInfoSection(store: store, replayIntro: replayIntro)
            }
            .paperForm()
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .font(.system(.body, weight: .semibold))
                        .accessibilityIdentifier("settings.close")
                }
            }
        }
        // 설정 안에서 생긴 토스트(예시로 채움 등)도 여기서 보이고 되돌릴 수 있게
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                ToastView(toast: t) { store.undo() }
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .tint(Ink.text)
        // 앱 글이 한국어뿐이라 시각 고르기도 오전/오후로
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
}

extension View {
    /// 기본 Form 을 종이 색으로 (설정 안 화면들이 같이 쓴다)
    fileprivate func paperForm() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Ink.ground.ignoresSafeArea())
            .toolbarBackground(Ink.ground, for: .navigationBar)
            .foregroundStyle(Ink.text)
    }
}

/// 설정 한 칸을 바꾸는 바인딩
@MainActor fileprivate func setting<T>(_ store: Store, _ kp: WritableKeyPath<Settings, T>) -> Binding<T> {
    Binding(get: { store.data.settings[keyPath: kp] }, set: { v in store.setSettings { $0[keyPath: kp] = v } })
}

// MARK: - 1. 하루 띠

private struct BandSection: View {
    var store: Store

    var body: some View {
        let p = store.settings.parts
        Section {
            Picker("아침 시작", selection: setting(store, \.parts.morningStart)) {
                ForEach(Array(stride(from: 0, through: max(0, p.afternoonStart - 30), by: 30)), id: \.self) { Text(Fmt.hm($0)).tag($0) }
            }
            Picker("낮 시작", selection: setting(store, \.parts.afternoonStart)) {
                ForEach(Array(stride(from: p.morningStart + 30, through: p.eveningStart - 30, by: 30)), id: \.self) { Text(Fmt.hm($0)).tag($0) }
            }
            Picker("저녁 시작", selection: setting(store, \.parts.eveningStart)) {
                ForEach(Array(stride(from: p.afternoonStart + 30, through: p.dayEnd - 30, by: 30)), id: \.self) { Text(Fmt.hm($0)).tag($0) }
            }
            Toggle("주 시작을 월요일로", isOn: setting(store, \.mondayFirst))
            Picker("기본 길이", selection: setting(store, \.defaultDuration)) {
                ForEach([15, 30, 45, 60], id: \.self) { Text(Fmt.dur($0)).tag($0) }
            }
        } header: {
            Text("하루 띠")
        } footer: {
            Text("아침 \(Fmt.hm(p.morningStart))–\(Fmt.hm(p.afternoonStart)) · 낮 –\(Fmt.hm(p.eveningStart)) · 저녁 –\(p.dayEnd >= 1440 ? "24:00" : Fmt.hm(p.dayEnd)). 길이를 안 적은 할 일은 기본 길이로 넣어.")
        }
        .listRowBackground(Ink.sheet)
        .pickerStyle(.menu)
    }
}

// MARK: - 4. 기기 안 AI

private struct AISection: View {
    var store: Store

    /// 지금 상태 한 줄 (설정의 켬/끔도 Brain 이 같이 본다)
    private var status: (text: String, ready: Bool) {
        switch Brain.shared.status {
        case .ready: ("이 iPhone 의 Apple Intelligence 로 돌아 · 기기 안에서만", true)
        case .off: ("꺼져 있어 · 켜면 지원하는 기기에서 바로 써", false)
        case .unavailable(let reason): (reason, false)
        }
    }

    /// 기기 안 언어 모델을 실제로 쓰는 곳 (하루 요약 · 한 주 한 줄 · 하루 닫기 말은 규칙)
    private static let uses: [(String, String)] = [
        ("비우기 정리 제안", "쏟아낸 것마다 칸과 때를 먼저 골라 둬"),
        ("첫 동작 쪼개기", "처음 보는 일에 2분짜리 첫걸음을 붙여"),
        ("걱정 상자", "걱정 속에서 내 손 안의 한 가지를 찾아"),
        ("한 줄 읽기 보조", "‘세 시’ · ‘퇴근하고’ 같은 말도 때로 읽어"),
    ]
    /// 언어 모델이 아니라 기기의 받아쓰기 · 글자 인식 (스위치와 상관없이)
    private static let senses: [(String, String)] = [
        ("말로 쏟아내기", "말한 것을 글로 바꿔"),
        ("사진으로 넣기", "손글씨 목록을 할 일로 옮겨"),
    ]

    var body: some View {
        let s = status
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Apple Intelligence 쓰기", isOn: setting(store, \.aiOn))
                    .accessibilityIdentifier("settings.ai.toggle")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if s.ready { Image(systemName: "checkmark").fontWeight(.bold).accessibilityHidden(true) }
                    Text(s.text).fixedSize(horizontal: false, vertical: true)
                }
                .font(Typo.meta)
                .foregroundStyle(s.ready ? Ink.text : Ink.text2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.ai.status")
            }
            .padding(.vertical, 2)
            Button { store.showSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { store.showAITour = true } } label: {
                Label("움직이는 사용법 보기", systemImage: "play.circle").foregroundStyle(Ink.accent)
            }
            .accessibilityIdentifier("settings.ai.tour")
            ForEach(Self.uses, id: \.0) { name, what in useRow(name, what) }
        } header: {
            Label("Apple Intelligence", systemImage: "apple.intelligence")
        } footer: {
            Text("아이폰에 내장된 Apple Intelligence 모델이 기기 안에서만 돌고 밖으로 안 나가. 꺼도 규칙으로 같은 흐름이 돌아. 하루 요약 · 한 주 한 줄은 늘 규칙으로 써.")
        }
        .listRowBackground(Ink.sheet)
        Section {
            ForEach(Self.senses, id: \.0) { name, what in useRow(name, what) }
        } header: {
            Text("말과 사진")
        } footer: {
            Text("기기의 받아쓰기와 글자 인식을 써. AI 스위치와 상관없이 돼.")
        }
        .listRowBackground(Ink.sheet)
    }

    private func useRow(_ name: String, _ what: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(.body, weight: .medium))
            Text(what).font(Typo.meta).foregroundStyle(Ink.text2)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 5. Siri와 단축어

private struct SiriSection: View {
    private static let phrases = ["우다다 지금 뭐 해", "우다다 오늘 할 일", "우다다로 숨 고르기", "우다다 하루 닫기"]

    var body: some View {
        Section {
            SiriTipCard(chrome: false)
            ForEach(Self.phrases, id: \.self) { phrase in
                Label("“\(phrase)”", systemImage: "waveform")
                    .font(.system(.body, weight: .medium))
                    .accessibilityLabel("Siri에게: \(phrase)")
            }
        } header: {
            Text("Siri와 단축어")
        } footer: {
            Text("이렇게 말해도 돼. 단축어 앱과 동작 버튼에도 우다다 동작이 다 들어 있어.")
        }
        .listRowBackground(Ink.sheet)
    }
}

// MARK: - 숏폼 앞에 잠깐

private struct GateSection: View {
    var store: Store
    @Environment(\.openURL) private var openURL

    private static let steps = [
        "단축어 앱을 열어.",
        "아래 ‘자동화’에서 새 자동화를 만들어.",
        "‘앱’을 고르고 YouTube · Instagram · TikTok을 골라.",
        "‘열릴 때’, ‘즉시 실행’으로 둬.",
        "동작에서 우다다 ‘숏폼 앞에 잠깐’을 골라.",
    ]

    var body: some View {
        Section {
            Toggle("숏폼 앞에 잠깐", isOn: setting(store, \.gateOn))
            if store.settings.gateOn {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(i + 1)").font(Typo.num(.body)).foregroundStyle(Ink.text2).frame(minWidth: 16)
                        Text(step).font(.system(.subheadline))
                    }
                    .accessibilityElement(children: .combine)
                }
                Button {
                    if let u = URL(string: "shortcuts://") { openURL(u) }
                } label: {
                    Label("단축어 앱 열기", systemImage: "arrow.up.forward.app")
                }
                .accessibilityIdentifier("settings.gate.shortcuts")
            }
        } footer: {
            Text("숏폼을 열면 우다다가 먼저 떠서 숨 한 번 고를 틈을 줘. 그냥 넘어가도 돼.")
        }
        .listRowBackground(Ink.sheet)
    }
}

// MARK: - 6·7. 촉감·소리 · 화면

private struct FeelSection: View {
    var store: Store

    var body: some View {
        Section("촉감·소리") {
            Toggle("촉감", isOn: setting(store, \.haptics))
            Toggle("소리", isOn: setting(store, \.sounds))
        }
        .listRowBackground(Ink.sheet)
        Section {
            ForEach(ThemeID.allCases) { t in
                Button {
                    guard store.settings.theme != t else { return }
                    Haptic.tick()
                    // 화면을 통째로 다시 그리니 설정이 닫힌다 → 다시 열어 둔다
                    store.tab = .records
                    store.showSettings = true
                    store.setSettings { $0.theme = t }
                } label: {
                    HStack(spacing: 14) {
                        ThemeSwatch(theme: t)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).font(.system(.body, weight: .medium)).foregroundStyle(Ink.text)
                            Text(t.note).font(Typo.meta).foregroundStyle(Ink.text2)
                        }
                        Spacer()
                        if store.settings.theme == t {
                            Image(systemName: "checkmark").font(.system(.body, weight: .bold)).foregroundStyle(Ink.accent)
                        }
                    }
                    .frame(minHeight: Metric.tap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("settings.theme.\(t.rawValue)")
                .accessibilityAddTraits(store.settings.theme == t ? .isSelected : [])
            }
            Picker("밝기", selection: setting(store, \.appearance)) {
                ForEach(Appearance.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.menu)
        } header: {
            Text("테마")
        } footer: {
            Text("색만 바뀌고 쓰는 법은 같아. 위젯도 같은 테마로 바뀌어. 테마마다 밝은 화면과 어두운 화면이 있어.")
        }
        .listRowBackground(Ink.sheet)
    }
}

/// 테마 견본: 종이 위에 약속 덩어리와 강조 줄 하나 — 그 테마의 색으로
struct ThemeSwatch: View {
    var theme: ThemeID
    var size: CGFloat = 44

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
        .accessibilityHidden(true)
    }
}
