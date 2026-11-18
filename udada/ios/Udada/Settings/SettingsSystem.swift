import SwiftUI
import UIKit
import UserNotifications

// 설정 — 기기 허락이 필요한 칸: 알림 · 기기 달력.

@MainActor fileprivate func setting<T>(_ store: Store, _ kp: WritableKeyPath<Settings, T>) -> Binding<T> {
    Binding(get: { store.data.settings[keyPath: kp] }, set: { v in store.setSettings { $0[keyPath: kp] = v } })
}

/// 0시부터 분 ↔ DatePicker 의 Date
@MainActor fileprivate func minuteBinding(_ store: Store, get: @escaping (Settings) -> Int, set: @escaping (inout Settings, Int) -> Void) -> Binding<Date> {
    Binding(
        get: { DayKey.today().date(minute: get(store.data.settings)) },
        set: { d in store.setSettings { set(&$0, minuteOfDay(d)) } }
    )
}

@MainActor fileprivate func openSystemSettings() {
    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
}

// MARK: - Mac 과 맞추기

/// 내 iCloud 로 Mac 의 우다다와 맞춘다. 켜고 끄기는 이 기기만.
struct SettingsSyncSection: View {
    var store: Store
    private var sync: CloudSync { CloudSync.shared }

    private var status: String {
        guard store.settings.syncOn else { return "꺼져 있어 · 이 iPhone 에만 둬" }
        switch sync.phase {
        case .off: return "이 iPhone 에만 있어"
        case .noAccount: return "설정에서 iCloud 에 로그인하면 맞춰져"
        case .syncing: return "맞추는 중"
        case .failed: return "지금은 못 맞췄어 · 곧 다시 해 볼게"
        case .ok(let at):
            let s = Date().timeIntervalSince(at)
            return "맞춰져 있어 · " + (s < 90 ? "방금" : s < 3600 ? "\(Int(s / 60))분 전" : "\(Int(s / 3600))시간 전")
        }
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Mac 과 맞추기", isOn: Binding(get: { store.settings.syncOn }, set: { on in
                    store.setSettings { $0.syncOn = on }
                    if on { sync.start() } else { sync.stop() }
                }))
                .accessibilityIdentifier("settings.sync.toggle")
                Text(status).font(Typo.meta).foregroundStyle(Ink.text2)
                    .accessibilityIdentifier("settings.sync.status")
            }
            .padding(.vertical, 2)
        } header: {
            Text("iPhone · Mac")
        } footer: {
            Text("Mac 의 우다다에서 적은 일이 몇 초 뒤 여기 뜨고, 여기서 끝낸 일이 Mac 메뉴 막대에서 지워져. Mac 에서 시작한 집중도 이어져. 내 iCloud 로만 오가고 개발자는 볼 수 없어.")
        }
        .listRowBackground(Ink.sheet)
    }
}

// MARK: - 2. 알림

struct SettingsAlertSection: View {
    var store: Store
    @State private var status: UNAuthorizationStatus?
    @Environment(\.scenePhase) private var phase

    private static let leads = [0, 5, 10, 15, 30, 60]
    private static let digestNames = ["아침", "낮", "저녁"]

    var body: some View {
        let s = store.settings
        Section {
            statusRow
            Toggle("띠마다 묶음 알림", isOn: setting(store, \.digestOn))
            if s.digestOn {
                ForEach(0..<3, id: \.self) { i in
                    DatePicker(Self.digestNames[i], selection: digestBinding(i), displayedComponents: .hourAndMinute)
                        .padding(.leading, 12)
                }
            }
            Toggle("약속 미리 알림", isOn: setting(store, \.eventAlertOn))
            if s.eventAlertOn {
                Picker("얼마나 미리", selection: setting(store, \.eventLead)) {
                    ForEach(Self.leads, id: \.self) { m in Text(Self.leadName(m)).tag(m) }
                }
                .pickerStyle(.menu)
                .padding(.leading, 12)
            }
            Toggle("걱정 시간", isOn: setting(store, \.worryOn))
            if s.worryOn {
                DatePicker("시각", selection: minuteBinding(store, get: { $0.worryTime }, set: { $0.worryTime = $1 }), displayedComponents: .hourAndMinute)
                    .padding(.leading, 12)
            }
            Toggle("하루 닫기 알림", isOn: setting(store, \.closeReminderOn))
            if s.closeReminderOn {
                DatePicker("시각", selection: minuteBinding(store, get: { $0.closeTime }, set: { $0.closeTime = $1 }), displayedComponents: .hourAndMinute)
                    .padding(.leading, 12)
            }
        } header: {
            Text("알림")
        } footer: {
            Text("알림을 하루 3번으로 묶으면 스트레스가 줄었어 (Fitz 2019)")
        }
        .listRowBackground(Ink.sheet)
        .task { await reload() }
        .onChange(of: phase) { _, p in if p == .active { Task { await reload() } } }
    }

    @ViewBuilder private var statusRow: some View {
        switch status {
        case .authorized, .provisional, .ephemeral:
            Label("알림 허락됨", systemImage: "checkmark")
                .font(.system(.body, weight: .medium))
                .accessibilityIdentifier("settings.notify.status")
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Text("알림이 꺼져 있어. 설정 앱에서 켤 수 있어.").font(.system(.subheadline)).foregroundStyle(Ink.text2)
                Button { openSystemSettings() } label: {
                    Label("설정 앱 열기", systemImage: "arrow.up.forward.app").frame(minHeight: Metric.tap)
                }
            }
        case .some, .none:
            VStack(alignment: .leading, spacing: 6) {
                Text("아직 허락 전이야. 필요한 때만 조용히 알려 줘.").font(.system(.subheadline)).foregroundStyle(Ink.text2)
                Button {
                    Task {
                        if await Notifier.requestPermission() { Notifier.reschedule(store.data, now: store.now) }
                        await reload()
                    }
                } label: {
                    Label("알림 허락하기", systemImage: "bell.badge").frame(minHeight: Metric.tap)
                }
                .accessibilityIdentifier("settings.notify.ask")
            }
        }
    }

    private func reload() async {
        await Notifier.refreshStatus()
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func digestBinding(_ i: Int) -> Binding<Date> {
        minuteBinding(store, get: { s in
            let t = s.digestTimes.count == 3 ? s.digestTimes : Settings().digestTimes
            return t[i]
        }, set: { s, m in
            if s.digestTimes.count != 3 { s.digestTimes = Settings().digestTimes }
            s.digestTimes[i] = m
        })
    }

    static func leadName(_ m: Int) -> String {
        switch m {
        case 0: "제시각에"
        case 60: "1시간 전"
        default: "\(m)분 전"
        }
    }
}

// MARK: - 3. 기기 달력

struct SettingsCalendarSection: View {
    var store: Store
    @State private var authorized = false
    @State private var denied = false
    @State private var sources: [CalendarService.Source] = []
    @State private var asking = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let s = store.settings
        Section {
            if authorized {
                Toggle("기기 달력 보기", isOn: Binding(get: { s.calendarOn }, set: setOn))
                    .accessibilityIdentifier("settings.calendar.on")
                if s.calendarOn {
                    ForEach(sources) { src in
                        Toggle(isOn: visible(src.id)) {
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: src.color)).frame(width: 10, height: 10).accessibilityHidden(true)
                                Text(src.title)
                            }
                        }
                        .padding(.leading, 12)
                    }
                }
            } else {
                Button {
                    connect()
                } label: {
                    HStack {
                        Label("기기 달력 연결", systemImage: "calendar.badge.plus")
                        Spacer()
                        if asking { ProgressView() }
                    }
                    .frame(minHeight: Metric.tap)
                }
                .disabled(asking)
                .accessibilityIdentifier("settings.calendar.connect")
                if denied {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("허락이 없어서 못 읽었어. 설정 앱에서 우다다의 캘린더를 ‘전체 접근’으로 바꿔 줘.")
                            .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        Button { openSystemSettings() } label: {
                            Label("설정 앱 열기", systemImage: "arrow.up.forward.app").frame(minHeight: Metric.tap)
                        }
                    }
                }
            }
        } header: {
            Text("기기 달력")
        } footer: {
            Text("약속을 하루 한 장의 띠에 같이 보여 줘. 바꾸거나 밖으로 보내지 않아.")
        }
        .listRowBackground(Ink.sheet)
        .task { reload() }
        .onChange(of: phase) { _, p in if p == .active { reload() } }
    }

    private func reload() {
        authorized = CalendarService.shared.authorized
        sources = authorized ? CalendarService.shared.sources() : []
        if authorized { denied = false }
    }

    private func connect() {
        asking = true
        Task {
            let ok = await CalendarService.shared.requestAccess()
            asking = false
            if ok {
                store.setSettings { $0.calendarOn = true }
                CalendarService.shared.refresh(store)
                Haptic.success()
            }
            denied = !ok
            authorized = ok || CalendarService.shared.authorized
            sources = authorized ? CalendarService.shared.sources() : []
        }
    }

    private func setOn(_ on: Bool) {
        store.setSettings { $0.calendarOn = on }
        if on {
            sources = CalendarService.shared.sources()
            CalendarService.shared.refresh(store)
        } else {
            store.external = []
        }
    }

    private func visible(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !store.settings.hiddenCalendars.contains(id) },
            set: { show in
                store.setSettings { s in
                    s.hiddenCalendars.removeAll { $0 == id }
                    if !show { s.hiddenCalendars.append(id) }
                }
                CalendarService.shared.refresh(store)
            }
        )
    }
}
