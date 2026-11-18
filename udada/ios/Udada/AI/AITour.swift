import SwiftUI

// 움직이는 사용법: 앱이 하는 일을 아홉 장면으로, 글이 아니라 진짜 화면이 움직이는 것으로 보여 준다.
// 장면마다 손가락이 누르고 → 화면이 답하고 → 아래 세 줄 설명이 그 순간에 맞춰 켜진다. 장면은 저절로 되풀이된다.
// 동작 줄이기를 켜면 장면의 끝 모습으로 멈춘다. iPhone 과 Mac 이 같은 파일을 쓴다 (부품은 GuideKit · GuideScenes).

/// 장면의 '직접 해 보기'가 여는 곳
enum TourTry: Hashable { case add, dump, find }

struct AITour: View {
    /// 처음 실행(소개)이면 닫기 대신 '건너뛰기', 마지막 장면의 버튼은 '다음'
    var intro = false
    var onTry: (TourTry) -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 동작 줄이기, 또는 UI 테스트 실행(-udReset: 끝없이 도는 장면은 테스트가 '화면이 멈출 때'를 못 만나게 한다)이면 끝 모습으로 멈춘다
    private var reduce: Bool { reduceMotion || (Self.frozen == nil && ProcessInfo.processInfo.arguments.contains("-udReset")) }
    /// 확인용(-udTourPage 3): 그 장면에서 연다
    @State private var page: Int = {
        defer { AITour.openAt = nil }
        let p = AITour.openAt ?? AITour.arg("-udTourPage").map { Int($0) } ?? 0
        return min(max(0, p), AITour.chapters.count - 1)
    }()
    /// 다음에 열릴 때 시작할 장면 (한 번 쓰고 비운다)
    @MainActor static var openAt: Int?
    @State private var forward = true
    @State private var started = Date()

    /// 확인용(-udTourAt 4.2): 그 시각에 멈춘 그림
    private static let frozen: Double? = arg("-udTourAt")
    private static func arg(_ name: String) -> Double? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
        return Double(a[i + 1])
    }

    struct Chapter {
        var title: String
        var ai = false
        var night = false
        var length: Double
        /// (켜지는 시각, 설명)
        var steps: [(Double, String)]
        var tryIt: (String, TourTry)? = nil
    }

    static let chapters: [Chapter] = [
        Chapter(title: "아래 한 줄에 적으면 자리를 찾아가", length: AddScene.length,
                steps: [(0, "화면 아래 줄에 그냥 적어."), (2.9, "날짜 · 시각 · 길이를 읽어서 넣기 전에 보여 줘."), (4.9, "시각이 있으면 약속, 없으면 할 일이 돼.")],
                tryIt: ("적어 보기", .add)),
        Chapter(title: "하루는 세 칸, 파란 칸이 지금", length: BandsScene.length,
                steps: [(0, "하루를 아침 · 낮 · 저녁 세 칸으로 봐."), (1.9, "지금 칸은 파랗게. 다음 약속까지 남은 시간이 보여."), (3.9, "그 시간에 들어갈 일을 골라 줘. 시작만 누르면 돼.")]),
        Chapter(title: "끝내면 긋고, 못 하면 밀어", length: DoneScene.length,
                steps: [(0, "네모를 누르면 끝. 잉크로 그어져."), (2.6, "줄을 왼쪽으로 밀면 내일이나 나중으로 가."), (4.3, "잘못 눌러도 되돌리기 한 번이면 돼.")]),
        Chapter(title: "쏟아내면 한 줄씩 나눠 줘", ai: true, length: DumpScene.length,
                steps: [(0, "떠오르는 대로 말하거나 써. 순서도 맞춤법도 상관없어."), (3.3, "Apple Intelligence가 한 줄씩 떼어 다듬어."), (5.9, "지금 · 날짜 · 걱정으로 나눠. 넣는 건 네가 눌러야 돼.")],
                tryIt: ("쏟아내 보기", .dump)),
        Chapter(title: "한 문장으로 여러 일을 바꿔", ai: true, length: CommandScene.length,
                steps: [(0, "같은 줄에 시키듯 적어도 돼."), (3.6, "Apple Intelligence가 읽고, 바꾸기 전에 먼저 보여 줘."), (5.5, "한 번에 적용하고, 한 번에 되돌려.")],
                tryIt: ("시켜 보기", .find)),
        Chapter(title: "받은 글과 사진에서 챙길 것만", ai: true, length: CaptureScene.length,
                steps: [(0, "메시지 · 메일은 공유 버튼으로 우다다에 보내."), (2.1, "Apple Intelligence가 약속만 찾아. 잡담은 빼."), (5.0, "포스터 · 안내문은 사진으로. 날짜와 이름을 묶어 줘.")]),
        Chapter(title: "앱을 열지 않고 Siri에게", ai: true, night: true, length: SiriScene.length,
                steps: [(0, "“Siri야, 우다다한테 시키기” — 잠긴 화면에서도 돼."), (4.4, "한 문장에 여러 일. 읽고 바로 바꾼 뒤 결과를 보여 줘."), (6.8, "“우다다로 정리해 줘” — 쏟아낸 말을 나눠 넣는 것까지.")]),
        Chapter(title: "뜨거우면 식히고, 저녁엔 닫아", length: RestScene.length,
                steps: [(0, "식히기: 1분 숨. 두 번 들이쉬고 길게 내쉬어."), (4.8, "하루 닫기: 남은 일은 내일이나 나중으로."), (8.1, "도장 쿵. 내일은 빈 머리로 시작해.")]),
        Chapter(title: "전부 이 기기 안에서", ai: true, length: InsideScene.length,
                steps: [(0, "적은 글 · 말 · 사진은 이 기기를 떠나지 않아."), (1.6, "서버도, 계정도, 광고도 없어."), (3.2, "Apple Intelligence가 없는 기기에서도 같은 흐름이 돌아가.")]),
    ]

    var body: some View {
        let ch = Self.chapters[page]
        let last = page == Self.chapters.count - 1
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("우다다 사용법").font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text2)
                Spacer()
                Button(intro ? "건너뛰기" : "닫기", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Ink.text2)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier(intro ? "intro.skip" : "tour.close")
            }

            // 장면은 시각의 함수다. 한 바퀴 = 장면 길이 + 끝 모습으로 머무는 1.6초
            TimelineView(.animation(paused: reduce || Self.frozen != nil)) { ctx in
                let total = ch.length + 1.6
                let raw = ctx.date.timeIntervalSince(started)
                let phase = raw.truncatingRemainder(dividingBy: total)
                let t = Self.frozen ?? (reduce ? ch.length : min(phase, ch.length))
                // 되풀이 사이에는 막을 잠깐 내린다 (끝 모습에서 처음으로 거꾸로 돌아가는 것이 보이지 않게)
                let curtain = reduce || Self.frozen != nil ? 1 : min(1, phase / 0.3, (total - phase) / 0.3)
                let active = ch.steps.lastIndex { $0.0 <= t } ?? 0

                VStack(alignment: .leading, spacing: 14) {
                    progress(part: reduce ? 1 : phase / total)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("\(page + 1) / \(Self.chapters.count)").font(Typo.num(size: 12, .semibold)).foregroundStyle(Ink.text3)
                            if ch.ai { GAIMark() }
                        }
                        Text(ch.title).font(Typo.serif(25)).foregroundStyle(Ink.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }

                    GuideStage { scene(page, Beat(t: t)) }
                        .opacity(curtain)
                        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 470)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(ch.night ? Ink.night : Ink.ground))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(ch.steps.indices, id: \.self) { i in step(i, ch.steps[i].1, active: active) }
                    }
                    .animation(reduce ? nil : Motion.soft, value: active)
                }
            }
            .id(page)
            .transition(reduce ? .opacity : .asymmetric(
                insertion: .opacity.combined(with: .offset(x: forward ? 28 : -28)),
                removal: .opacity.combined(with: .offset(x: forward ? -28 : 28))))

            Spacer(minLength: 14)

            HStack(spacing: 10) {
                if page > 0 {
                    Button("이전") { go(page - 1) }.buttonStyle(TourButton(fill: Ink.fill, text: Ink.text))
                        .accessibilityIdentifier("tour.back")
                }
                if let t = ch.tryIt {
                    Button(t.0) { onTry(t.1) }.buttonStyle(TourButton(fill: Ink.fill, text: Ink.text))
                        .accessibilityIdentifier("tour.try")
                }
                Spacer(minLength: 0)
                Button(last ? (intro ? "다음" : "다 봤어") : "다음") {
                    if last { onClose() } else { go(page + 1) }
                }
                .buttonStyle(TourButton(fill: Ink.accent, text: Ink.accentText))
                .accessibilityIdentifier("tour.next")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Ink.ground.ignoresSafeArea())
        // 옆으로 밀어 넘긴다
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) else { return }
            if v.translation.width < -40, page < Self.chapters.count - 1 { go(page + 1) }
            if v.translation.width > 40, page > 0 { go(page - 1) }
        })
    }

    private func go(_ p: Int) {
        forward = p > page
        started = Date()
        withAnimation(reduce ? nil : Motion.page) { page = p }
    }

    /// 어디쯤인지: 장면 수만큼의 가는 줄. 지금 장면의 줄은 장면이 흐르는 만큼 찬다.
    private func progress(part: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(Self.chapters.indices, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Ink.rule)
                        Capsule().fill(Ink.text).frame(width: g.size.width * (i < page ? 1 : i == page ? max(0.04, part) : 0))
                    }
                }
                .frame(height: 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("사용법")
        .accessibilityValue("\(Self.chapters.count)장면 중 \(page + 1)번째")
    }

    /// 설명 한 줄: 장면이 그 대목에 닿으면 켜진다
    private func step(_ i: Int, _ text: String, active: Int) -> some View {
        let on = i == active, past = i < active
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(i + 1)").font(Typo.num(size: 12, .bold))
                .foregroundStyle(on ? Ink.accentText : Ink.text3)
                .frame(width: 20, height: 20)
                .background(Circle().fill(on ? Ink.accent : Ink.fill))
            Text(text).font(.system(size: 15, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Ink.text : past ? Ink.text2 : Ink.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func scene(_ i: Int, _ b: Beat) -> some View {
        switch i {
        case 0: AddScene(b: b)
        case 1: BandsScene(b: b)
        case 2: DoneScene(b: b)
        case 3: DumpScene(b: b)
        case 4: CommandScene(b: b)
        case 5: CaptureScene(b: b)
        case 6: SiriScene(b: b)
        case 7: RestScene(b: b)
        default: InsideScene(b: b)
        }
    }
}

private struct TourButton: ButtonStyle {
    var fill: Color
    var text: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
