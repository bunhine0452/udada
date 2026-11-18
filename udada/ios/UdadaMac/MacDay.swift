import AppKit
import SwiftUI

// 하루 한 장의 조각들: 한 줄 넣기 · 지금 줄 · 할 일 줄 · 약속 덩어리. 메뉴 막대와 창이 같이 쓴다.

// MARK: - 한 줄 넣기

/// 치면서 바로 읽는다: "내일 3시 치과" → [내일] [15:00] [1시간]
struct AddField: View {
    @Environment(Store.self) private var store
    @Binding var text: String
    var day: DayKey? = nil
    var large = false
    var prompt = "내일 3시 치과 · 보고서 30분"
    var onAdded: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}
    @FocusState.Binding var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 12 : 7) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: large ? 17 : 12, weight: .bold))
                    .foregroundStyle(text.isEmpty ? Ink.text3 : Ink.accent)
                TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Ink.text3))
                    .textFieldStyle(.plain)
                    .font(.system(size: large ? 21 : 13.5, weight: large ? .medium : .regular))
                    .foregroundStyle(Ink.text)
                    .focused($focused)
                    .onSubmit(submit)
                    .onExitCommand(perform: onCancel)
                    .accessibilityIdentifier("add.field")
                if !text.isEmpty && !large {
                    KeyCap(text: "↩")
                }
            }
            if let p = preview {
                HStack(spacing: 6) {
                    ForEach(p.chips, id: \.self) { c in
                        Text(c)
                            .font(Typo.num(size: large ? 12.5 : 11, .semibold))
                            .foregroundStyle(Ink.accent)
                            .padding(.horizontal, 7)
                            .frame(height: large ? 22 : 19)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.accentSoft))
                    }
                    Text(p.title)
                        .font(.system(size: large ? 13 : 11.5, weight: .medium))
                        .foregroundStyle(Ink.text2)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: preview?.chips)
    }

    private struct Preview: Equatable { var chips: [String]; var title: String }

    /// 넣으면 어디로 가는지 미리 (넣기와 같은 규칙으로 읽는다)
    private var preview: Preview? {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, let it = AddEntryIntent.item(from: raw, now: store.now, settings: store.settings) else { return nil }
        var chips: [String] = []
        if let r = it.repeatRule { chips.append(r.label) }
        else if it.isLater { chips.append("나중에") }
        else {
            let parsed = Parser.parse(raw, now: store.now, parts: store.settings.parts)
            let d = (parsed.day == nil ? day : nil) ?? it.day
            chips.append(Fmt.day(d, today: store.today))
        }
        if !it.isLater { chips.append(it.time.map(Fmt.hm) ?? it.part.name) }
        chips.append(Fmt.dur(it.duration))
        return Preview(chips: chips, title: it.title)
    }

    private func submit() {
        // 이미 있는 일을 바꾸라는 말이면 새로 넣지 않고 '말로 하기'로 보낸다 (미리 보여 주고 적용)
        if CommandRules.looksLikeCommand(text),
           CommandRules.plan(text, data: store.data, now: store.now).steps.contains(where: { $0.kind != .add && $0.ok }) {
            store.pendingAddText = text
            text = ""
            onCancel()
            store.cover = .find
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let placed = store.quickAdd(text, on: day) else { return }
        text = ""
        Haptic.tap()
        onAdded(placed)
    }
}

// MARK: - 지금 줄

/// 코발트 줄 하나: 다음 약속까지 남은 시간 + 그 안에 들어가는 일
struct NowCard: View {
    @Environment(Store.self) private var store
    var line: NowLine
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Ink.accent).frame(width: 4)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("지금").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.accent)
                    Text(Fmt.hm(line.minute)).font(Typo.num(size: 11.5, .semibold)).foregroundStyle(Ink.accent)
                }
                Text(line.headline)
                    .font(Typo.serif(compact ? 17 : 22))
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line.advice)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let fit = line.fit, store.data.activeFocus == nil {
                Button {
                    store.startFocus(fit)
                } label: {
                    Label("집중", systemImage: "play.fill")
                }
                .buttonStyle(MacFill(tone: .accent, compact: compact))
                .help("‘\(fit.title)’ \(Fmt.dur(fit.duration)) — iPhone 에서도 같은 시계가 돌아")
                .accessibilityIdentifier("now.focus")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 돌고 있는 집중: 흐른 시간 / 예정, 끝냄 · 멈춤. 처음 보는 일이면 Apple Intelligence 가 2분짜리 첫 동작을 붙인다.
struct FocusStrip: View {
    @Environment(Store.self) private var store
    @Environment(Ticker.self) private var ticker
    var active: ActiveFocus
    var compact = false
    @State private var step: String?
    @State private var stepFromAI = false

    var body: some View {
        let _ = ticker.second
        let elapsed = Int(Date().timeIntervalSince(active.started))
        let over = elapsed > active.planned * 60
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("집중 중").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.nightSoft)
                    Text(active.title).font(.system(size: compact ? 13.5 : 15, weight: .semibold)).foregroundStyle(Ink.nightText).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(clockText(elapsed))
                        .font(Typo.num(size: compact ? 22 : 28, .bold))
                        .foregroundStyle(over ? Color(hex: 0xFF9C85) : Ink.nightText)
                        .contentTransition(.numericText())
                    Text("예상 \(Fmt.dur(active.planned))").font(.system(size: 10.5)).foregroundStyle(Ink.nightSoft)
                }
                VStack(spacing: 5) {
                    Button("끝냄") { store.stopFocus(finished: true) }
                        .buttonStyle(MacFill(tone: .night, compact: true))
                        .accessibilityIdentifier("focus.done")
                    Button("멈춤") { store.stopFocus(finished: false) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ink.nightSoft)
                }
            }
            if let step {
                Rectangle().fill(Ink.nightLine).frame(height: 1)
                HStack(spacing: 7) {
                    Text("첫 동작").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Ink.nightSoft)
                    Text(step).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.nightText).lineLimit(1)
                    Spacer(minLength: 4)
                    if stepFromAI {
                        HStack(spacing: 3) {
                            Image(systemName: "apple.intelligence").font(.system(size: 9, weight: .semibold))
                            Text("Apple Intelligence").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: 0x8399FF))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.night))
        .task(id: active.started) { await loadStep() }
    }

    /// 흔한 갈래(문서·전화·청소…)는 다듬어 둔 문장이 바로, 처음 보는 일만 기기 안 모델에게
    private func loadStep() async {
        let t = active.title
        guard !t.isEmpty, t != "집중", !BrainRules.isCrisis(t) else { step = nil; return }
        let tidy = BrainRules.tidy(t)
        step = BrainRules.firstStep(for: tidy)
        stepFromAI = false
        guard Brain.shared.isReady, BrainRules.knownStep(for: tidy) == nil, let got = await Brain.shared.firstStep(for: t) else { return }
        stepFromAI = got != step
        step = got
    }
}

// MARK: - 줄

/// 할 일 한 줄. 올리면 동작이 뜬다 (집중 · 내일로 · 지우기).
struct TodoRow: View {
    @Environment(Store.self) private var store
    var entry: Entry
    var dense = false
    @State private var hover = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Button { store.toggleDone(entry) } label: { MacCheck(done: entry.done) }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.done ? "되돌리기" : "끝내기")
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    if entry.pinned { Image(systemName: "star.fill").font(.system(size: 8.5)).foregroundStyle(Ink.accent) }
                    StruckText(text: entry.title, font: .system(size: 13, weight: .medium), done: entry.done, lineLimit: dense ? 1 : 2)
                        .foregroundStyle(entry.done ? Ink.text3 : Ink.text)
                        .calm(Motion.soft, value: entry.done)
                    if entry.repeating { Image(systemName: "repeat").font(.system(size: 9, weight: .semibold)).foregroundStyle(Ink.text3) }
                }
                if let from = entry.movedFrom, !entry.done, !dense {
                    Text("\(Fmt.day(from, today: store.today))에서 옴").font(.system(size: 10.5)).foregroundStyle(Ink.text3)
                }
            }
            Spacer(minLength: 6)
            if hover && !entry.done {
                HStack(spacing: 4) {
                    if store.data.activeFocus == nil {
                        Button { store.startFocus(entry) } label: { Image(systemName: "play.fill") }
                            .help("집중 시작")
                    }
                    Button { store.move(entry, to: entry.day.adding(days: 1), part: .morning) } label: { Image(systemName: "arrow.right") }
                        .help("내일로")
                }
                .buttonStyle(MacGhost())
                .transition(.opacity)
            } else {
                Text(Fmt.dur(entry.duration))
                    .font(Typo.num(size: 11, .medium))
                    .foregroundStyle(Ink.text3)
            }
        }
        .padding(.trailing, 8)
        .frame(minHeight: dense ? 28 : 32)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? Ink.fill.opacity(0.7) : .clear))
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.1), value: hover)
        .contextMenu { menu }
        .accessibilityIdentifier("row.\(entry.title)")
    }

    @ViewBuilder private var menu: some View {
        Button(entry.done ? "되돌리기" : "끝내기") { store.toggleDone(entry) }
        if !entry.done {
            Button("집중 시작") { store.startFocus(entry) }.disabled(store.data.activeFocus != nil)
            Button(entry.pinned ? "오늘의 하나 풀기" : "오늘의 하나로") { store.pin(entry) }
            if !entry.repeating {
                Button("작게 쪼개기…") {
                    // 메뉴 막대에서 눌러도 창에서 뜬다
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    store.splitting = SplitRequest(title: entry.title, due: entry.day, part: entry.part)
                }
            }
            Divider()
            Menu("옮기기") {
                ForEach(Part.allCases) { p in
                    Button("\(Fmt.day(entry.day, today: store.today)) \(p.name)") { store.move(entry, to: entry.day, part: p) }
                }
                Divider()
                Button("내일 아침") { store.move(entry, to: entry.day.adding(days: 1), part: .morning) }
                Button("나중에") { store.move(entry, to: nil) }
            }
            Button("걱정 상자로") { store.toWorry(entry) }
        }
        Divider()
        Button("지우기", role: .destructive) { store.delete(entry) }
        if entry.repeating { Button("반복 전체 지우기", role: .destructive) { store.delete(entry, wholeSeries: true) } }
    }
}

/// 약속: 박힌 것은 꽉 채운 덩어리. 기기 달력 약속은 왼쪽에 달력 색 줄.
struct EventBlock: View {
    @Environment(Store.self) private var store
    var entry: Entry
    var live = false

    var body: some View {
        HStack(spacing: 9) {
            if let c = entry.color { RoundedRectangle(cornerRadius: 1.5).fill(Color(hex: c)).frame(width: 3, height: 22) }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.blockText).lineLimit(1)
                if let name = entry.calendarName {
                    Text(name).font(.system(size: 10)).foregroundStyle(Ink.blockText2).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let t = entry.time {
                Text(Fmt.hm(t) + (entry.duration > 0 ? "–" + Fmt.hm(t + entry.duration) : ""))
                    .font(Typo.num(size: 11.5, .semibold))
                    .foregroundStyle(Ink.blockText2)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 38)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Ink.block))
        .overlay(alignment: .leading) {
            if live { RoundedRectangle(cornerRadius: 2).fill(Ink.accent).frame(width: 4).padding(.vertical, 6).offset(x: -8) }
        }
        .opacity(entry.done ? 0.45 : 1)
        .contextMenu {
            if !entry.isExternal {
                Button(entry.done ? "되돌리기" : "끝내기") { store.toggleDone(entry) }
                if !entry.done && !entry.repeating {
                    Button("준비를 작게 쪼개기…") { store.splitting = SplitRequest(title: entry.title, due: entry.day, part: .afternoon) }
                }
                Button("지우기", role: .destructive) { store.delete(entry) }
            } else {
                Text("기기 달력의 약속")
            }
        }
    }
}

/// 아래에 잠깐 뜨는 한 줄 (되돌리기)
struct MacToast: View {
    @Environment(Store.self) private var store
    var toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.message).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.blockText).lineLimit(1)
            if toast.canUndo {
                Button("되돌리기") { store.undo() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Ink.blockText)
                    .underline()
                    .keyboardShortcut("z", modifiers: .command)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Capsule().fill(Ink.block))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
