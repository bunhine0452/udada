import SwiftUI

// 사용법 장면 1~5: 적기 · 세 칸 · 끝내고 미루기 · 쏟아내기 · 말로 시키기.
// 좌표는 320×400 무대 기준, 시각은 초.

// MARK: - 1. 적기

struct AddScene: View {
    var b: Beat
    static let length = 10.5
    private static let first = "3시 치과"
    private static let second = "보고서 30분"

    var body: some View {
        let fly1 = b.land(4.9, 0.7)   // 약속이 칸으로
        let fly2 = b.land(8.5, 0.65)  // 할 일이 칸으로
        let text = b.on(8.4) ? "" : b.on(6.2) ? typed(Self.second, b, from: 6.2, per: 0.16) : b.on(4.85) ? "" : typed(Self.first, b, from: 1.3, per: 0.3)

        GPaper(live: 1).at(14, 14, w: 292, h: 196)
        GBandHead(name: "낮", range: "12–18", live: 1).at(28, 24, w: 264, h: 28)
        Rectangle().fill(Ink.accent).at(28, 56, w: 264, h: 2)
        GTodo(text: "메일 답장").at(28, 64, w: 264, h: 34)

        // 읽은 것 미리보기
        preview(title: "치과", rest: "오늘 15:00 약속").show(b.p(2.9, 0.35) * (1 - b.lin(4.85, 0.2))).at(16, 312, w: 288, h: 24)
        preview(title: "보고서", rest: "오늘 낮 · 30분").show(b.p(7.7, 0.3) * (1 - b.lin(8.4, 0.2))).at(16, 312, w: 288, h: 24)

        GBar(text: text, caret: b.on(1.05), pressed: max(b.press(4.75), b.press(8.35))).at(0, 344)

        // 넣기를 누르면 적은 줄이 칸의 제자리로 날아가 앉는다
        if b.on(4.9) {
            GBlock(when: "15:00", title: "치과")
                .at(mix(56, 28, fly1), mix(354, 142, fly1), w: mix(190, 264, fly1), h: mix(36, 38, fly1))
                .opacity(b.lin(4.9, 0.12))
        }
        if b.on(8.5) {
            GTodo(text: "보고서", tag: "30분", plate: fly2 < 1)
                .at(mix(56, 28, fly2), mix(354, 102, fly2), w: mix(190, 264, fly2), h: 34)
                .opacity(b.lin(8.5, 0.12))
        }

        GuideFinger(beat: b, keys: [(0.3, CGPoint(x: 210, y: 290)), (0.9, CGPoint(x: 150, y: 372)), (4.0, CGPoint(x: 150, y: 372)),
                                    (4.6, CGPoint(x: 281, y: 372)), (8.6, CGPoint(x: 281, y: 372))], taps: [1.0, 4.75, 8.35])
    }

    private func preview(title: String, rest: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Ink.text)
            Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Ink.text3)
            Text(rest).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.text2)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 2. 세 칸

struct BandsScene: View {
    var b: Beat
    static let length = 10.0

    var body: some View {
        let live = b.p(1.9, 0.5)
        let focus = b.p(5.9, 0.4)

        // 하루의 자: 눈금이 아침을 지나 낮으로 온다
        ForEach(0..<3, id: \.self) { i in
            let x = CGFloat(14 + i * 100)
            VStack(alignment: .leading, spacing: 5) {
                Text(["아침", "낮", "저녁"][i]).font(Typo.serif(13))
                    .foregroundStyle(i == 1 ? Ink.text.opacity(1 - live) : (i == 0 ? Ink.text3 : Ink.text))
                    .overlay(alignment: .leading) { if i == 1 { Text("낮").font(Typo.serif(13)).foregroundStyle(Ink.accent).opacity(live) } }
                Capsule().fill(Ink.rule).frame(height: 4)
            }
            .show(b.p(0.15 + Double(i) * 0.12, 0.4))
            .at(x, 12, w: 92, h: 34, align: .topLeading)
        }
        Capsule().fill(Ink.text).at(mix(18, 150, b.p(0.7, 1.2)), 31, w: 2.5, h: 12).opacity(b.lin(0.5, 0.2))

        // 아침: 지나간 칸은 한 줄로 접힌다
        HStack(spacing: 8) {
            Text("아침").font(Typo.serif(15)).foregroundStyle(Ink.text2)
            Text("지나감 · 끝낸 것 2").font(.system(size: 11)).foregroundStyle(Ink.text3)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.fill.opacity(0.6)))
        .show(b.p(0.3, 0.45)).at(14, 58, w: 292, h: 36)

        // 낮: 지금 칸
        Group {
            GPaper(live: live).at(14, 102, w: 292, h: 200)
            GBandHead(name: "낮", range: "12–18", live: live).at(28, 112, w: 264, h: 28)
            Rectangle().fill(Ink.rule).overlay(Rectangle().fill(Ink.accent).opacity(live)).at(28, 144, w: 264, h: 1 + live)
            GTodo(text: "메일 답장").at(28, 226, w: 264, h: 32)
            GBlock(when: "15:00", title: "치과").at(28, 260, w: 264, h: 32)
        }
        .show(b.p(0.5, 0.45))

        // 지금 카드: 남은 시간 → 들어갈 일 → (시작을 누르면) 집중 시계
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.accent)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("14:20").font(Typo.num(size: 17, .bold))
                    Text("치과까지 40분").font(.system(size: 13.5, weight: .bold))
                }
                HStack {
                    Text("‘메일 답장’ 15분, 지금 들어가.").font(.system(size: 11.5, weight: .medium))
                    Spacer(minLength: 4)
                    Text("시작").font(.system(size: 11.5, weight: .bold)).foregroundStyle(Ink.accent)
                        .frame(width: 44, height: 28)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Ink.accentText))
                        .scaleEffect(1 - 0.1 * b.press(5.7))
                }
                .opacity(b.p(3.9, 0.4))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .opacity(1 - focus)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("집중").font(.system(size: 10.5, weight: .bold)).opacity(0.8)
                    Text("메일 답장").font(.system(size: 14, weight: .bold))
                }
                Spacer()
                Text(clock).font(Typo.num(size: 26, .bold))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .opacity(focus)
        }
        .foregroundStyle(Ink.accentText)
        .scaleEffect(0.96 + 0.04 * b.p(2.9, 0.4))
        .opacity(b.p(2.9, 0.4))
        .at(28, 152, w: 264, h: 68, align: .topLeading)

        // 저녁
        Group {
            GPaper().at(14, 310, w: 292, h: 78)
            GBandHead(name: "저녁", range: "18–24").at(28, 318, w: 264, h: 26)
            GTodo(text: "빨래 개기").at(28, 348, w: 264, h: 30)
        }
        .show(b.p(0.7, 0.45))

        GuideFinger(beat: b, keys: [(4.8, CGPoint(x: 210, y: 340)), (5.5, CGPoint(x: 268, y: 198)), (6.4, CGPoint(x: 268, y: 198))], taps: [5.7])
    }

    /// 시작을 누른 뒤로 실제로 줄어드는 시계
    private var clock: String {
        let left = max(0, 15 * 60 - Int(max(0, b.t - 5.9)))
        return String(format: "%d:%02d", left / 60, left % 60)
    }
}

// MARK: - 3. 끝내고 미루기

struct DoneScene: View {
    var b: Beat
    static let length = 10.0

    var body: some View {
        let back = b.p(6.0, 0.45)                 // 되돌리기
        let drag = b.p(2.9, 0.9) - back           // 왼쪽으로 끄는 만큼
        let gone = b.land(4.0, 0.35) - back       // 놓으면 빠져나간다
        let up = b.p(4.2, 0.4) - back             // 아랫줄이 올라온다

        GPaper(live: 1).at(14, 14, w: 292, h: 190)
        GBandHead(name: "낮", range: "12–18", live: 1).at(28, 24, w: 264, h: 28)
        Rectangle().fill(Ink.accent).at(28, 56, w: 264, h: 2)

        GTodo(text: "메일 답장", check: b.p(1.3, 0.4)).at(28, 64, w: 264, h: 38)

        // 밀린 줄 뒤에서 '내일'이 드러난다. 줄은 칸 밖으로 삐져나오지 않는다 (칸 너비로 자른다)
        ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                Spacer()
                Text("내일").font(.system(size: 12, weight: .bold))
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Ink.blockText)
            .padding(.trailing, 12)
            .frame(width: 264, height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Ink.block))
            .opacity(min(1, drag * 3) * (1 - gone))
            .offset(y: 3)
            GTodo(text: "보고서 초안")
                .frame(width: 264, height: 38)
                .background(Ink.sheet)
                .opacity(1 - gone)
                .offset(x: -104 * drag - 180 * gone)
        }
        .frame(width: 264, height: 38, alignment: .topLeading)
        .clipped()
        .offset(x: 28, y: 102)

        GTodo(text: "택배 보내기").at(28, mix(140, 102, up), w: 264, h: 38)

        GToast(text: "내일 아침으로 옮겼어", pressed: b.press(5.8))
            .show(b.p(4.3, 0.35) * (1 - b.lin(6.1, 0.3)), rise: 14)
            .at(20, 300, w: 280, h: 42)

        GuideFinger(beat: b, keys: [(0.4, CGPoint(x: 170, y: 290)), (1.1, CGPoint(x: 36, y: 83)), (2.0, CGPoint(x: 36, y: 83)),
                                    (2.8, CGPoint(x: 250, y: 121)), (3.8, CGPoint(x: 146, y: 121)), (4.6, CGPoint(x: 146, y: 121)),
                                    (5.6, CGPoint(x: 270, y: 321)), (6.5, CGPoint(x: 270, y: 321))],
                    taps: [1.3, 5.8], holds: [2.8...3.95])
    }
}

// MARK: - 4. 쏟아내기

struct DumpScene: View {
    var b: Beat
    static let length = 11.5
    private static let said = ["엄마한테 전화해야 되고", "보고서도 써야 되는데", "월세 오르면 어떡하지"]
    private static let cards = ["엄마한테 전화하기", "보고서 쓰기", "월세 오르면 어떡하지"]
    private static let tags = ["지금", "내일 아침", "걱정 상자"]
    private static let short = ["엄마 전화", "보고서", "월세 걱정"]
    private static let bins = ["오늘", "내일", "걱정 상자"]

    var body: some View {
        let heard = b.lin(0.5, 2.6)
        let all = Self.said.joined(separator: " ")
        let shownCount = Int(Double(all.count) * heard)

        // 듣는 중 → 나누는 중 → 나눴어
        HStack(spacing: 6) {
            if b.on(3.3) {
                Image(systemName: "apple.intelligence").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.accent)
                Text(b.on(6.9) ? "Apple Intelligence가 3개로 나눴어" : "Apple Intelligence가 나누는 중").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Ink.accent)
            } else {
                HStack(spacing: 2.5) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(Ink.text).frame(width: 2.5, height: 5 + 9 * abs(sin(b.t * 7 + Double(i) * 1.3)) * (b.on(0.4) ? 1 : 0.2))
                    }
                }
                .frame(height: 16)
                Text("듣는 중").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Ink.text2)
            }
            Spacer()
        }
        .at(16, 12, w: 288, h: 20)

        // 받아쓴 말: 세 덩어리가 차례로 끊긴다
        segments(shown: shownCount)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.fill))
            .at(14, 38, w: 292, h: 62, align: .topLeading)

        // 칸 셋
        ForEach(0..<3, id: \.self) { i in
            let lit = b.land(8.5 + Double(i) * 0.18, 0.6)
            VStack(spacing: 5) {
                Text(Self.bins[i]).font(.system(size: 11, weight: .bold)).foregroundStyle(lit > 0.9 ? Ink.accent : Ink.text3)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(lit > 0.9 ? Ink.accent.opacity(0.7) : Ink.rule, style: StrokeStyle(lineWidth: 1, dash: lit > 0.9 ? [] : [4, 3]))
            }
            .show(b.p(6.9, 0.4))
            .at(CGFloat(14 + i * 100), 308, w: 92, h: 78, align: .top)
        }

        // 모두 넣기
        Text("3개 넣기").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Ink.accentText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.accent))
            .scaleEffect(1 - 0.05 * b.press(8.3))
            .show(b.p(7.0, 0.35) * (1 - b.lin(8.5, 0.25)))
            .at(14, 258, w: 292, h: 34)

        // 카드 세 장: 말에서 떨어져 나오고 → 꼬리표가 붙고 → 칸으로 날아간다
        ForEach(0..<3, id: \.self) { i in
            let born = b.land(4.3 + Double(i) * 0.35, 0.5)
            let fly = b.land(8.5 + Double(i) * 0.18, 0.6)
            let y0 = CGFloat(110 + i * 46)
            // 날아가는 도중에 긴 카드를 짧은 카드로 바꾼다. 둘을 겹쳐 두면 안 보이는 긴 카드의 폭이 짧은 카드를 칸 밖으로 밀어낸다.
            Group {
                if b.on(8.65 + Double(i) * 0.18) {
                    GTodo(text: Self.short[i], plate: true, size: 11)
                } else {
                    GTodo(text: Self.cards[i], tag: Self.tags[i], tagPop: b.pop(5.9 + Double(i) * 0.3), plate: true)
                }
            }
            .frame(width: mix(292, 84, fly), height: mix(38, 30, fly))
            .clipped()
            .opacity(born)
            .offset(x: mix(14, CGFloat(18 + i * 100), fly), y: mix(mix(y0 - 22, y0, born), 343, fly))
        }

        GuideFinger(beat: b, keys: [(7.5, CGPoint(x: 220, y: 340)), (8.1, CGPoint(x: 160, y: 276)), (8.7, CGPoint(x: 160, y: 276))], taps: [8.3])
    }

    /// 받아쓴 글. 끊긴 덩어리는 먹색으로 진해지고 코발트 밑줄이 붙는다.
    private func segments(shown: Int) -> Text {
        var out = Text("")
        var used = 0
        for (i, s) in Self.said.enumerated() {
            let take = max(0, min(s.count, shown - used))
            used += s.count + 1
            guard take > 0 else { break }
            let cut = b.on(3.3 + Double(i) * 0.3)
            var piece = Text(String(s.prefix(take))).foregroundColor(cut ? Ink.text : Ink.text2)
            if cut { piece = piece.underline(true, color: Ink.accent).fontWeight(.semibold) }
            out = out + piece + Text(" ")
        }
        return out.font(.system(size: 13))
    }
}

// MARK: - 5. 말로 시키기

struct CommandScene: View {
    var b: Beat
    static let length = 10.5
    private static let line = "치과 내일로 미루고 보고서는 끝냈어"

    var body: some View {
        let sheet = b.land(3.6, 0.45) * (1 - b.p(5.5, 0.3))
        let move = b.land(5.9, 0.7)
        let text = b.on(3.5) ? "" : typed(Self.line, b, from: 0.6, per: 0.14)

        column("오늘").at(14, 12, w: 142, h: 30)
        column("내일").at(164, 12, w: 142, h: 30)
        GTodo(text: "보고서 초안", check: b.p(6.6, 0.4), plate: true, size: 12).at(14, 84, w: 142, h: 32)
        GTodo(text: "장보기", plate: true, size: 12).at(14, 120, w: 142, h: 32)
        GTodo(text: "택배 보내기", plate: true, size: 12).at(164, 48, w: 142, h: 32)
        // 치과는 오늘에서 내일로 건너간다
        GTodo(text: "치과 예약", tag: move > 0.95 ? "옮김" : nil, tagPop: b.pop(6.5), plate: true, size: 12)
            .at(mix(14, 164, move), mix(48, 84, move), w: 142, h: 32)

        GToast(text: "2가지를 바꿨어").show(b.p(7.0, 0.35), rise: 14).at(20, 292, w: 280, h: 40)

        GBar(text: text, caret: b.on(0.4) && !b.on(3.5), pressed: b.press(3.35)).at(0, 344)

        // 바꾸기 전에 먼저 보여 주는 판
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("이렇게 할게").font(Typo.serif(15)).foregroundStyle(Ink.text)
                GAIMark()
            }
            planRow("‘치과 예약’ → 내일", check: b.pop(4.0))
            planRow("‘보고서 초안’ 끝냄", check: b.pop(4.3))
            Text("2가지 적용").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Ink.accentText)
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.accent))
                .scaleEffect(1 - 0.05 * b.press(5.3))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GPaper(radius: 18))
        .opacity(sheet).offset(y: CGFloat(1 - sheet) * 30)
        .at(14, 176, w: 292, h: 158, align: .topLeading)

        GuideFinger(beat: b, keys: [(2.7, CGPoint(x: 200, y: 300)), (3.2, CGPoint(x: 281, y: 372)), (4.5, CGPoint(x: 281, y: 372)),
                                    (5.1, CGPoint(x: 160, y: 306)), (5.8, CGPoint(x: 160, y: 306))], taps: [3.35, 5.3])
    }

    private func column(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name).font(Typo.serif(15)).foregroundStyle(Ink.text)
            Rectangle().fill(Ink.rule).frame(height: 1)
        }
    }

    private func planRow(_ text: String, check: Double) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(Ink.text)
                Image(systemName: "checkmark").font(.system(size: 8.5, weight: .heavy)).foregroundStyle(Ink.sheet)
            }
            .frame(width: 16, height: 16).scaleEffect(check).opacity(min(1, check))
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
        }
        .frame(height: 22)
    }
}
