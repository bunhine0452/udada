import SwiftUI

/// 말로 찾기 (Mac, ⌘F). Apple Intelligence 가 물음을 읽고, 답은 내 기록에서 규칙이 찾는다 — 지어낼 자리가 없다.
struct MacFind: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var answer: FindAnswer?
    @State private var plan: CommandPlan?
    @State private var chosen: Set<UUID> = []
    @State private var busy = false
    @State private var widening = false
    @FocusState private var focused: Bool

    private static let examples = ["다음 주에 뭐 있어", "돈 나가는 일 뭐 남았어", "치과 내일로 미루고 보고서는 끝냈어", "지난주에 끝낸 운동 몇 번", "금요일 3시 미팅 추가하고 장보기는 지워 줘"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold)).foregroundStyle(Ink.text3)
                TextField("", text: $text, prompt: Text("물어보거나 시켜 봐 — 치과 내일로 미루고 보고서는 끝냈어").foregroundStyle(Ink.text3))
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Ink.text)
                    .focused($focused)
                    .onSubmit { run(text) }
                    .onExitCommand { dismiss() }
                    .accessibilityIdentifier("find.field")
                if busy { ProgressView().controlSize(.small) }
                KeyCap(text: "esc")
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .paper(13)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))

            if let plan {
                planView(plan)
            } else if let a = answer {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(widening && a.hits.isEmpty ? FindRules.searching(a) : a.line).font(Typo.serif(18)).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("find.answer")
                    if a.hits.contains(where: \.byMeaning) { AppleAIBadge(text: "Apple Intelligence가 뜻으로 찾음") }
                    else if widening { AppleAIBadge(text: "뜻이 가까운 것도 찾는 중") }
                    else if a.query.fromAI { AppleAIBadge(text: "Apple Intelligence가 읽음") }
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(a.hits) { h in
                            Button { open(h) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: h.done ? "checkmark.square.fill" : (h.time != nil ? "clock" : "square"))
                                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(h.done ? Ink.text3 : Ink.text2)
                                    Text(h.title).font(.system(size: 13, weight: .medium)).foregroundStyle(h.done ? Ink.text3 : Ink.text)
                                        .strikethrough(h.done, color: Ink.text3).lineLimit(1)
                                    if h.byMeaning {
                                        Text("뜻").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Ink.accent)
                                            .padding(.horizontal, 4).frame(height: 15)
                                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Ink.accentSoft))
                                            .help("낱말은 다르지만 Apple Intelligence 가 뜻이 맞다고 고른 기록")
                                    }
                                    Spacer(minLength: 8)
                                    Text(FindRules.when(h, today: store.today).trimmingCharacters(in: .whitespaces))
                                        .font(Typo.num(size: 11.5, .semibold)).foregroundStyle(Ink.text2)
                                }
                                .frame(height: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Hairline()
                        }
                        if a.hits.isEmpty, !widening {
                            Text("낱말을 줄이거나 때를 바꿔서 다시 물어봐.").font(.system(size: 12)).foregroundStyle(Ink.text3)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                        }
                    }
                }
                .scrollIndicators(.never)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("이렇게 물어봐").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.text3).padding(.top, 18)
                    ForEach(Self.examples, id: \.self) { ex in
                        Button { text = ex; run(ex) } label: {
                            Text(ex).font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.text)
                                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Hairline()
                    }
                    Text(Brain.shared.isReady ? "말은 이 Mac 의 Apple Intelligence 가 읽고, 찾기와 바꾸기는 내 기록에 대고만 해. 바꾸기 전에 먼저 보여 줘."
                                             : "찾기와 바꾸기는 내 기록에 대고만 해. 바꾸기 전에 먼저 보여 줘.")
                        .font(.system(size: 11.5)).foregroundStyle(Ink.text3).padding(.top, 10)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(width: 560, height: 440, alignment: .top)
        .background(Ink.ground)
        .onAppear {
            let q = store.pendingAddText
            if !q.isEmpty { store.pendingAddText = ""; text = q; run(q) } else { focused = true }
        }
    }

    /// 바꿀 것 미리보기. 줄을 눌러 빼고, ⌘↩ 로 적용. 못 찾은 일은 흐리게 — 아무것도 안 한다.
    @ViewBuilder private func planView(_ p: CommandPlan) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("이렇게 할게").font(Typo.serif(18)).foregroundStyle(Ink.text).accessibilityIdentifier("cmd.title")
            if p.fromAI { AppleAIBadge(text: "Apple Intelligence가 읽음") }
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
        ScrollView {
            VStack(spacing: 0) {
                ForEach(p.steps) { s in
                    Button {
                        guard s.ok else { return }
                        if chosen.contains(s.id) { chosen.remove(s.id) } else { chosen.insert(s.id) }
                    } label: {
                        HStack(spacing: 6) {
                            MacCheck(done: s.ok && chosen.contains(s.id)).opacity(s.ok ? 1 : 0.25)
                            Image(systemName: Self.symbol(s)).font(.system(size: 11, weight: .semibold)).foregroundStyle(s.ok ? Ink.text2 : Ink.text3).frame(width: 16)
                            Text(CommandRules.describe(s, today: store.today))
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(s.ok ? Ink.text : Ink.text3).lineLimit(1)
                            Spacer(minLength: 6)
                        }
                        .frame(height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline()
                }
            }
        }
        .scrollIndicators(.never)
        let n = p.steps.filter { $0.ok && chosen.contains($0.id) }.count
        HStack {
            Text("적용해도 ⌘Z 로 한 번에 되돌릴 수 있어").font(.system(size: 11.5)).foregroundStyle(Ink.text3)
            Spacer()
            Button(n == 0 ? "바꿀 게 없어" : "\(n)가지 적용") {
                if store.apply(p.steps.filter { chosen.contains($0.id) }) > 0 { dismiss() }
            }
            .buttonStyle(MacFill(tone: .accent))
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(n == 0)
            .accessibilityIdentifier("cmd.apply")
        }
        .padding(.top, 10)
    }

    private static func symbol(_ s: CommandStep) -> String {
        guard s.ok else { return "questionmark" }
        switch s.kind { case .add: return "plus"; case .done: return "checkmark"; case .move: return "arrow.right"; case .delete: return "trash" }
    }

    private func run(_ q: String) {
        let q = q.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !q.isEmpty else { return }
        busy = true
        Task {
            // 물음이면 찾고, 시키는 말이면 계획을 세운다
            if CommandRules.looksLikeCommand(q) || (!CommandRules.isQuestion(q) && CommandRules.pieces(q).count > 1) {
                let p = await Brain.shared.plan(q, data: store.data, now: store.now)
                plan = p; answer = nil
                chosen = Set(p.doable.map(\.id))
            } else {
                let first = await Brain.shared.find(q, data: store.data, today: store.today)
                answer = first; plan = nil
                busy = false
                // 낱말로 찾은 답을 먼저 보이고, 뜻이 가까운 기록은 뒤에 이어 붙인다 (기다림 없음)
                widening = Brain.shared.isReady && first.hits.isEmpty && !first.query.words.isEmpty
                if widening, let more = await Brain.shared.findMore(q, answer: first, data: store.data, today: store.today), answer == first {
                    withAnimation(.easeOut(duration: 0.2)) { answer = more }
                }
                widening = false
            }
            busy = false
        }
    }

    private func open(_ h: FindHit) {
        guard let d = h.day else { return }
        store.selectedDay = d
        dismiss()
    }
}
