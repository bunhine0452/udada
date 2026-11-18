#if os(iOS)
import AppIntents
import SwiftUI
import UIKit
import UserNotifications

// 화면 그대로 · 우다다로 받기: 앱을 열지 않고, 보던 자리에서.
// - ScreenIntent: 단축어가 넘긴 스크린샷(또는 글)에서 받은 약속을 찾아 내 일정에 대어 보고 답장을 고르게 한다.
//   단축어 「스크린샷 찍기 → 화면 그대로」를 만들면 뒷면 탭 · 동작 버튼 · 제어 센터 · 홈 화면 · Siri 이름 어디에든 걸 수 있다.
// - ReceiveIntent: 단축어 자동화(메시지 · 메일을 받을 때)가 넘긴 글에서 챙길 일정을 받아 두고 알림 한 줄을 보낸다.
// 날 · 시각 · 겹침은 규칙이 실제 기록으로 정하고, 모델은 답장 문장만 다듬는다 (Reply.swift 와 같은 짜임).

@MainActor
enum ScreenWork {
    struct Out {
        var read: ScreenRead
        var check: ReplyCheck?
        var drafts: [ReplyDraft] = []
        var fromAI: Bool { drafts.contains { $0.fromAI } }
    }

    static func pieces(_ image: CGImage) async -> [ScreenPiece] {
        let w = Double(image.width), h = Double(image.height)
        guard w > 0, h > 0 else { return [] }
        return await TextScan.fragments(in: image).map { f in
            ScreenPiece(text: f.text, minX: Double(min(f.topLeft.x, f.bottomLeft.x)) / w, maxX: Double(max(f.topRight.x, f.bottomRight.x)) / w,
                        top: 1 - Double(max(f.topLeft.y, f.topRight.y)) / h)
        }
    }

    static func external(_ data: AppData, around day: DayKey) -> [Entry] {
        if let s = Store.live { return s.external }
        return data.settings.calendarOn ? CalendarService.shared.entries(from: day, days: 8, hidden: data.settings.hiddenCalendars) : []
    }

    static func run(image: CGImage?, text: String?, polish: Bool = true) async -> Out {
        let now = IntentData.now
        var read: ScreenRead = .nothing
        if let image { read = ScreenRules.read(await pieces(image), now: now) }
        if read == .nothing, let t = text, t.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 { read = ScreenRules.read(text: t, now: now) }
        guard case .offer(let message) = read, let offer = ReplyRules.offer(from: message, now: now) else { return Out(read: read) }
        let data = IntentData.read()
        let check = ReplyRules.check(offer, data: data, external: external(data, around: offer.day), now: now)
        let drafts = polish ? await Brain.shared.polish(check) : ReplyRules.drafts(check)
        return Out(read: read, check: check, drafts: drafts)
    }
}

struct ScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "화면 그대로"
    static let description: IntentDescription? = IntentDescription("보고 있던 대화나 안내 화면을 읽어, 받은 약속을 내 일정에 대어 보고 답장을 써 줘. 앞에 ‘스크린샷 찍기’를 두고 그 결과를 넘겨.")

    @Parameter(title: "화면", description: "스크린샷", supportedContentTypes: [.image])
    var screen: IntentFile?

    @Parameter(title: "글", description: "스크린샷 대신 넘길 글 (없으면 복사해 둔 글)")
    var text: String?

    static var parameterSummary: some ParameterSummary { Summary("\(\.$screen) 그대로 읽기") { \.$text } }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        var image: CGImage?
        if let d = screen?.data, let ui = UIImage(data: d) { image = TextScan.upright(ui) }
        let fallback = text ?? (image == nil ? UIPasteboard.general.string : nil)
        let out = await ScreenWork.run(image: image, text: fallback)
        if let c = out.check {
            let head = ReplyRules.verdict(c)
            return .result(value: out.drafts.first?.text ?? "", dialog: IntentDialog(stringLiteral: head),
                           view: ScreenSnippet(head: head, quote: c.offer.message, drafts: out.drafts, check: c, lines: [], ai: out.fromAI))
        }
        if case .lines(let lines) = out.read {
            for l in lines { Inbox.put(text: l) }
            Store.live?.inboxCount = Inbox.items().count
            let head = lines.count == 1 ? "챙길 게 하나 있어. 받아 뒀어." : "챙길 게 \(lines.count)개 있어. 받아 뒀어."
            return .result(value: lines.joined(separator: "\n"), dialog: IntentDialog(stringLiteral: head),
                           view: ScreenSnippet(head: head, quote: "", drafts: [], check: nil, lines: lines, ai: false))
        }
        let head = "이 화면에서는 약속이나 챙길 일정을 못 찾았어."
        return .result(value: "", dialog: IntentDialog(stringLiteral: head),
                       view: ScreenSnippet(head: head, quote: "", drafts: [], check: nil, lines: [], ai: false))
    }
}

/// 결과 카드의 답장 버튼: 문장을 복사하고, 가기로 한 답이면 약속을 넣는다.
struct CopyReplyIntent: AppIntent {
    static let title: LocalizedStringResource = "답장 복사"
    static let isDiscoverable = false

    @Parameter(title: "답장") var reply: String
    @Parameter(title: "약속 이름") var name: String
    /// yyyymmdd, 0 이면 일정에 넣지 않는다 (거절)
    @Parameter(title: "날") var day: Int
    @Parameter(title: "시각(분)") var time: Int
    @Parameter(title: "길이(분)") var duration: Int

    init() {}
    init(reply: String, name: String, day: DayKey?, time: Int, duration: Int) {
        self.reply = reply
        self.name = name
        self.day = day.map { $0.y * 10000 + $0.m * 100 + $0.d } ?? 0
        self.time = time
        self.duration = duration
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UIPasteboard.general.string = reply
        guard day > 0 else { return .result(dialog: "복사했어. 붙여 넣기만 하면 돼.") }
        let key = DayKey(y: day / 10000, m: (day / 100) % 100, d: day % 100)
        let now = IntentData.now
        let title = name, t = time, dur = duration
        await IntentData.write { d in
            guard !d.items.contains(where: { $0.title == title && $0.day == key && $0.time == t }) else { return }
            d.items.append(Item(title: title, day: key, part: d.settings.parts.part(at: t), time: t, duration: dur, created: now))
        }
        return .result(dialog: "복사했어. ‘\(title)’도 일정에 넣었어.")
    }
}

/// 단축어 자동화가 넘긴 글(문자 · 메일 등)에서 챙길 것만 받아 둔다. 일정에 넣는 것은 사용자가 누른다.
struct ReceiveIntent: AppIntent {
    static let title: LocalizedStringResource = "우다다로 받기"
    static let description: IntentDescription? = IntentDescription("받은 문자 · 메일 · 글에서 챙길 일정만 골라 받아 두고, 내 약속과 겹치면 알려 줘. 자동화의 ‘메시지를 받을 때’ · ‘이메일을 받을 때’에 걸어 두면 손대지 않아도 들어와.")

    @Parameter(title: "받은 글")
    var text: String

    static var parameterSummary: some ParameterSummary { Summary("\(\.$text) 받기") }

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let note = await ReceiveIntent.receive(text)
        return .result(value: note, dialog: IntentDialog(stringLiteral: note.isEmpty ? "챙길 건 없었어." : note))
    }

    /// 받아 두고 알림 한 줄. 돌려주는 값은 알림 글(챙길 게 없으면 빈 글).
    @MainActor
    static func receive(_ text: String) async -> String {
        let now = IntentData.now
        guard !ScreenRules.isJunk(text) else { return "" }
        let found = await Brain.shared.capture(text, now: now)
        guard !found.lines.isEmpty else { return "" }
        for l in found.lines { Inbox.put(text: l) }
        Store.live?.inboxCount = Inbox.items().count
        let data = IntentData.read()
        let note = ScreenRules.notice(found.lines, data: data, external: ScreenWork.external(data, around: DayKey(now)), now: now)
        let c = UNMutableNotificationContent()
        c.title = "받은 글에 챙길 게 있어"
        c.body = note
        c.sound = nil
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "received-\(Int(now.timeIntervalSince1970))", content: c, trigger: nil))
        return note
    }
}

struct ScreenSnippet: View {
    var head: String
    var quote: String
    var drafts: [ReplyDraft]
    var check: ReplyCheck?
    var lines: [String]
    var ai: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("우다다").font(Typo.serif(15, relativeTo: .subheadline)).foregroundStyle(Ink.text)
                if ai { GAIMark() }
                Spacer()
            }
            if !quote.isEmpty {
                Text("“\(quote)”").font(Typo.meta).foregroundStyle(Ink.text2).lineLimit(2)
            }
            Text(head).font(.system(.headline, weight: .bold)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            if let c = check {
                ForEach(drafts) { d in
                    let slot: ReplyCheck.Slot? = d.kind == .accept ? .init(day: c.offer.day, time: c.offer.time) : d.kind == .alternative ? c.alt : nil
                    Button(intent: CopyReplyIntent(reply: d.text, name: c.offer.title, day: slot?.day, time: slot?.time ?? 0, duration: c.offer.duration)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(d.label + (slot == nil ? " · 복사" : " · 복사하고 일정에")).font(Typo.meta).foregroundStyle(Ink.accent)
                            Text(d.text).font(Typo.row).foregroundStyle(Ink.text)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.accentSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            ForEach(lines.prefix(5), id: \.self) { l in
                Text(l).font(Typo.row).foregroundStyle(Ink.text).lineLimit(2)
            }
            if !lines.isEmpty { Text("앱을 열면 넣을지 고를 수 있어").font(Typo.meta).foregroundStyle(Ink.text3) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.sheet)
    }
}
#endif
