import SwiftUI

/// 작게 쪼개기 (Mac — 줄을 오른쪽 눌러 연다). 큰일 하나를 Apple Intelligence 가 서너 걸음으로 쓰고, 규칙이 마감 전 날들에 놓는다.
/// 걸음을 고치고 켜고 끈 뒤 ⌘↩ 로 한 번에 넣는다 (⌘Z 한 번). 큰일은 그대로 남는다.
struct MacBreakdown: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BreakdownDraft

    init(request: SplitRequest) { _draft = State(initialValue: BreakdownDraft(request)) }

    var body: some View {
        @Bindable var draft = draft
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("작게 쪼개기").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.text3)
                Spacer()
                KeyCap(text: "esc")
            }
            Text("‘\(draft.subject.isEmpty ? draft.request.title : draft.subject)’")
                .font(Typo.serif(22)).foregroundStyle(Ink.text).lineLimit(2)
                .padding(.top, 6)
                .accessibilityIdentifier("split.title")
            Text(deadline).font(.system(size: 12)).foregroundStyle(Ink.text2).padding(.top, 3)

            if draft.loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(Brain.shared.isReady ? "Apple Intelligence가 걸음을 나누는 중이야" : "걸음을 나누는 중이야")
                        .font(.system(size: 13)).foregroundStyle(Ink.text2)
                }
                .padding(.top, 22)
                Spacer(minLength: 0)
            } else if draft.blocked {
                Text("이건 걸음으로 나누지 않을게. 많이 힘들면 109(자살예방상담) · 1577-0199 로 전화해 줘. 24시간 받아.")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 8) {
                    Text("걸음").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.text3)
                    if draft.fromAI { AppleAIBadge(text: "Apple Intelligence가 나눔").fixedSize() }
                    Spacer()
                    if draft.paces.count > 1 {
                        Picker("", selection: $draft.pace) {
                            ForEach(draft.paces) { Text($0.name).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityIdentifier("split.pace")
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 6)
                VStack(spacing: 0) {
                    Hairline()
                    ForEach($draft.lines) { $line in
                        HStack(spacing: 6) {
                            Button { line.on.toggle() } label: { MacCheck(done: line.on) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(line.on ? "빼기" : "넣기")
                            TextField("", text: $line.text)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(line.on ? Ink.text : Ink.text3)
                                .accessibilityIdentifier("split.step")
                            Spacer(minLength: 8)
                            Text(draft.slot(line, store) ?? "뺌")
                                .font(Typo.num(size: 11.5, .semibold))
                                .foregroundStyle(line.on ? Ink.accent : Ink.text3)
                                .lineLimit(1)
                        }
                        .frame(height: 36)
                        Hairline()
                    }
                }
                Spacer(minLength: 10)
                HStack(alignment: .center) {
                    Text(footnote).font(.system(size: 11.5)).foregroundStyle(Ink.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(draft.count == 0 ? "넣을 걸음이 없어" : "걸음 \(draft.count)개 넣기") {
                        if draft.apply(store) > 0 { dismiss() }
                    }
                    .buttonStyle(MacFill(tone: .accent))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(draft.count == 0)
                    .accessibilityIdentifier("split.apply")
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 400, alignment: .top)
        .background(Ink.ground)
        .onExitCommand { dismiss() }
        .task { await draft.load(store) }
    }

    private var deadline: String {
        guard let due = draft.request.due else { return "날짜 없는 일 · 걸음만 날에 놓여" }
        return "\(Fmt.day(due, today: store.today)) 마감 · 큰일은 그 날에 그대로 남아"
    }

    private var footnote: String {
        (draft.fromAI ? "걸음은 이 Mac 의 Apple Intelligence 가 썼어. " : "") + draft.placeNote(store) + " ⌘Z 로 한 번에 되돌려."
    }
}
