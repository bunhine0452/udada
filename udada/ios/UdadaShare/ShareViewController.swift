import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 공유 확장: 다른 앱에서 고른 글·링크·사진·녹음을 우다다의 '받아 둔 것'에 넣는다.
/// 여기서는 받아 두기만 한다 — 챙길 일을 고르는 것은 앱을 열었을 때 기기 안 Apple Intelligence 가 한다. 아무것도 기기 밖으로 나가지 않는다.
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
        var saved = 0
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            var gotText = false
            for p in item.attachments ?? [] {
                if p.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    if let url = try? await p.loadItem(forTypeIdentifier: UTType.audio.identifier) as? URL, Inbox.put(file: url) { saved += 1 }
                } else if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let got = try? await p.loadItem(forTypeIdentifier: UTType.image.identifier)
                    var image: UIImage?
                    if let url = got as? URL { image = UIImage(contentsOfFile: url.path) } else if let i = got as? UIImage { image = i } else if let d = got as? Data { image = UIImage(data: d) }
                    if let data = image?.jpegData(compressionQuality: 0.85), Inbox.put(image: data) { saved += 1 }
                } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let s = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String, Inbox.put(text: s) { saved += 1; gotText = true }
                } else if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    // 링크만 왔으면 같이 온 글(제목·고른 글)을 받는다 — 주소만으로는 챙길 일을 알 수 없다
                    if let s = item.attributedContentText?.string, !gotText, Inbox.put(text: s) { saved += 1; gotText = true }
                }
            }
            if !gotText, (item.attachments ?? []).isEmpty, let s = item.attributedContentText?.string, Inbox.put(text: s) { saved += 1 }
        }
        await MainActor.run { state.saved = saved; state.done = true }
        try? await Task.sleep(for: .milliseconds(saved > 0 ? 1300 : 1800))
        await MainActor.run { extensionContext?.completeRequest(returningItems: nil) }
    }
}

@Observable final class ShareState {
    var done = false
    var saved = 0
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
                Text(!state.done ? "받는 중…" : state.saved > 0 ? "우다다가 받아 뒀어." : "받을 수 있는 게 없었어.")
                    .font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(ink)
                Text(!state.done ? " " : state.saved > 0 ? "앱을 열면 이 iPhone 의 Apple Intelligence 가 챙길 일정과 할 일만 골라 줘. 기기 밖으로 나가지 않아."
                                                            : "글, 사진, 녹음을 공유해 줘.")
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
