import SwiftUI

/// 비우기 끝의 한 장: 지금 할 단 하나 · 첫 동작 · 칸별 개수.
/// 지금 칸의 첫 장은 오늘의 하나로 꽂히고, 나머지 지금 칸은 지금 띠에 들어간다.
struct DumpFinishCard: View {
    var oneThing: String?
    var firstStep: String?
    var stepFromAI: Bool
    var stepLoading: Bool
    var counts: [DumpBin: Int]
    var minute: Int
    var partName: String

    var body: some View {
        let extra = max(0, (counts[.now] ?? 0) - 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("지금 할 단 하나").font(.system(.caption, weight: .semibold))
                    .foregroundStyle(oneThing == nil ? Ink.text3 : Ink.accent)
                Spacer()
                Text(Fmt.hm(minute)).font(Typo.num(.caption, .semibold)).foregroundStyle(Ink.text3)
            }
            Text(oneThing ?? "지금 할 건 없어.")
                .font(.system(.title2, weight: .bold)).foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("finish.one")
            if oneThing != nil { stepRow }
            Text(oneThing == nil ? "전부 자리를 찾았어. 창밖 한 번 보고 와."
                 : extra > 0 ? "2분만. 안 끝나도 돼. 오늘의 하나로 꽂아 뒀고, 나머지 \(extra)개는 \(partName) 띠에 넣었어."
                 : "2분만. 안 끝나도 돼. 오늘의 하나로 꽂아 뒀어.")
                .font(.system(.subheadline)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Ink.rule)
                .frame(height: 1).padding(.vertical, 4)
                .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(DumpBin.allCases, id: \.self) { b in cell(b).frame(maxWidth: .infinity, alignment: .leading) }
                }
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow { cell(.now); cell(.date) }
                    GridRow { cell(.worry); cell(.drop) }
                }
            }
        }
        .card(padding: 18)
    }

    @ViewBuilder private var stepRow: some View {
        if let s = firstStep {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("첫 동작").font(.system(.caption, weight: .semibold)).foregroundStyle(Ink.text3)
                Text(s).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if stepFromAI { AIBadge() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("finish.step")
        } else if stepLoading {
            ThinkingLine(text: "첫 동작 찾는 중")
        }
    }

    private func cell(_ b: DumpBin) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(counts[b] ?? 0)").font(Typo.num(.title3)).foregroundStyle(Ink.text)
            Text(DumpFlow.binName(b)).font(.system(.caption2)).foregroundStyle(Ink.text2).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
