import SwiftUI

// 사용법 장면 6~9: 밖에서 받기 · Siri · 식히고 닫기 · 기기 안에서.

// MARK: - 6. 밖에서 받기 (받은 글 · 사진)

struct CaptureScene: View {
    var b: Beat
    static let length = 10.5
    private static let parts: [(String, Bool)] = [("금요일 7시", true), ("에 ", false), ("강남역", true), ("에서 ", false), ("저녁", true), (" 어때?", false)]

    var body: some View {
        let found = b.on(2.1)

        // 받은 메시지
        Text("민지").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Ink.text3).show(b.p(0.2, 0.3)).at(18, 10, w: 100, h: 14)
        message.padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ink.fill))
            .fixedSize(horizontal: true, vertical: false)
            .show(b.p(0.3, 0.35)).at(14, 28, h: 36)
        Text("ㅋㅋㅋ 어제 진짜 웃겼어").font(.system(size: 13.5)).foregroundStyle(Ink.text)
            .padding(.horizontal, 12).frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ink.fill))
            .fixedSize(horizontal: true, vertical: false)
            .show(b.p(0.5, 0.35)).opacity(1 - 0.72 * b.p(2.5, 0.4)).at(14, 70, h: 36)

        // 공유 → 우다다
        HStack(spacing: 5) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 10.5, weight: .semibold))
            Text("공유 → 우다다").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Ink.text)
        .padding(.horizontal, 10).frame(maxHeight: .infinity)
        .background(Capsule().strokeBorder(Ink.text.opacity(0.7), lineWidth: 1.2))
        .fixedSize(horizontal: true, vertical: false)
        .scaleEffect(1 - 0.06 * b.press(1.6))
        .show(b.p(0.9, 0.3) * (1 - b.lin(2.0, 0.3))).at(196, 112, h: 28)

        VStack(alignment: .leading, spacing: 6) {
            GAIMark(text: "받은 글에서 찾음").opacity(b.p(3.6, 0.3))
            GBlock(when: "금 19:00", title: "강남역 저녁").frame(height: 38)
        }
        .show(b.land(3.0, 0.5), rise: 18).at(14, 112, w: 292, h: 64, align: .topLeading)

        // 포스터 사진
        VStack(alignment: .leading, spacing: 6) {
            Text("가을 북토크").font(Typo.serif(17)).foregroundStyle(Ink.text)
                .padding(.horizontal, 4).overlay(mark(b.pop(7.0)))
            Text("12월 5일 (토) 오후 3시").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Ink.text)
                .padding(.horizontal, 4).overlay(mark(b.pop(7.2)))
            Text("성수 책방 · 참가비 5,000원 · 문의 02-000-0000").font(.system(size: 10)).foregroundStyle(Ink.text3)
                .padding(.horizontal, 4).opacity(1 - 0.6 * b.p(7.2, 0.4))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.fill))
        .overlay(alignment: .top) {
            // 위에서 아래로 한 번 읽어 내려간다
            Rectangle().fill(Ink.accent).frame(height: 2).offset(y: 92 * b.lin(5.7, 1.2))
                .opacity(b.on(5.7) && !b.on(6.95) ? 0.9 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .show(b.p(5.0, 0.45)).at(14, 196, w: 292, h: 96, align: .topLeading)

        GBlock(when: "12/5 토 15:00", title: "가을 북토크").show(b.land(7.7, 0.5), rise: 18).at(14, 304, w: 292, h: 38)
        Text("가격 · 주소 · 전화번호는 뺐어").font(.system(size: 11)).foregroundStyle(Ink.text3).show(b.p(8.4, 0.35)).at(18, 350, w: 280, h: 16)

        GuideFinger(beat: b, keys: [(0.9, CGPoint(x: 150, y: 220)), (1.4, CGPoint(x: 250, y: 126)), (2.0, CGPoint(x: 250, y: 126))], taps: [1.6])

        let _ = found
    }

    private var message: some View {
        HStack(spacing: 0) {
            ForEach(Self.parts.indices, id: \.self) { i in
                let on = Self.parts[i].1
                let p = on ? b.p(2.1 + Double(i) * 0.12, 0.35) : 0
                Text(Self.parts[i].0).font(.system(size: 13.5, weight: on && p > 0.3 ? .semibold : .regular)).foregroundStyle(Ink.text)
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { g in Capsule().fill(Ink.accent).frame(width: g.size.width * p, height: 2).offset(y: g.size.height) }
                    }
            }
        }
    }

    private func mark(_ p: Double) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Ink.accent, lineWidth: 1.5).scaleEffect(0.9 + 0.1 * min(1, p)).opacity(min(1, p))
    }
}

// MARK: - 7. Siri

/// 앱 밖(잠금 화면)에서 Siri 에게 말한다. 우다다가 열리지 않고 답이 그 자리에 뜬다.
struct SiriScene: View {
    var b: Beat
    static let length = 13.0

    var body: some View {
        let second = b.on(6.8)
        let fade = 1 - b.p(6.4, 0.35) + b.p(6.9, 0.3)   // 두 번째 대화로 바뀌는 사이
        let s = second ? b.t - 6.8 : b.t                 // 대화 안의 시각
        let c = Beat(t: s)
        let ask = second ? "“Siri야, 우다다로 정리해 줘”" : "“Siri야, 우다다한테 시키기”"
        let reply = second ? "뭘 정리할까?" : "뭘 할까?"
        let say = second ? "엄마한테 전화하고 보고서 쓰고 월세가 걱정이야" : "치과 내일로 미루고 금요일 7시에 저녁 약속 넣어"
        let cardAt = second ? 3.3 : 4.4
        let speaking = (c.on(0.4) && !c.on(1.3)) || (c.on(1.9) && !c.on(cardAt - 0.4))

        RoundedRectangle(cornerRadius: 0).fill(Ink.night).at(0, 0, w: 320, h: 400)
        Text("9:41").font(Typo.num(size: 40, .semibold)).foregroundStyle(Ink.nightText).at(0, 14, w: 320, h: 46, align: .center)

        // Siri 가 그 자리에서 보여 주는 우다다의 답
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("우다다").font(Typo.serif(14)).foregroundStyle(Ink.text)
                GAIMark()
                Spacer()
            }
            if second {
                Text("3개로 나눠 넣었어").font(.system(size: 14, weight: .bold)).foregroundStyle(Ink.text)
                line("엄마한테 전화하기", "지금", c.pop(cardAt + 0.4))
                line("보고서 쓰기", "내일 아침", c.pop(cardAt + 0.7))
                line("월세가 걱정이야", "걱정 상자", c.pop(cardAt + 1.0))
            } else {
                Text("2가지 했어").font(.system(size: 14, weight: .bold)).foregroundStyle(Ink.text)
                line("‘치과 예약’", "내일로", c.pop(cardAt + 0.4))
                line("‘저녁 약속’", "금 19:00", c.pop(cardAt + 0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.sheet))
        .show(c.land(cardAt, 0.5) * fade, rise: -16)
        .at(16, 74, w: 288, h: second ? 150 : 124, align: .topLeading)

        // 말한 것
        VStack(alignment: .leading, spacing: 7) {
            Text(ask).font(.system(size: 12.5)).foregroundStyle(Ink.nightSoft).opacity(c.p(0.4, 0.3))
            Text(reply).font(.system(size: 14, weight: .semibold)).foregroundStyle(Ink.nightText).opacity(c.p(1.4, 0.3))
            Text(c.on(1.9) ? "“" + typed(say, c, from: 1.9, per: 0.07) + (c.on(1.9 + Double(say.count) * 0.07) ? "”" : "") : " ")
                .font(.system(size: 14.5, weight: .medium)).foregroundStyle(Ink.nightText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(fade)
        .at(22, 248, w: 276, h: 96, align: .topLeading)

        // 듣고 있다는 표시: 가는 물결 한 줄 (말할 때만 출렁인다)
        Wave(phase: b.t * 5, amp: speaking ? 7 : 1.2)
            .stroke(Ink.nightText.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .at(60, 356, w: 200, h: 24)
        Text("우다다는 열리지 않았어").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Ink.nightSoft)
            .opacity(c.p(cardAt + 0.9, 0.4) * fade).at(0, 382, w: 320, h: 14, align: .center)
    }

    private func line(_ title: String, _ tag: String, _ pop: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Ink.text)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.text).lineLimit(1)
            Spacer(minLength: 4)
            GTag(text: tag)
        }
        .scaleEffect(0.96 + 0.04 * min(1, pop), anchor: .leading).opacity(min(1, pop))
    }
}

private struct Wave: Shape {
    var phase: Double
    var amp: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 60
        for i in 0...n {
            let x = Double(i) / Double(n)
            // 가운데가 크고 양 끝이 잦아든다
            let y = sin(x * 9 + phase) * amp * sin(x * .pi)
            let pt = CGPoint(x: r.minX + r.width * x, y: r.midY + y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

// MARK: - 8. 식히고 닫기

struct RestScene: View {
    var b: Beat
    static let length = 11.0

    var body: some View {
        let night = 1 - b.p(4.8, 0.6)
        // 두 번 들이쉬고(0.5~1.9, 1.9~2.6) 길게 내쉰다(2.6~4.8)
        let breath = 0.5 + 0.32 * b.p(0.5, 1.4) + 0.18 * b.p(1.9, 0.7) - 0.5 * b.p(2.6, 2.2)
        let word = b.on(2.6) ? "길게 내쉬어" : b.on(1.9) ? "한 번 더" : "들이쉬고"

        // 하루 닫기 (종이)
        Group {
            Text("하루 닫기").font(Typo.serif(20)).foregroundStyle(Ink.text).at(20, 18, w: 200, h: 28)
            Text("남은 것 2").font(.system(size: 11.5)).foregroundStyle(Ink.text3).at(20, 46, w: 200, h: 16)
            leftover("보고서 초안", pick: 0, tapAt: 6.5).at(20, 72, w: 280, h: 40)
            leftover("택배 보내기", pick: 1, tapAt: 7.4).at(20, 118, w: 280, h: 40)
            stamp.at(86, 176, w: 148, h: 148, align: .center)
            Text("3개 끝냄 · 2개는 자리를 정했어").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Ink.text2)
                .show(b.p(8.9, 0.4)).at(0, 340, w: 320, h: 18, align: .center)
        }
        .opacity(1 - night)

        // 식히기 (밤)
        Group {
            Rectangle().fill(Ink.night).at(-300, -300, w: 920, h: 1000)
            Text("1분 숨").font(Typo.serif(18)).foregroundStyle(Ink.nightText).at(0, 26, w: 320, h: 26, align: .center)
            Circle().fill(Ink.nightSoft.opacity(0.22))
                .overlay(Circle().strokeBorder(Ink.nightText.opacity(0.85), lineWidth: 1.5))
                .frame(width: 190, height: 190).scaleEffect(breath)
                .at(65, 90, w: 190, h: 190, align: .center)
            Text(word).font(.system(size: 15, weight: .semibold)).foregroundStyle(Ink.nightText).at(0, 304, w: 320, h: 22, align: .center)
            Text("쉬는 동안 화면엔 볼 게 없어").font(.system(size: 11)).foregroundStyle(Ink.nightSoft).at(0, 334, w: 320, h: 16, align: .center)
        }
        .opacity(night)

        GuideFinger(beat: b, keys: [(5.8, CGPoint(x: 160, y: 250)), (6.3, CGPoint(x: 222, y: 92)), (6.9, CGPoint(x: 222, y: 92)),
                                    (7.2, CGPoint(x: 272, y: 138)), (7.9, CGPoint(x: 272, y: 138))], taps: [6.5, 7.4])
    }

    /// 남은 일 한 줄: 내일 · 나중에 중 하나를 누르면 그쪽으로 빠져나간다
    private func leftover(_ title: String, pick: Int, tapAt: Double) -> some View {
        let gone = b.land(tapAt + 0.15, 0.45)
        return HStack(spacing: 6) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.text)
            Spacer()
            ForEach(0..<2, id: \.self) { i in
                let on = i == pick && b.on(tapAt)
                Text(i == 0 ? "내일" : "나중에").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? Ink.sheet : Ink.text)
                    .padding(.horizontal, 9).frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Ink.text : Ink.fill))
                    .scaleEffect(i == pick ? 1 - 0.08 * b.press(tapAt) : 1)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GPaper(radius: 12))
        .opacity(1 - gone).offset(x: 60 * CGFloat(gone))
    }

    /// 도장: 크게 떠 있다가 쿵 내려앉는다
    private var stamp: some View {
        let hit = b.lin(8.1, 0.22)
        let settle = 1 + 0.9 * pow(1 - hit, 2) - 0.05 * sin(b.lin(8.32, 0.3) * .pi)
        return ZStack {
            Circle().strokeBorder(Ink.stamp, lineWidth: 4)
            Circle().strokeBorder(Ink.stamp, lineWidth: 1.5).padding(9)
            VStack(spacing: 2) {
                Text("오늘 끝").font(Typo.serif(28))
                Text("11 · 18").font(Typo.num(size: 12, .semibold))
            }
            .foregroundStyle(Ink.stamp)
        }
        .rotationEffect(.degrees(-12))
        .scaleEffect(settle)
        .opacity(0.92 * hit)
    }
}

// MARK: - 9. 기기 안에서

struct InsideScene: View {
    var b: Beat
    static let length = 7.0
    private static let outside = ["서버", "계정", "광고"]

    private var status: String {
        switch Brain.modelStatus() {
        case .ready: "이 기기의 Apple Intelligence가 지금 켜져 있어"
        case .off: "설정에서 켤 수 있어"
        case .unavailable(let why): why + " — 그래도 같은 흐름이 규칙으로 돌아가"
        }
    }

    var body: some View {
        let breath = 0.5 + 0.5 * sin(b.t * 1.5)
        // 기기 하나. 글은 이 테두리를 넘지 않는다
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Ink.sheet)
            RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Ink.text, lineWidth: 2)
            VStack(spacing: 12) {
                Circle().fill(Ink.accent).frame(width: 18, height: 18).scaleEffect(0.6 + 0.4 * breath).opacity(0.45 + 0.5 * breath)
                Text("적은 글 · 말 · 사진").font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text)
                GAIMark()
            }
        }
        .scaleEffect(0.94 + 0.06 * b.p(0.3, 0.5)).opacity(b.p(0.3, 0.5))
        .at(75, 50, w: 170, h: 190, align: .center)

        ForEach(Self.outside.indices, id: \.self) { i in
            HStack(spacing: 4) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .heavy))
                Text(Self.outside[i] + " 없음").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Ink.text2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Capsule().strokeBorder(Ink.rule, lineWidth: 1))
            .show(b.p(1.6 + Double(i) * 0.35, 0.4))
            .at(CGFloat(22 + i * 96), 270, w: 84, h: 30, align: .center)
        }
        Text(status).font(.system(size: 12)).foregroundStyle(Ink.text3).multilineTextAlignment(.center)
            .show(b.p(3.2, 0.4)).at(20, 322, w: 280, h: 40, align: .center)
    }
}
