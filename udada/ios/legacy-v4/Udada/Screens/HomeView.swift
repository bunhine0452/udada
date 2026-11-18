import SwiftUI

struct IntroView: View {
    @Environment(Flow.self) private var flow
    var body: some View {
        VStack(spacing: 16) {
            TopBar()
            LCD(label: "우다다", badge: "머릿속 정리 기계") {
                Text("머릿속에 떠도는 거,\n우다다 쏟아내고\n하나씩 닫아.")
                    .font(Fonts.lcd(26)).kerning(-0.5).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 10) {
                how(1, "쏟아낸다", "할 일, 걱정, 생각난 거 전부. 한 줄에 하나씩.")
                how(2, "한 장씩 정리한다", "지금 할지, 언제 할지, 걱정 시간으로 미룰지, 버릴지.")
                how(3, "잊어도 된다", "정해 둔 건 그때 알려 줄게. 머리에 안 들고 있어도 돼.")
            }
            Spacer(minLength: 8)
            Text("'언제'만 정해도 머릿속에 계속 떠오르던 생각이 줄었어. (Masicampo & Baumeister 2011)")
                .font(Fonts.ui(11.5, .medium)).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
            Button {
                Store.shared.seenIntro = true
                flow.go(.home)
            } label: { KeyLabel(tag: "3분이면 돼", title: "시작하기", big: 21) }
                .buttonStyle(KeyStyle(tone: .blue))
                .frame(height: 84)
                .accessibilityIdentifier("intro.go")
        }
        .padding(.horizontal, 18).padding(.bottom, 8)
    }

    private func how(_ n: Int, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)").font(Fonts.mono(20, .heavy)).foregroundStyle(Palette.blue).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Fonts.ui(16, .heavy)).kerning(-0.4)
                Text(sub).font(Fonts.ui(12.5, .medium)).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.body2)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.black.opacity(0.08), lineWidth: 1)))
    }
}

/// 첫 화면: 한 문장 · 머리 소음 · 큰 [쏟아내기] · 오늘 할 것 · 닫은 고리
struct HomeView: View {
    @Environment(Flow.self) private var flow
    @State private var refresh = 0

    var body: some View {
        @Bindable var flow = flow
        let store = Store.shared
        let today = store.today()
        let openCount = store.open.count
        VStack(spacing: 14) {
            TopBar {
                SmallKey(symbol: "tray.full", label: "\(openCount)") { flow.go(.drawer) }
                    .accessibilityIdentifier("drawer").accessibilityLabel("정리함 \(openCount)개")
            }
            LCD(label: flow.banner == nil ? "머릿속 정리 기계" : "방금 정리함", badge: flow.banner == nil ? "지금" : "끝") {
                VStack(alignment: .leading, spacing: 8) {
                    if let b = flow.banner {
                        Text(b).font(Fonts.lcd(19)).kerning(-0.3).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("banner")
                    } else {
                        Text("머릿속 거,\n우다다 쏟아내.").font(Fonts.lcd(26)).kerning(-0.5).fixedSize(horizontal: false, vertical: true)
                        Text("꺼내서 하나씩 '언제'나 '안 함'을 붙이면 머리가 조용해져.")
                            .font(Fonts.ui(12, .semibold)).opacity(0.8).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            LCD(label: "지금 머리 소음", badge: Noise.word(flow.before)) {
                HStack(spacing: 14) {
                    SevenSeg(text: flow.before < 10 ? " \(flow.before)" : "\(flow.before)", height: 34)
                    ClarityBar(value: $flow.before).accessibilityIdentifier("noise")
                }
            }
            Button { flow.startDump() } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("한 줄에 하나 · 맞춤법 상관없음").font(Fonts.ui(11, .heavy)).opacity(0.75)
                        Spacer()
                        Image(systemName: "text.badge.plus").font(.system(size: 20, weight: .bold))
                    }
                    Spacer(minLength: 0)
                    Text("쏟아내기").font(Fonts.ui(34, .heavy)).kerning(-1.2)
                }
            }
            .buttonStyle(KeyStyle(tone: .blue, radius: 18, depth: 7))
            .frame(minHeight: 120, maxHeight: .infinity) // 남는 공간은 쏟아내기 키가 채운다
            .layoutPriority(-1)
            .accessibilityIdentifier("dump.start")
            Panel {
                HStack {
                    Text("오늘 할 것").font(Fonts.ui(12, .heavy))
                    Spacer()
                    Text("닫은 고리").font(Fonts.ui(10, .heavy)).opacity(0.6)
                    SevenSeg(text: String(format: "%04d", min(9999, store.closedTotal)), height: 16, color: Palette.ink, ghost: 0.08)
                }
                .foregroundStyle(Palette.ink2)
                if today.isEmpty {
                    Text(openCount == 0 ? "비어 있어. 머리가 시끄러우면 쏟아내 봐." : "오늘은 없어. 나머지는 정해 둔 날에 알려 줄게.")
                        .font(Fonts.ui(13, .semibold)).foregroundStyle(Palette.ink2)
                } else {
                    ForEach(today.prefix(3)) { it in
                        HStack(spacing: 10) {
                            Button {
                                Feel.detent(); store.markDone(it.id); refresh += 1
                            } label: {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke(Palette.ink.opacity(0.35), lineWidth: 1.2))
                            }
                            .foregroundStyle(Palette.ink)
                            .accessibilityLabel("끝: \(it.text)")
                            Text(it.text).font(Fonts.ui(15, .bold)).foregroundStyle(Palette.ink).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(it.bin == .now ? "지금" : it.due.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")
                                .font(Fonts.mono(11, .bold)).foregroundStyle(Palette.ink2)
                        }
                    }
                }
            }
            .id(refresh)
            .accessibilityIdentifier("today")
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 18).padding(.bottom, 8)
    }
}
