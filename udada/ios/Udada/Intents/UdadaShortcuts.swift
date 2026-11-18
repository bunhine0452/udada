import AppIntents

/// Siri 에게 바로 말할 수 있는 문장들. 문장마다 앱 이름이 들어가야 한다. (최대 10개)
struct UdadaShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .navy

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddEntryIntent(), phrases: [
            "\(.applicationName)에 적어 줘",
            "\(.applicationName)에 적기",
            "\(.applicationName)에 할 일 넣어 줘",
        ], shortTitle: "적기", systemImageName: "square.and.pencil")

        AppShortcut(intent: NowIntent(), phrases: [
            "\(.applicationName) 지금 뭐 해",
            "\(.applicationName) 지금 뭐 하지",
            "\(.applicationName)에서 지금 할 일",
        ], shortTitle: "지금 뭐 해?", systemImageName: "clock")

        AppShortcut(intent: TodayIntent(), phrases: [
            "\(.applicationName) 오늘 할 일",
            "\(.applicationName) 오늘 뭐 있어",
        ], shortTitle: "오늘 할 일", systemImageName: "list.bullet")

        AppShortcut(intent: FindIntent(), phrases: [
            "\(.applicationName)에서 찾아 줘",
            "\(.applicationName)에서 찾기",
        ], shortTitle: "찾기", systemImageName: "magnifyingglass")

        AppShortcut(intent: CompleteEntryIntent(), phrases: [
            "\(.applicationName)에서 \(\.$task) 끝냈어",
            "\(.applicationName)에서 할 일 끝내기",
        ], shortTitle: "끝내기", systemImageName: "checkmark.square")

        AppShortcut(intent: StartRestIntent(), phrases: [
            "\(.applicationName)로 숨 고르기",
            "\(.applicationName)로 \(\.$kind)",
            "\(.applicationName)로 식히기",
        ], shortTitle: "식히기", systemImageName: "wind")

        // 앱을 열지 않고 한 문장으로 여러 일을 바꾼다
        AppShortcut(intent: TellIntent(), phrases: [
            "\(.applicationName)한테 시키기",
            "\(.applicationName)한테 시켜 줘",
            "\(.applicationName)에 시키기",
        ], shortTitle: "시키기", systemImageName: "text.bubble")

        // 쏟아낸 말을 나눠서 넣는 것까지 Siri 안에서
        AppShortcut(intent: SortIntent(), phrases: [
            "\(.applicationName)로 정리해 줘",
            "\(.applicationName)에 쏟아내기",
            "\(.applicationName)로 머리 비우기",
        ], shortTitle: "정리해서 넣기", systemImageName: "tray.and.arrow.down")

        AppShortcut(intent: CloseDayIntent(), phrases: [
            "\(.applicationName) 하루 닫기",
            "\(.applicationName)로 하루 닫기",
        ], shortTitle: "하루 닫기", systemImageName: "moon")

        AppShortcut(intent: GateIntent(), phrases: [
            "\(.applicationName) 숏폼 앞에 잠깐",
            "\(.applicationName) 잠깐",
        ], shortTitle: "숏폼 앞에 잠깐", systemImageName: "hand.raised")
    }
}
