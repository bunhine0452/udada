import SwiftUI

/// 나중에 함: 날을 안 정한 일. 10일 넘게 있던 것만 "아직 할 거야?"를 묻는다 (버림은 10일째에 굳는다 — Halder 2026).
struct LaterSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let items = store.data.laterItems
                    Text("날을 안 정한 일이 여기 모여. 오늘로 꺼내거나, 오래된 건 놓아줘도 돼.")
                        .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 12)
                    if items.isEmpty {
                        Hint(text: "지금은 비어 있어. 넣기 줄에서 ‘나중에’를 고르면 여기로 와.")
                    }
                    ForEach(items) { it in
                        LaterRow(item: it, age: DayLogic.age(it, today: store.today), pull: { pull(it) }) {
                            store.change(undo: "놓아줬어") { $0.remove(.item(it.id)) }
                            Haptic.tap()
                        }
                        Hairline()
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 4)
                .padding(.bottom, 64)
                .animation(.snappy, value: store.data.laterItems.map(\.id))
            }
            .background(Ink.ground)
            .navigationTitle("나중에")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }.fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) { ToastLayer().padding(.bottom, 12) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Ink.ground)
    }

    private func pull(_ it: Item) {
        let part = store.settings.parts.part(at: minuteOfDay(store.now))
        let today = store.today, now = store.now
        store.change(undo: "오늘 \(part.name)에 넣었어") { data in
            data.move(.item(it.id), to: today, part: part)
            data.update(it.id) { $0.created = now }
        }
        Haptic.tap()
    }
}

/// 나중에 한 줄: 이름 · 며칠째 · [오늘로] [지우기]. 좁거나 글자가 크면 버튼이 아래 줄로 내려간다.
private struct LaterRow: View {
    let item: Item
    let age: Int
    var pull: () -> Void
    var drop: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                label.frame(maxWidth: .infinity, alignment: .leading)
                buttons
            }
            VStack(alignment: .leading, spacing: 10) {
                label
                HStack(spacing: 8) { buttons }
            }
        }
        .padding(.vertical, 10)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(Typo.row).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(age >= 10 ? "\(age)일째. 아직 할 거야?" : age == 0 ? "오늘 넣음" : "\(age)일 전에 넣음")
                .font(Typo.meta)
                .foregroundStyle(age >= 10 ? Ink.text : Ink.text2)
                .fontWeight(age >= 10 ? .semibold : .regular)
        }
        .frame(minWidth: 120, alignment: .leading)
    }

    @ViewBuilder private var buttons: some View {
        Button("오늘로", action: pull)
            .buttonStyle(FillButton(tone: .ink, height: 44, full: false))
            .fixedSize()
            .accessibilityLabel("\(item.title) 오늘로")
            .accessibilityIdentifier("later.pull.\(item.title)")
        Button(action: drop) {
            // 두 줄의 [오늘로]가 같은 자리에 서도록 '놓아주기'·'지우기' 폭을 맞춘다
            Text(age >= 10 ? "놓아주기" : "지우기").frame(minWidth: 64)
        }
            .buttonStyle(FillButton(tone: .quiet, height: 44, full: false))
            .fixedSize()
            .accessibilityLabel("\(item.title) \(age >= 10 ? "놓아주기" : "지우기")")
            .accessibilityIdentifier("later.drop.\(item.title)")
    }
}
