import SwiftUI
import WidgetKit

// 앱스토어 스크린샷용: 우다다 위젯 확장의 뷰 코드를 그대로 가져와 고정 시각(14:20)으로 그려 PNG 로 남긴다.
@main
struct GalleryApp: App {
    var body: some Scene { WindowGroup { GalleryView() } }
}

struct GalleryView: View {
    @State private var status = "rendering…"
    @State private var live: (UdadaActivity.ContentState, UdadaActivity.ContentState)?
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let live {
                // 실시간 현황은 화면에 그려야 타이머가 제대로 나온다 (ImageRenderer 는 자리표시만 그림)
                VStack(spacing: 120) {
                    WActivityLock(state: live.0, stale: false)
                        .frame(width: 364)
                        .background(Ink.ground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    WActivityLock(state: live.1, stale: false)
                        .frame(width: 364)
                        .background(Ink.night)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .environment(\.colorScheme, .light)
            } else {
                Text(status)
            }
        }
        .task { status = render() }
    }

    func arg(_ name: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: name), i + 1 < a.count { return a[i + 1] }
        return nil
    }

    @MainActor func render() -> String {
        guard let out = arg("-out"), let dataPath = arg("-data"), let nowS = arg("-now") else { return "args?" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let now = f.date(from: nowS) else { return "bad now" }
        guard let raw = try? Data(contentsOf: URL(fileURLWithPath: dataPath)),
              let data = try? JSONDecoder().decode(AppData.self, from: raw) else { return "bad data" }
        let entry = WDay.entry(data: data, at: now, compact: false)
        var made: [String] = []
        func save<V: View>(_ name: String, _ v: V) {
            let r = ImageRenderer(content: v.environment(\.colorScheme, .light))
            r.scale = 3
            if let png = r.uiImage?.pngData() {
                try? png.write(to: URL(fileURLWithPath: out).appendingPathComponent(name + ".png"))
                made.append(name)
            }
        }
        let sizes: [(String, WidgetFamily, CGSize)] = [
            ("w-small", .systemSmall, CGSize(width: 170, height: 170)),
            ("w-medium", .systemMedium, CGSize(width: 364, height: 170)),
            ("w-large", .systemLarge, CGSize(width: 364, height: 382)),
        ]
        for (name, family, size) in sizes {
            save(name, TodayWidgetContent(entry: entry, family: family)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(Ink.ground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
        }
        // 잠금 화면 실시간 현황: 집중 (종이) · 식히기 (밤)
        let focus = UdadaActivity.ContentState.focus(title: "메일 답장", started: now.addingTimeInterval(-6 * 60), planned: 15)
        save("la-focus", WActivityLock(state: focus, stale: false)
            .frame(width: 364)
            .background(Ink.ground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        let rest = UdadaActivity.ContentState.rest(.breath, start: now, until: now.addingTimeInterval(60))
        save("la-rest", WActivityLock(state: rest, stale: false)
            .frame(width: 364)
            .background(Ink.night)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
        live = (focus, rest)
        return "made: " + made.joined(separator: ", ")
    }
}
