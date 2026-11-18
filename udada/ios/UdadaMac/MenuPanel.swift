import SwiftUI

/// 메뉴 막대를 누르면 내려오는 오늘: 한 줄 넣기 · 지금 줄 · 세 띠 · 맞춤 상태.
struct MenuPanel: View {
    @Environment(Store.self) private var store
    @Environment(Ticker.self) private var ticker
    @Environment(\.openWindow) private var openWindow
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let _ = ticker.minute
        let sheet = store.sheet(for: store.today)
        VStack(alignment: .leading, spacing: 0) {
            AddField(text: $text, onAdded: { store.show($0) }, focused: $focused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .paper(10)
                .padding(.bottom, 10)

            if let a = store.data.activeFocus {
                FocusStrip(active: a, compact: true).padding(.bottom, 10)
            } else if let line = sheet.now {
                NowCard(line: line, compact: true)
                    .padding(12)
                    .paper(10)
                    .padding(.bottom, 10)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sheet.bands) { band in
                        if !band.isEmpty { bandView(band) }
                    }
                    if sheet.isEmpty {
                        Text("오늘은 비어 있어. 위에 한 줄 적어 봐.")
                            .font(.system(size: 12)).foregroundStyle(Ink.text3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 22)
                    }
                }
            }
            .frame(maxHeight: 330)
            .scrollIndicators(.never)

            Hairline().padding(.vertical, 9)
            HStack(spacing: 8) {
                SyncLine(on: store.settings.syncOn)
                Spacer()
                Button("쏟아내기") { open(); store.cover = .dump }.buttonStyle(MacGhost())
                Button("창 열기") { open() }.buttonStyle(MacGhost())
                Menu {
                    Toggle("iPhone 과 맞추기 (내 iCloud)", isOn: Binding(get: { store.settings.syncOn }, set: setSync))
                    Toggle("로그인할 때 열기", isOn: Binding(get: { LoginItem.isOn }, set: LoginItem.set))
                    Picker("테마", selection: Binding(get: { store.settings.theme }, set: { t in store.setSettings { $0.theme = t } })) {
                        ForEach(ThemeID.allCases) { Text($0.name).tag($0) }
                    }
                    Button("쓰는 법 다시 보기") { open(); store.showSettings = true }
                    Divider()
                    Button("우다다 끝내기") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.text2)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(12)
        .frame(width: 356)
        .background(Ink.ground)
        .overlay(alignment: .bottom) {
            if let t = store.toast { MacToast(toast: t).padding(.bottom, 44) }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
        .onAppear { focused = true }
    }

    private func bandView(_ band: Band) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(band.part.name)
                    .font(Typo.serif(13))
                    .foregroundStyle(band.live ? Ink.accent : (band.gone ? Ink.text3 : Ink.text))
                if band.live && band.free > 0 {
                    Text("빈 시간 \(Fmt.dur(band.free))").font(.system(size: 10.5)).foregroundStyle(Ink.text3)
                }
            }
            .padding(.leading, 4)
            ForEach(band.events) { EventBlock(entry: $0) }
            ForEach(band.todos) { TodoRow(entry: $0, dense: true) }
        }
        .opacity(band.gone ? 0.6 : 1)
    }

    private func open() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setSync(_ on: Bool) {
        store.setSettings { $0.syncOn = on }
        if on { CloudSync.shared.start() } else { CloudSync.shared.stop() }
    }
}
