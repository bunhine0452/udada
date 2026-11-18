import SwiftUI

/// 작게 쪼개기 (iPhone). 큰일 하나를 Apple Intelligence 가 서너 걸음으로 쓰고, 규칙이 마감 전 날들에 놓는다.
/// 바로 넣지 않는다 — 걸음을 고치고 켜고 끈 뒤 눌러야 한 번에 들어간다. 큰일은 그대로 남는다.
struct BreakdownSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BreakdownDraft
    var onAdded: () -> Void = {}

    init(request: SplitRequest, onAdded: @escaping () -> Void = {}) {
        _draft = State(initialValue: BreakdownDraft(request))
        self.onAdded = onAdded
    }

    var body: some View {
        @Bindable var draft = draft
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("작게 쪼개기").font(Typo.serif(28, relativeTo: .title)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: Metric.tap, minHeight: Metric.tap)
                    .accessibilityIdentifier("split.close")
            }
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("‘\(draft.subject.isEmpty ? draft.request.title : draft.subject)’")
                            .font(Typo.serif(20, relativeTo: .title3)).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(deadline).font(Typo.meta).foregroundStyle(Ink.text2)
                    }

                    if draft.loading {
                        ThinkingLine(text: Brain.shared.isReady ? "Apple Intelligence가 걸음을 나누는 중이야" : "걸음을 나누는 중이야")
                    } else if draft.blocked {
                        Text("이건 걸음으로 나누지 않을게. 많이 힘들면 109(자살예방상담) · 1577-0199 로 전화해 줘. 24시간 받아.")
                            .font(Typo.row).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        steps
                        if draft.paces.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("놓는 법").font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text2)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(draft.paces) { p in
                                            Chip(title: p.name, on: draft.pace == p, id: "split.pace.\(p.rawValue)") {
                                                withAnimation(.snappy) { draft.pace = p }
                                            }
                                        }
                                    }
                                }
                                .scrollClipDisabled()
                            }
                        }
                        Text(footnote).font(Typo.meta).foregroundStyle(Ink.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            if !draft.loading && !draft.blocked {
                Button(draft.count == 0 ? "넣을 걸음이 없어" : "걸음 \(draft.count)개 넣기") {
                    if draft.apply(store) > 0 { Haptic.success(); dismiss(); onAdded() }
                }
                .buttonStyle(FillButton(tone: .accent))
                .disabled(draft.count == 0)
                .padding(.bottom, 12)
                .accessibilityIdentifier("split.apply")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .background(Ink.ground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Ink.ground)
        .task { await draft.load(store) }
    }

    /// 걸음 줄: 네모로 켜고 끄고, 글은 바로 고칠 수 있다. 오른쪽에 놓일 자리.
    @ViewBuilder private var steps: some View {
        @Bindable var draft = draft
        VStack(alignment: .leading, spacing: 8) {
            if draft.fromAI { AIBadge(text: "Apple Intelligence가 나눔") }
            VStack(spacing: 0) {
                ForEach($draft.lines) { $line in
                    HStack(spacing: 4) {
                        Button {
                            Haptic.tick()
                            withAnimation(.snappy) { line.on.toggle() }
                        } label: { CheckBox(done: line.on) }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel(line.on ? "빼기" : "넣기")
                        TextField("걸음", text: $line.text, axis: .vertical)
                            .font(Typo.row)
                            .foregroundStyle(line.on ? Ink.text : Ink.text3)
                            .lineLimit(1...2)
                            .writingToolsBehavior(.disabled)
                            .accessibilityIdentifier("split.step")
                        Spacer(minLength: 8)
                        Text(draft.slot(line, store) ?? "뺌")
                            .font(Typo.num(.footnote, .semibold))
                            .foregroundStyle(line.on ? Ink.accent : Ink.text3)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                            .accessibilityIdentifier("split.slot")
                    }
                    .frame(minHeight: Metric.rowMin)
                    Hairline().padding(.leading, 52)
                }
            }
            .padding(.leading, -12)
        }
    }

    private var deadline: String {
        guard let due = draft.request.due else { return "날짜 없는 일 · 걸음만 날에 놓여" }
        return "\(Fmt.day(due, today: store.today)) 마감 · 큰일은 그 날에 그대로 남아"
    }

    private var footnote: String {
        let who = draft.fromAI ? "걸음은 이 iPhone 의 Apple Intelligence 가 썼어. 기기 밖으로 안 나가. " : ""
        return who + draft.placeNote(store) + " 걸음 글은 눌러서 고칠 수 있어."
    }
}
