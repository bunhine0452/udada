import SwiftUI
import UIKit
import PhotosUI

// 화면 그대로 · 복사한 글 알아보기의 앱 안 입구.
// - 복사한 글: 붙여넣기 허락을 묻지 않고 '일정처럼 보이는 글이 있나'만 알아본 뒤, 눌렀을 때 읽는다.
// - 화면: 스크린샷 한 장에서 받은 약속을 찾아 답장으로, 안내문이면 받아 둔 것으로.

extension Store {
    private static let seenKey = "udada.clip.seen"

    /// 앱이 앞으로 올 때: 새로 복사한 글에 약속이 보이면 넣기 줄 위에 한 줄을 띄운다.
    func checkClipboard() {
        let pb = UIPasteboard.general
        let count = pb.changeCount
        guard count != UserDefaults.standard.integer(forKey: Store.seenKey), pb.hasStrings else { clipHint = false; return }
        Task { @MainActor in
            let found = (try? await pb.detectedPatterns(for: [\.calendarEvents])) ?? []
            clipHint = found.contains(\.calendarEvents)
        }
    }

    func dismissClipboard() {
        UserDefaults.standard.set(UIPasteboard.general.changeCount, forKey: Store.seenKey)
        clipHint = false
    }

    /// 복사해 둔 글을 받는다: 약속을 묻는 글이면 답장으로, 아니면 받아 둔 것으로 비우기에.
    func takeClipboard() {
        let raw = UIPasteboard.general.string
        dismissClipboard()
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), t.count >= 2 else {
            show("복사해 둔 글이 없어")
            return
        }
        if ReplyRules.looksLikeOffer(t, now: now) {
            reply = ReplyRequest(text: t)
            return
        }
        Inbox.put(text: t)
        inboxCount = Inbox.items().count
        takeInbox = true
        dumpMode = .text
        cover = .dump
    }

    /// 스크린샷 한 장을 읽는다 (앱 안에서 고른 그림 · 확인용 -udScreen)
    func readScreen(_ image: UIImage) async {
        guard let cg = TextScan.upright(image) else { show("그림을 못 읽었어"); return }
        let out = await ScreenWork.run(image: cg, text: nil, polish: false)
        switch out.read {
        case .offer(let message):
            reply = ReplyRequest(text: message)
        case .lines(let lines):
            for l in lines { Inbox.put(text: l) }
            inboxCount = Inbox.items().count
            takeInbox = true
            dumpMode = .text
            cover = .dump
        case .nothing:
            show("이 화면에서는 약속이나 챙길 일정을 못 찾았어")
        }
    }
}

/// 넣기 줄 위의 한 줄: 방금 복사한 글에 약속이 보일 때만
struct ClipChip: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            Button { Haptic.tap(); store.takeClipboard() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard").font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.accent)
                        .accessibilityHidden(true)
                    Text("방금 복사한 글에 약속이 보여").font(Typo.row).foregroundStyle(Ink.text)
                    Spacer(minLength: 4)
                    Text("받기").font(Typo.meta).foregroundStyle(Ink.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clip.take")
            Button { store.dismissClipboard() } label: {
                Image(systemName: "xmark").font(.system(.caption, weight: .bold)).foregroundStyle(Ink.text3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("clip.dismiss")
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.accentSoft))
    }
}

/// 화면 그대로: 지금 해 보기 + 어디서든 부르게 거는 법 + 자동으로 받기
struct ScreenSetupView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var pick: PhotosPickerItem?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("화면 그대로").font(Typo.serif(26, relativeTo: .title)).foregroundStyle(Ink.text)
                            .accessibilityAddTraits(.isHeader)
                        Text("카톡 · 문자 · 메일 어디서든, 보고 있던 화면을 그대로 읽어. 받은 약속이면 내 일정에 대어 보고 답장을 써 주고, 예약 안내면 챙길 것만 받아 둬.")
                            .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PhotosPicker(selection: $pick, matching: .screenshots) {
                        HStack(spacing: 8) {
                            if busy { ProgressView() } else { Image(systemName: "photo.on.rectangle") }
                            Text(busy ? "읽는 중" : "스크린샷 골라서 해 보기")
                        }
                    }
                    .buttonStyle(FillButton(tone: .ink))
                    .disabled(busy)
                    .accessibilityIdentifier("screen.pick")

                    block("어디서든 부르기", [
                        "단축어 앱에서 새 단축어를 만들어.",
                        "동작 ‘스크린샷 찍기’를 넣고, 그 아래에 ‘화면 그대로’(우다다)를 넣어. 화면 칸에 스크린샷이 들어가.",
                        "이 단축어를 원하는 데 걸어: 뒷면 두 번·세 번 두드리기(설정 → 손쉬운 사용 → 터치 → 뒷면 탭), 동작 버튼, 제어 센터, 홈 화면 아이콘, 잠금 화면, Siri로 부르는 이름.",
                        "걸어 둔 걸 누르면 보던 화면 위에 답이 떠. 답장을 누르면 복사되고 약속도 들어가.",
                    ])
                    Button("단축어 앱 열기") { if let u = URL(string: "shortcuts://create-shortcut") { openURL(u) } }
                        .buttonStyle(FillButton(tone: .line))
                        .accessibilityIdentifier("screen.shortcuts")

                    block("손대지 않아도 받기", [
                        "단축어 앱 → 자동화 → 새로운 자동화에서 ‘메시지’ 또는 ‘이메일’을 골라.",
                        "‘예약’, ‘안내’ 같은 낱말이 든 글을 받을 때로 정하고 ‘즉시 실행’을 켜.",
                        "동작으로 ‘우다다로 받기’를 넣고, 받은 글 칸에 ‘단축어 입력’을 넣어.",
                        "그 뒤로는 예약 문자가 오면 알림으로 알려 줘. 내 약속과 겹치면 같이 말해.",
                    ])
                    Text("카카오톡처럼 다른 앱에 온 글은 iOS 가 자동으로 넘겨주지 않아. 그런 글은 위의 화면 그대로, 공유 → 우다다, 또는 복사한 뒤 우다다 열기로 받아.")
                        .font(Typo.meta).foregroundStyle(Ink.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Ink.sheet)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() }.accessibilityIdentifier("screen.close") } }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            busy = true
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                pick = nil
                guard let data, let ui = UIImage(data: data) else { busy = false; store.show("그림을 못 읽었어"); return }
                dismiss()
                try? await Task.sleep(for: .milliseconds(450))
                await store.readScreen(ui)
                busy = false
            }
        }
    }

    private func block(_ title: String, _ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Typo.serif(19, relativeTo: .headline)).foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(i + 1)").font(.system(.footnote, design: .rounded, weight: .bold)).foregroundStyle(Ink.accent)
                        .frame(width: 18, alignment: .leading)
                    Text(s).font(.system(.subheadline)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
