import SwiftUI

/// 정리함: 지금 · 날짜(때별) · 걱정 시간. 끝낸 건 ✓.
struct DrawerView: View {
    @Environment(Flow.self) private var flow
    @State private var items = Store.shared.open

    var body: some View {
        VStack(spacing: 14) {
            TopBar(back: { flow.go(.home, forward: false) }, title: "정리함")
            LCD(label: "머리 대신 들고 있는 것", badge: "\(items.count)") {
                if items.isEmpty {
                    Text("비어 있음.\n머리가 시끄러우면 쏟아내 봐.").font(Fonts.lcd(15)).opacity(0.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(groups, id: \.0) { title, list in
                                Text(title).font(Fonts.lcd(12)).opacity(0.7).padding(.top, 12).padding(.bottom, 4)
                                ForEach(list) { it in row(it) }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            Text("여기 있는 건 머리에 안 들고 있어도 돼. 때가 되면 알려 줄게.")
                .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.ink2).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18).padding(.bottom, 8)
        .accessibilityIdentifier("drawer.list")
    }

    private func row(_ it: Item) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(it.text).font(Fonts.ui(15, .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if let due = it.due { Text(due.formatted(.dateTime.weekday(.abbreviated).hour().minute())).font(Fonts.mono(11, .bold)).opacity(0.6) }
                Button {
                    Feel.detent()
                    Store.shared.markDone(it.id)
                    withAnimation { items.removeAll { $0.id == it.id } }
                } label: { Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).frame(width: 44, height: 44) }
                    .overlay(Rectangle().stroke(Palette.seg, lineWidth: 1))
                    .foregroundStyle(Palette.seg)
                    .accessibilityLabel("끝: \(it.text)")
            }
            .padding(.vertical, 4)
            Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1).opacity(0.3)
        }
    }

    private var groups: [(String, [Item])] {
        var out: [(String, [Item])] = []
        let now = items.filter { $0.bin == .now }
        if !now.isEmpty { out.append(("지금 · 2분이면 끝", now)) }
        for w in When.allCases {
            let l = items.filter { $0.bin == .date && $0.when == w }.sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
            if !l.isEmpty { out.append((w.label, l)) }
        }
        let worry = items.filter { $0.bin == .worry }
        if !worry.isEmpty { out.append(("걱정 시간 · 매일 21:30", worry)) }
        return out
    }
}
