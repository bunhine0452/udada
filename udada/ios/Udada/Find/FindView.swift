import SwiftUI

/// 말로 하기 (iPhone). 물으면 찾고("다음 주에 병원 언제야?"), 시키면 바꾼다("치과 내일로 미루고 보고서는 끝냈어").
/// Apple Intelligence 는 말을 읽기만 하고, 찾기·바꾸기는 규칙이 내 기록에 대고 한다. 바꾸기는 미리 보여 주고 눌러야 적용된다.
struct FindView: View {
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
            HStack {
                Text("말로 하기").font(Typo.serif(28, relativeTo: .title)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("find.close")
            }
            .padding(.top, 8)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(.body, weight: .semibold)).foregroundStyle(Ink.text3)
                TextField("", text: $text, prompt: Text("물어보거나 시켜 봐").foregroundStyle(Ink.text3))
                    .font(.system(.title3, weight: .medium))
                    .foregroundStyle(Ink.text)
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit { run(text) }
                    .accessibilityIdentifier("find.field")
                if busy { ProgressView() }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusButton, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let plan {
                        planView(plan)
                    } else if let a = answer {
                        result(a)
                    } else {
                        Text("이렇게 물어봐").font(Typo.caption).foregroundStyle(Ink.text3).padding(.top, 6)
                        ForEach(Self.examples, id: \.self) { ex in
                            Button { text = ex; run(ex) } label: {
                                Text(ex).font(Typo.row).foregroundStyle(Ink.text)
                                    .frame(maxWidth: .infinity, minHeight: Metric.tap, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            Hairline()
                        }
                        Text(Brain.shared.isReady ? "말은 이 iPhone 의 Apple Intelligence 가 읽고, 찾기와 바꾸기는 내 기록에 대고만 해. 바꾸기 전에 먼저 보여 줘."
                                                 : "찾기와 바꾸기는 내 기록에 대고만 해. 바꾸기 전에 먼저 보여 줘.")
                            .font(Typo.meta).foregroundStyle(Ink.text3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, Metric.gutter)
        .background(Ink.ground.ignoresSafeArea())
        .onAppear {
            // 딥링크·Siri 가 넘긴 물음이 있으면 바로 찾는다
            let q = store.pendingAddText
            if !q.isEmpty { store.pendingAddText = ""; text = q; run(q) } else { focused = true }
        }
    }

    @ViewBuilder private func result(_ a: FindAnswer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(widening && a.hits.isEmpty ? FindRules.searching(a) : a.line)
                .font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("find.answer")
            if a.hits.contains(where: \.byMeaning) { AIBadge(text: "Apple Intelligence가 뜻으로 찾음") }
            else if widening { ThinkingLine(text: "뜻이 가까운 것도 찾는 중…") }
            else if a.query.fromAI { AIBadge() }
        }
        if a.hits.isEmpty, !widening {
            Text("낱말을 줄이거나 때를 바꿔서 다시 물어봐.").font(Typo.meta).foregroundStyle(Ink.text2)
        }
        VStack(spacing: 0) {
            ForEach(a.hits) { h in
                Button { open(h) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: h.done ? "checkmark.square.fill" : (h.time != nil ? "clock" : "square"))
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(h.done ? Ink.text3 : Ink.text2)
                        Text(h.title).font(Typo.row).foregroundStyle(h.done ? Ink.text3 : Ink.text)
                            .strikethrough(h.done, color: Ink.text3).lineLimit(2).multilineTextAlignment(.leading)
                        if h.byMeaning {
                            Text("뜻").font(.system(.caption2, weight: .bold)).foregroundStyle(Ink.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Ink.accentSoft))
                                .accessibilityLabel("뜻으로 찾음")
                        }
                        Spacer(minLength: 8)
                        Text(FindRules.when(h, today: store.today).trimmingCharacters(in: .whitespaces))
                            .font(Typo.num(.footnote, .semibold)).foregroundStyle(Ink.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metric.rowMin, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("find.hit.\(h.title)")
                Hairline()
            }
        }
    }

    /// 바꿀 것 미리보기: 줄마다 켜고 끌 수 있고, 눌러야 적용된다. 못 찾은 일은 흐리게 — 아무것도 안 한다.
    @ViewBuilder private func planView(_ p: CommandPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이렇게 할게").font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                .accessibilityIdentifier("cmd.title")
            if p.fromAI { AIBadge() }
        }
        VStack(spacing: 0) {
            ForEach(p.steps) { s in
                Button {
                    guard s.ok else { return }
                    Haptic.tick()
                    if chosen.contains(s.id) { chosen.remove(s.id) } else { chosen.insert(s.id) }
                } label: {
                    HStack(spacing: 4) {
                        CheckBox(done: s.ok && chosen.contains(s.id))
                            .opacity(s.ok ? 1 : 0.25)
                        Text(CommandRules.describe(s, today: store.today))
                            .font(Typo.row).foregroundStyle(s.ok ? Ink.text : Ink.text3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: Metric.rowMin)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("cmd.step.\(s.kind.rawValue)")
                Hairline().padding(.leading, 52)
            }
        }
        .padding(.leading, -12)
        let n = p.steps.filter { $0.ok && chosen.contains($0.id) }.count
        Button(n == 0 ? "바꿀 게 없어" : "\(n)가지 적용") {
            let done = store.apply(p.steps.filter { chosen.contains($0.id) })
            if done > 0 { Haptic.success(); dismiss() }
        }
        .buttonStyle(FillButton(tone: .accent))
        .disabled(n == 0)
        .padding(.top, 8)
        .accessibilityIdentifier("cmd.apply")
    }

    private func run(_ q: String) {
        let q = q.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !q.isEmpty else { return }
        // 한 주를 풀어 달라는 말은 그 화면으로 넘긴다
        if ReplanRules.looksLikeReplan(q) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { store.replan = ReplanRequest(text: q) }
            return
        }
        busy = true
        Haptic.tick()
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

    /// 그날의 한 장으로 간다
    private func open(_ h: FindHit) {
        guard let d = h.day else { return }
        store.tab = .today
        store.selectedDay = d
        dismiss()
    }
}
