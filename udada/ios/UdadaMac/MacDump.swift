import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mac 에서 비우기: 자판으로 쏟아내면 이 Mac 의 Apple Intelligence가 한 줄씩 떼어 네 칸으로 나눈다.
/// 종이 목록은 아이폰 카메라로 찍으면(연속성 카메라) 이 창으로 바로 들어온다. 사진·스크린샷을 끌어다 놓아도 된다.
struct MacDump: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    static var seedText: String?
    static var seedImage: String?
    /// 밖에서 받은 글 (서비스 메뉴 '우다다로 보내기' · -udRun capture:…)
    static var seedCapture: String?
    /// 녹음 파일 경로 (-udRun audio:…)
    static var seedAudio: String?
    /// 무엇에서 찾았는지 한 줄 (받은 글 · 녹음)
    @State private var source: String?
    @State private var hearing = false
    private enum Stage { case write, sorting, sort }
    @State private var stage: Stage = .write
    @State private var raw = ""
    @State private var cards: [Card] = []
    @State private var reading = false
    @State private var dropping = false
    @State private var sawPhoto = false
    @State private var camera = CameraImport()
    @FocusState private var editing: Bool

    private struct Card: Identifiable, Hashable {
        var id = UUID()
        var suggestion: DumpSuggestion
        var bin: DumpBin
        /// 사용자가 칸을 직접 바꿨나 (그러면 모델이 나중에 덮지 않는다)
        var touched = false
    }
    @State private var refining = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(stage == .sort ? "어디에 둘까" : "쏟아내기")
                    .font(Typo.serif(22)).foregroundStyle(Ink.text)
                if stage == .sort && refining {
                    HStack(spacing: 5) { ProgressView().controlSize(.mini); Text("Apple Intelligence가 한 장씩 다듬는 중").font(.system(size: 11, weight: .medium)).foregroundStyle(Ink.accent) }
                } else if stage == .sort && cards.contains(where: { $0.suggestion.fromAI }) { AppleAIBadge(text: "Apple Intelligence가 나눔") }
                Spacer()
                Button("닫기") { dismiss() }.buttonStyle(MacGhost()).keyboardShortcut(.cancelAction)
            }
            .padding(.bottom, 4)
            Text(stage == .sort ? "칸이 틀리면 눌러서 바꿔. 버리기는 진짜로 지워져." : "머릿속에 도는 걸 순서 없이 다 적어. 다듬지 않아도 돼.")
                .font(.system(size: 12.5)).foregroundStyle(Ink.text2)
                .padding(.bottom, 14)

            switch stage {
            case .write: writeStage
            case .sorting: sortingStage
            case .sort: sortStage
            }
        }
        .padding(24)
        .frame(width: 620, height: 540)
        .background(Ink.ground)
        .onAppear {
            editing = true
            if store.settings.aiOn { Brain.shared.prewarm() }
            // 확인용(-udRun dump:…): 글을 채워서 바로 나눈다
            if let seed = MacDump.seedText { MacDump.seedText = nil; raw = seed; organize() }
            // 확인용(-udRun photo:<경로>): 그림을 끌어다 놓은 것처럼 읽는다
            if let path = MacDump.seedImage {
                MacDump.seedImage = nil
                if let cg = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) { read(cg) }
            }
            if let text = MacDump.seedCapture { MacDump.seedCapture = nil; capture(text, from: "받은 글에서 찾음") }
            if let path = MacDump.seedAudio { MacDump.seedAudio = nil; hear(URL(fileURLWithPath: path)) }
        }
    }

    // MARK: 적기

    private var writeStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $raw)
                    .font(.system(size: 15))
                    .foregroundStyle(Ink.text)
                    .scrollContentBackground(.hidden)
                    .focused($editing)
                    .writingToolsBehavior(.disabled) // 날것 그대로 — 다듬는 건 '나누기'가 한다
                    .padding(10)
                    .accessibilityIdentifier("dump.editor")
                if raw.isEmpty {
                    Text("엄마한테 전화해야 되고 보고서도 써야 되는데 월세 오르면 어떡하지…")
                        .font(.system(size: 15)).foregroundStyle(Ink.text3)
                        .padding(.horizontal, 15).padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                if reading {
                    HStack(spacing: 6) { BreathDot(size: 7); Text(hearing ? "녹음을 이 Mac 안에서 받아쓰는 중" : Brain.canSeeImages() && Brain.shared.isReady ? "사진을 보는 중" : "글자를 읽는 중").font(.system(size: 12)).foregroundStyle(Ink.text2) }
                        .padding(8).paper(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ink.accent, lineWidth: dropping ? 2 : 0))
            .onDrop(of: [.image, .fileURL], isTargeted: $dropping) { providers in
                loadImage(providers)
                return true
            }

            HStack(spacing: 10) {
                Button { camera.popUp() } label: { Label("아이폰으로 찍기", systemImage: "iphone.rear.camera") }
                    .buttonStyle(MacFill(tone: .quiet))
                    .background(CameraAnchor(holder: camera) { cg in read(cg) })
                    .help("종이 목록·메모를 아이폰 카메라로 찍으면 여기로 바로 들어와 (연속성 카메라)")
                Menu {
                    Button("클립보드의 글에서 찾기") { if let s = NSPasteboard.general.string(forType: .string) { capture(s, from: "받은 글에서 찾음") } }
                    Button("녹음 파일에서 찾기…") { pickAudio() }
                } label: { Label("밖에서 받기", systemImage: "tray.and.arrow.down") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help("남이 보낸 메시지·메일이나 회의 녹음에서 챙길 일정과 할 일만 뽑아 와")
                if let source {
                    AppleAIBadge(text: source)
                } else if sawPhoto {
                    AppleAIBadge(text: "사진에서 일정을 찾음")
                } else {
                    Text("사진·녹음 파일을 끌어다 놓아도 돼").font(.system(size: 11.5)).foregroundStyle(Ink.text3)
                }
                Spacer()
                brainStatus
                Button { organize() } label: { Text("나누기") }
                    .buttonStyle(MacFill(tone: .accent))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("dump.organize")
            }
        }
    }

    @ViewBuilder private var brainStatus: some View {
        switch Brain.shared.status {
        case .ready: AppleAIBadge(text: "기기 안에서만")
        case .off: Text("규칙으로 나눠").font(.system(size: 11)).foregroundStyle(Ink.text3)
        case .unavailable(let why): Text("규칙으로 나눠").font(.system(size: 11)).foregroundStyle(Ink.text3).help(why)
        }
    }

    private var sortingStage: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().controlSize(.regular)
            Text(Brain.shared.isReady ? "이 Mac 안에서 한 줄씩 떼는 중" : "한 줄씩 떼는 중")
                .font(.system(size: 13)).foregroundStyle(Ink.text2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 나누기

    private var sortStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach($cards) { $card in cardRow($card) }
                }
            }
            .scrollIndicators(.never)
            HStack {
                Button("다시 적기") { stage = .write; editing = true }.buttonStyle(MacFill(tone: .quiet))
                Spacer()
                Text(summary).font(.system(size: 11.5)).foregroundStyle(Ink.text3)
                Button("자리에 넣기") { place() }
                    .buttonStyle(MacFill(tone: .accent))
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityIdentifier("dump.place")
            }
        }
    }

    private func cardRow(_ card: Binding<Card>) -> some View {
        let c = card.wrappedValue
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(c.suggestion.text)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(c.bin == .drop ? Ink.text3 : Ink.text)
                    .strikethrough(c.bin == .drop, color: Ink.text3)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    if c.suggestion.fromAI { Image(systemName: "apple.intelligence").font(.system(size: 9, weight: .semibold)).foregroundStyle(Ink.accent).transition(.opacity) }
                    Text(where_(c)).font(.system(size: 11)).foregroundStyle(Ink.text3).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                ForEach(DumpBin.allCases, id: \.self) { b in
                    Button { card.wrappedValue.bin = b; card.wrappedValue.touched = true } label: {
                        Text(Self.name(b))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(c.bin == b ? Ink.sheet : Ink.text2)
                            .padding(.horizontal, 8).frame(height: 24)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(c.bin == b ? (b == .drop ? Ink.stamp : Ink.text) : .clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ink.fill))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .paper(10)
    }

    private static func name(_ b: DumpBin) -> String {
        switch b { case .now: "지금"; case .date: "날짜"; case .worry: "걱정"; case .drop: "버리기" }
    }

    /// 카드가 갈 자리 한 줄
    private func where_(_ c: Card) -> String {
        switch c.bin {
        case .now: return "오늘 지금 띠로 · 2분 안에 끝나는 일"
        case .worry: return "걱정 상자로 · 걱정 시간에 꺼내 봐"
        case .drop: return "안 하기로"
        case .date:
            let p = Parser.parse(c.suggestion.text, now: store.now, parts: store.settings.parts)
            var s = c.suggestion; s.bin = .date
            let w = DumpPlan.suggestedWhen(s, parsed: p) ?? .day(store.today.adding(days: 1), .morning)
            return DumpPlan.label(w, time: p.time, today: store.today) + (c.suggestion.reason.isEmpty ? "" : " · " + c.suggestion.reason)
        }
    }

    private var summary: String {
        let n = cards.filter { $0.bin != .drop }.count
        let d = cards.count - n
        return "\(n)개 넣고" + (d > 0 ? " \(d)개 버려" : "")
    }

    // MARK: 동작

    /// 누르면 규칙 카드가 바로 뜨고, Apple Intelligence 가 한 장씩 다듬는 대로 그 카드만 바뀐다 (기다리는 화면이 없다)
    private func organize() {
        let text = raw
        refining = Brain.shared.isReady
        Task {
            for await list in Brain.shared.organizeStream(text, today: store.today, now: store.now) {
                withAnimation(.easeOut(duration: 0.22)) { merge(list) }
                stage = cards.isEmpty ? .write : .sort
            }
            refining = false
        }
    }

    /// 새 목록을 끼운다: 조각이 같은 카드는 자리를 지키고(사용자가 칸을 바꿨으면 칸도 지킨다), 달라진 것만 바꾼다
    private func merge(_ list: [DumpSuggestion]) {
        var next: [Card] = []
        var old = cards
        for s in list {
            if let i = old.firstIndex(where: { $0.suggestion.piece == s.piece && s.piece >= 0 }) {
                var c = old.remove(at: i)
                let keepBin = c.touched ? c.bin : s.bin
                c.suggestion = s; c.bin = keepBin
                next.append(c)
            } else {
                next.append(Card(suggestion: s, bin: s.bin))
            }
        }
        cards = next
    }

    private func place() {
        let now = store.now, today = store.today, settings = store.settings
        var items: [Item] = []
        for (i, c) in cards.enumerated() {
            var s = c.suggestion; s.bin = c.bin
            let p = Parser.parse(s.text, now: now, parts: settings.parts)
            let when: DumpPlan.When? = c.bin == .date ? (DumpPlan.suggestedWhen(s, parsed: p) ?? .day(today.adding(days: 1), .morning)) : nil
            if let it = DumpPlan.item(for: s, bin: c.bin, when: when, today: today, now: now, settings: settings,
                                      created: now.addingTimeInterval(Double(i) * 0.001)) { items.append(it) }
        }
        store.change { d in for it in items { d.add(it) } }
        store.show("\(items.count)개를 자리에 넣었어")
        Haptic.success()
        dismiss()
    }

    // MARK: 사진 → 글자 (Vision, 기기 안)

    private func loadImage(_ providers: [NSItemProvider]) {
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                p.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let cg = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                    Task { @MainActor in read(cg) }
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url, AudioNotes.isAudio(url) { Task { @MainActor in hear(url) }; return }
                    guard let url, let cg = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                    Task { @MainActor in read(cg) }
                }
            }
        }
    }

    // MARK: 밖에서 받기 (남이 보낸 글 · 녹음)

    /// 남이 보낸 글에서 챙길 줄만 뽑아 적는 칸에 넣는다. 그 뒤는 여느 비우기와 같다 (눌러야 나눈다 — 먼저 보고 고칠 수 있게).
    private func capture(_ text: String, from label: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        reading = true
        Task {
            let got = await Brain.shared.capture(text, now: store.now)
            reading = false; hearing = false
            guard !got.lines.isEmpty else { store.show("챙길 일정이나 할 일을 못 찾았어"); return }
            withAnimation(Motion.soft) {
                raw += (raw.isEmpty || raw.hasSuffix("\n") ? "" : "\n") + got.lines.joined(separator: "\n")
                source = label
            }
        }
    }

    private func hear(_ url: URL) {
        reading = true; hearing = true
        Task {
            do {
                let heard = try await AudioNotes.transcribe(url)
                capture(heard, from: "녹음에서 찾음")
            } catch {
                reading = false; hearing = false
                store.show(AudioNotes.message(error))
            }
        }
    }

    private func pickAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        panel.message = "회의·통화 녹음을 고르면 이 Mac 안에서 받아쓰고 챙길 일만 뽑아. 녹음은 저장하지 않아."
        if panel.runModal() == .OK, let url = panel.url { hear(url) }
    }

    private func read(_ image: CGImage) {
        reading = true
        Task {
            let ocr = await TextScan.recognize(image)
            guard !ocr.isEmpty else { reading = false; store.show("읽을 글자를 못 찾았어"); return }
            // 포스터·안내문이면 Apple Intelligence 가 그림을 보고 날짜와 이름을 묶는다 (못 보면 읽은 줄 그대로)
            let seen = await Brain.shared.readPhoto(image, ocr: ocr)
            reading = false
            sawPhoto = seen.fromAI
            raw += (raw.isEmpty || raw.hasSuffix("\n") ? "" : "\n") + seen.lines.joined(separator: "\n")
        }
    }
}

// MARK: - 연속성 카메라

/// 'iPhone 에서 가져오기' 메뉴를 띄운다. 시스템이 근처 아이폰의 카메라를 열고, 찍은 사진을 이 뷰로 돌려준다.
@MainActor
final class CameraImport {
    fileprivate weak var view: CameraRequestorView?
    func popUp() { view?.popUp() }
}

private struct CameraAnchor: NSViewRepresentable {
    var holder: CameraImport
    var onImage: (CGImage) -> Void

    func makeNSView(context: Context) -> CameraRequestorView {
        let v = CameraRequestorView()
        v.onImage = onImage
        holder.view = v
        return v
    }
    func updateNSView(_ v: CameraRequestorView, context: Context) { v.onImage = onImage }
}

final class CameraRequestorView: NSView, NSServicesMenuRequestor {
    var onImage: ((CGImage) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        if let returnType, NSImage.imageTypes.contains(returnType.rawValue) { return self }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }

    func readSelection(from pboard: NSPasteboard) -> Bool {
        guard let image = NSImage(pasteboard: pboard), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        onImage?(cg)
        return true
    }

    func popUp() {
        window?.makeFirstResponder(self)
        let menu = NSMenu()
        let item = NSMenuItem(title: "iPhone 에서 가져오기", action: nil, keyEquivalent: "")
        item.identifier = NSMenuItem.importFromDeviceIdentifier
        menu.addItem(item)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 6), in: self)
    }
}
