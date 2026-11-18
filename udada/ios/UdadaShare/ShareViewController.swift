import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit

/// 공유 확장: 다른 앱에서 공유한 화면(스크린샷) · 글에서 일정을 찾아 바로 넣고 알림으로 알려 준다.
/// 받은 약속(“금요일 7시 어때?”)은 넣지 않고 받아 둔다 — 답장은 앱에서 고른다. 못 찾은 사진과 녹음도 받아 두고 앱에서 다시 읽는다.
/// 글자 인식과 날짜 읽기는 이 기기 안에서만 한다. 아무것도 기기 밖으로 나가지 않는다.
final class ShareViewController: UIViewController {
    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        let host = UIHostingController(rootView: ShareCard(state: state))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        Task { await receive() }
    }

    private func receive() async {
        var work = ShareWork()
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            var gotText = false
            for p in item.attachments ?? [] {
                if p.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    if let url = try? await p.loadItem(forTypeIdentifier: UTType.audio.identifier) as? URL, Inbox.put(file: url) { work.kept += 1 }
                } else if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let got = try? await p.loadItem(forTypeIdentifier: UTType.image.identifier)
                    var image: UIImage?
                    if let url = got as? URL { image = UIImage(contentsOfFile: url.path) } else if let i = got as? UIImage { image = i } else if let d = got as? Data { image = UIImage(data: d) }
                    if let image { await work.take(image: image) }
                } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let s = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String { work.take(text: s); gotText = true }
                } else if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    // 링크만 왔으면 같이 온 글(제목·고른 글)을 받는다 — 주소만으로는 챙길 일을 알 수 없다
                    if let s = item.attributedContentText?.string, !gotText { work.take(text: s); gotText = true }
                }
            }
            if !gotText, (item.attachments ?? []).isEmpty, let s = item.attributedContentText?.string { work.take(text: s) }
        }
        let result = await work.finish()
        await MainActor.run { state.title = result.title; state.detail = result.detail; state.done = true }
        try? await Task.sleep(for: .milliseconds(result.long ? 2400 : 1500))
        await MainActor.run { extensionContext?.completeRequest(returningItems: nil) }
    }
}

/// 공유로 들어온 것을 읽고, 일정은 넣고, 나머지는 받아 둔다.
struct ShareWork {
    /// 일정으로 넣을 줄
    var lines: [String] = []
    /// 받은 약속 (답장은 앱에서)
    var offers: [String] = []
    /// 받아 두기만 한 것 (녹음 · 못 읽은 사진 · 때가 없는 글)
    var kept = 0
    let now = Date()

    mutating func take(image: UIImage) async {
        guard let cg = TextScan.upright(image) else { return }
        switch ScreenRules.read(await TextScan.pieces(in: cg), now: now) {
        case .offer(let m): offers.append(m)
        case .lines(let l): lines += l
        case .nothing:
            // 포스터처럼 글자만으로는 못 읽는 그림은 앱의 Apple Intelligence 가 다시 본다
            if let data = image.jpegData(compressionQuality: 0.85), Inbox.put(image: data) { kept += 1 }
        }
    }

    mutating func take(text: String) {
        switch ScreenRules.read(text: text, now: now) {
        case .offer(let m): offers.append(m)
        case .lines(let l): lines += l
        case .nothing: if !ScreenRules.isJunk(text), Inbox.put(text: text) { kept += 1 }
        }
    }

    struct Result { var title: String; var detail: String; var long: Bool }

    func finish() async -> Result {
        var data = DataFile.load()
        data.settle(now: now)
        let today = DayKey(now)
        let fresh = ScreenRules.items(from: lines, data: data, now: now)
        if !fresh.isEmpty {
            data.items += fresh
            DataFile.save(data)
            WidgetCenter.shared.reloadAllTimelines()
            await ShareAlarms.apply(data, now: now)
        }
        for o in offers { Inbox.put(text: o) }

        var title = "", detail = ""
        if !fresh.isEmpty {
            title = "일정 \(fresh.count)개를 넣었어."
            detail = ScreenRules.summary(fresh, today: today)
            await ShareAlarms.tell(title: "일정 \(fresh.count)개를 넣었어", body: detail, url: "udada://day/\(fresh[0].day.map { "\($0)" } ?? "")")
        } else if !lines.isEmpty {
            title = "이미 들어 있는 일정이야."
            detail = "같은 이름 · 같은 때로 넣어 둔 게 있어서 다시 넣지 않았어."
        }
        if let o = offers.first {
            if title.isEmpty { title = "받은 약속이 있어." } else { detail += "\n받은 약속도 하나 있어." }
            if fresh.isEmpty { detail = "“\(o.prefix(60))” — 앱을 열면 내 일정을 보고 답장을 써 줘." }
            await ShareAlarms.tell(title: "받은 약속이 있어", body: "“\(o.prefix(80))” — 눌러서 내 일정 보고 답장 쓰기", url: "udada://reply?text=" + (o.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
        }
        if title.isEmpty {
            title = kept > 0 ? "우다다가 받아 뒀어." : "일정을 못 찾았어."
            detail = kept > 0 ? "바로 읽히는 일정은 없었어. 앱을 열면 이 iPhone 의 Apple Intelligence 가 다시 읽어 줘." : "날짜나 시각이 적힌 화면 · 글을 공유해 줘."
        }
        return Result(title: title, detail: detail, long: !fresh.isEmpty || !offers.isEmpty)
    }
}

/// 확장에서 거는 알림: 넣었다는 한 줄과, 넣은 약속의 미리 알림 (앱의 Notifier 와 같은 계산 · 같은 이름표라 앱이 열리면 그대로 이어받는다)
enum ShareAlarms {
    static func allowed() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return [.authorized, .provisional, .ephemeral].contains(s.authorizationStatus)
    }

    static func tell(title: String, body: String, url: String) async {
        guard await allowed() else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.userInfo = ["url": url]
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "shared-\(UUID().uuidString.prefix(8))", content: c, trigger: nil))
    }

    static func apply(_ data: AppData, now: Date) async {
        guard await allowed() else { return }
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(NotifyPlan.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        let calendar = Calendar.current
        for note in NotifyPlan.make(data, now: now, calendar: calendar, focus: .current) {
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = note.body
            content.threadIdentifier = note.thread
            content.userInfo = ["url": note.url, "kind": note.kind.rawValue]
            content.filterCriteria = note.kind.rawValue
            if data.settings.sounds { content.sound = .default }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: note.fire)
            try? await center.add(UNNotificationRequest(identifier: note.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}

@Observable final class ShareState {
    var done = false
    var title = ""
    var detail = ""
}

/// 종이 한 장: 받았다는 것과, 앱을 열면 무엇이 일어나는지 한 줄
private struct ShareCard: View {
    var state: ShareState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let paper = scheme == .dark ? Color(red: 0.13, green: 0.14, blue: 0.13) : Color(red: 0.98, green: 0.98, blue: 0.97)
        let ink = scheme == .dark ? Color(red: 0.93, green: 0.93, blue: 0.9) : Color(red: 0.13, green: 0.16, blue: 0.15)
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text(!state.done ? "읽는 중…" : state.title)
                    .font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(ink)
                Text(!state.done ? " " : state.detail)
                    .font(.subheadline).foregroundStyle(ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(paper))
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.42, dampingFraction: 0.9), value: state.done)
        }
        .accessibilityIdentifier("share.card")
    }
}
