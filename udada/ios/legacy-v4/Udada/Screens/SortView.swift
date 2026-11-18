import SwiftUI

/// 쏟아내기: 한 줄 = 고리 하나. 정리하기 키는 키보드 바로 위에 붙는다.
struct DumpView: View {
    @Environment(Flow.self) private var flow
    @FocusState private var typing: Bool
    static let example = "레포트 금요일까지 3장 시작도 안 함\n엄마한테 전화\n방 정리\n택배 반품 언제까지더라\n단톡 답장 안 했음\n다음 달 월세 오르면 어떡하지\n헬스 등록할까 말까"

    var body: some View {
        @Bindable var flow = flow
        let n = flow.lines.count
        VStack(spacing: 14) {
            TopBar(back: { flow.go(.home, forward: false) }, title: "쏟아내기")
            LCD(label: "막 써도 됨 · 한 줄에 하나", badge: "열린 고리 \(n)") {
                ZStack(alignment: .topLeading) {
                    if flow.text.isEmpty {
                        Text("할 일, 걱정, 생각난 거 전부.\n맞춤법·순서 상관없음.")
                            .font(.system(size: 17, design: .monospaced)).opacity(0.4).padding(.top, 8).padding(.leading, 5)
                    }
                    TextEditor(text: $flow.text)
                        .font(.system(size: 17, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($typing)
                        .accessibilityIdentifier("dump.text")
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { flow.text = Self.example } label: { KeyLabel(tag: "EX", title: "예시", big: 16) }
                    .buttonStyle(KeyStyle()).frame(maxWidth: 104)
                    .accessibilityIdentifier("dump.example")
                Button { typing = false; flow.startSort() } label: {
                    KeyLabel(tag: n == 0 ? "한 줄 이상 써 줘" : "\(n)개 → 한 장씩", title: "정리하기", big: 21)
                }
                .buttonStyle(KeyStyle(tone: .blue))
                .disabled(n == 0).opacity(n == 0 ? 0.5 : 1)
                .accessibilityIdentifier("dump.sort")
            }
            .frame(height: 80)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Palette.body)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { typing = true } }
    }
}

/// 한 장씩 정리: 카드 + 제안 + 네 칸. 버리기는 파쇄기처럼 찢어진다.
struct SortView: View {
    @Environment(Flow.self) private var flow
    @State private var pickingDate = false
    @State private var shredding: String?
    private let compact = UIScreen.main.bounds.height < 700

    var body: some View {
        let i = min(flow.index, max(0, flow.cards.count - 1))
        let card = flow.cards.isEmpty ? nil : flow.cards[i]
        VStack(spacing: 14) {
            TopBar(back: { flow.go(.dump, forward: false) }, title: "정리하기")
            if let card {
                LCD(label: "\(min(flow.index + 1, flow.cards.count)) / \(flow.cards.count)", badge: "한 장씩") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 3) {
                            ForEach(flow.cards.indices, id: \.self) { k in Rectangle().fill(Palette.seg.opacity(k < flow.index ? 1 : 0.15)).frame(height: 4) }
                        }
                        Spacer(minLength: 0)
                        ZStack(alignment: .leading) {
                            Text(card.text).font(Fonts.lcd(compact ? 23 : 27)).kerning(-0.5).lineLimit(3).minimumScaleFactor(0.7)
                                .opacity(shredding == nil ? 1 : 0)
                                .id(flow.index).transition(.push(from: .bottom))
                                .accessibilityIdentifier("sort.card")
                            if let s = shredding { Shred(text: s, compact: compact) }
                        }
                        Spacer(minLength: 0)
                        if pickingDate {
                            Text("언제 할래? 그때 알려 줄게.").font(Fonts.lcd(13))
                            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                                GridRow { whenKey(.tonight); whenKey(.tomorrow) }
                                GridRow { whenKey(.weekend); whenKey(.nextWeek) }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("제안").font(Fonts.lcd(12)).opacity(0.7)
                                    Text(" \(card.suggestion.name) ").font(Fonts.lcd(13)).foregroundStyle(Palette.lcd).background(Palette.seg)
                                }
                                Text(card.why).font(Fonts.ui(13, .semibold)).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(Palette.seg, lineWidth: 1))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: flow.index)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow { binKey(.now, card); binKey(.date, card) }
                    GridRow { binKey(.worry, card); binKey(.drop, card) }
                }
                .frame(height: compact ? 150 : 172)
                Button { put(card.suggestion, card.when, card.text) } label: {
                    HStack { Text("제안대로 딸깍").font(Fonts.ui(18, .heavy)); Spacer(); Text(card.suggestion.name).font(Fonts.ui(12, .heavy)).opacity(0.75) }
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(KeyStyle(tone: .blue))
                .frame(height: 64)
                .accessibilityIdentifier("sort.suggest")
            }
        }
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private func binKey(_ b: Bin, _ c: Flow.Card) -> some View {
        let n = flow.cards.prefix(flow.index).filter { $0.bin == b }.count
        return Button {
            if b == .date && !pickingDate { withAnimation { pickingDate = true } } else { put(b, b == .date ? c.when : nil, c.text) }
        } label: {
            VStack(alignment: .leading) {
                HStack { Text(b.tag).font(Fonts.ui(10, .heavy)).opacity(0.6); Spacer(); Led(on: (pickingDate ? .date : c.suggestion) == b) }
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline) {
                    Image(systemName: b.symbol).font(.system(size: 14, weight: .bold)).opacity(0.6)
                    Text(b.name).font(Fonts.ui(17, .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\(n)").font(Fonts.mono(13, .heavy)).opacity(0.6)
                }
            }
        }
        .buttonStyle(KeyStyle(radius: 12, depth: 5))
        .accessibilityIdentifier("bin.\(b.rawValue)")
    }

    private func whenKey(_ w: When) -> some View {
        Button { put(.date, w, "") } label: { Text(w.label).font(Fonts.ui(14, .heavy)).frame(maxWidth: .infinity, maxHeight: .infinity) }
            .buttonStyle(KeyStyle(tone: .lit, radius: 10, depth: 3))
            .frame(height: compact ? 44 : 50)
            .accessibilityIdentifier("when.\(w.rawValue)")
    }

    private func put(_ b: Bin, _ w: When?, _ text: String) {
        guard shredding == nil else { return }
        pickingDate = false
        if b == .drop {
            shredding = text
            Feel.shred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                shredding = nil
                withAnimation { flow.put(.drop) }
            }
        } else {
            withAnimation { flow.put(b, when: w) }
        }
    }
}

/// 버린 카드가 세로로 찢어져 떨어진다 (파쇄기)
struct Shred: View {
    var text: String
    var compact: Bool
    @State private var fall = false
    private let strips = 10
    var body: some View {
        GeometryReader { g in
            let w = g.size.width / CGFloat(strips)
            ZStack(alignment: .topLeading) {
                ForEach(0..<strips, id: \.self) { k in
                    Text(text).font(Fonts.lcd(compact ? 23 : 27)).kerning(-0.5).lineLimit(3)
                        .frame(width: g.size.width, alignment: .leading)
                        .mask(Rectangle().frame(width: w - 1).offset(x: CGFloat(k) * w - g.size.width / 2 + w / 2))
                        .offset(y: fall ? 140 + CGFloat((k * 37) % 60) : 0)
                        .rotationEffect(.degrees(fall ? Double((k % 3) - 1) * 9 : 0))
                        .opacity(fall ? 0 : 1)
                        .animation(.easeIn(duration: 0.6).delay(Double(k) * 0.015), value: fall)
                }
            }
        }
        .frame(height: 100)
        .onAppear { fall = true }
        .allowsHitTesting(false)
    }
}
