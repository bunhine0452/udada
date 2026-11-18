import SwiftUI
import CoreSpotlight

@main
struct UdadaApp: App {
    @State private var store: Store
    @Environment(\.scenePhase) private var phase

    init() {
        NotificationRouter.install()
        Store.afterPersist = [{ SpotlightIndex.refresh($0) }]
        let s = Store()
        _store = State(initialValue: s)
        CloudSync.connect(s)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(store.settings.theme) // 색 토큰은 정적이라, 테마가 바뀌면 화면을 통째로 다시 그린다
                .environment(store)
                .preferredColorScheme(scheme)
                .onOpenURL { store.open($0) }
                .onContinueUserActivity(CSSearchableItemActionType) { a in
                    if let u = SpotlightIndex.url(for: a) { store.open(u) }
                }
                .onChange(of: phase) { _, p in
                    guard p == .active else { return }
                    store.reload()
                    refreshSystem()
                    store.checkClipboard()
                    // 위젯이 바꾼 것을 챙기고, 다른 기기에서 온 것을 바로 받는다
                    CloudSync.shared.refresh()
                }
                .task {
                    // 첫 화면이 뜬 다음에 — 앱 시작을 무겁게 하지 않게
                    try? await Task.sleep(for: .milliseconds(700))
                    store.checkClipboard()
                    // 확인용(-udScreen <그림 파일>): 그 스크린샷을 '화면 그대로'로 읽는다
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-udScreen"), i + 1 < args.count, let ui = UIImage(contentsOfFile: args[i + 1]) {
                        await store.readScreen(ui)
                    }
                    // 꺼진 사이 남은 식히기 시계는 정리 (돌던 집중은 이어진다)
                    if store.data.activeFocus == nil { LiveActivity.end() }
                    refreshSystem()
                    // iCloud 가 바뀌면 조용히 깨워 준다 (알림 허락과 상관없다)
                    UIApplication.shared.registerForRemoteNotifications()
                }
        }
    }

    private var scheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// 앱이 앞으로 올 때: 기기 달력 · 알림 상태 · 알림 일정 · Spotlight 색인 · AI 준비
    private func refreshSystem() {
        CalendarService.shared.refresh(store)
        Task { await Notifier.refreshStatus() }
        Notifier.reschedule(store.data, now: store.now)
        SpotlightIndex.refresh(store.data)
        if store.settings.aiOn { Brain.shared.prewarm() }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            if store.data.seenIntro {
                TabView(selection: $store.tab) {
                    Tab("오늘", systemImage: "sun.max", value: AppTab.today) { TodayView() }
                        .accessibilityIdentifier("tab.today")
                    Tab("달력", systemImage: "calendar", value: AppTab.calendar) { CalendarTab() }
                        .accessibilityIdentifier("tab.calendar")
                    Tab("비우기", systemImage: "tray.and.arrow.down", value: AppTab.mind) { MindView() }
                        .accessibilityIdentifier("tab.mind")
                    Tab("기록", systemImage: "chart.bar", value: AppTab.records) { RecordsView() }
                        .accessibilityIdentifier("tab.records")
                }
                .tint(Ink.text)
            } else {
                IntroView()
            }
        }
        .fullScreenCover(item: $store.cover) { cover in
            Group {
                switch cover {
                case .rest: RestView()
                case .focus(let e): FocusView(entry: e)
                case .close: CloseDayView()
                case .dump: DumpFlow()
                case .worry: WorryFlow()
                case .gate: GateView()
                case .find: FindView()
                }
            }
            .environment(store)
        }
        // 받은 약속에 답장
        .background {
            Color.clear.fullScreenCover(item: $store.reply) { r in ReplyView(request: r).environment(store) }
        }
        // 한 주 풀기 — 다른 덮개와 겹치지 않게 따로 건다
        .background {
            Color.clear.fullScreenCover(item: $store.replan) { r in ReplanView(request: r).environment(store) }
        }
        .background {
            Color.clear.sheet(isPresented: $store.showScreenSetup) { ScreenSetupView().environment(store) }
        }
        // 줄 메뉴의 '작게 쪼개기' (오늘 · 달력 어디서든)
        .sheet(item: $store.splitting) { r in BreakdownSheet(request: r) {}.environment(store) }
        // 움직이는 사용법 — 다른 덮개와 겹치지 않게 따로 건다
        .background {
            Color.clear.fullScreenCover(isPresented: $store.showAITour) {
                AITour(onTry: { what in
                    store.showAITour = false
                    store.tryFromTour(what)
                }, onClose: { store.showAITour = false })
            }
        }
        .onAppear {
            // 앱이 꺼졌다 켜져도 돌던 집중은 이어진다
            if store.data.activeFocus != nil && store.cover == nil { store.cover = .focus(nil) }
        }
        // Mac 에서 시작한 집중이 여기서 이어진다
        .onChange(of: store.data.activeFocus) { old, new in
            if old == nil, new != nil, store.cover == nil, store.data.seenIntro { store.cover = .focus(nil) }
        }
        // 보고 있는 날을 Mac 이 이어 열 수 있게 (Handoff)
        .userActivity(Continuity.dayActivity, isActive: store.data.seenIntro && store.tab == .today) { a in
            Continuity.fill(a, day: store.selectedDay, today: store.today)
        }
        .onContinueUserActivity(Continuity.dayActivity) { a in
            guard let d = Continuity.day(from: a) else { return }
            store.cover = nil
            store.tab = .today
            store.selectedDay = d
        }
        .onChange(of: store.tab) { _, _ in Haptic.tick() }
    }
}

extension Store {
    /// 사용법의 '직접 해 보기': 사용법이 내려간 뒤 그 화면을 연다
    func tryFromTour(_ what: TourTry) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [self] in
            switch what {
            case .add: tab = .today; selectedDay = today; addFocusRequest += 1
            case .dump: tab = .mind; dumpMode = .text; cover = .dump
            case .find: cover = .find
            }
        }
    }
}
