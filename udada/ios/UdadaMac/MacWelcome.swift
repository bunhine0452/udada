import SwiftUI

/// 처음 열었을 때의 안내 네 쪽. 그림 대신 진짜 부품으로 — 한 줄 넣기는 여기서 바로 쳐 볼 수 있다.
/// (Mac 에는 설정 화면이 없어서 store.showSettings 를 '다시 보기' 신호로 쓴다.)
struct MacWelcome: View {
    @Environment(Store.self) private var store
    @State private var page = 0
    private let count = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image("MenuMark").foregroundStyle(Ink.text)
                Text("우다다").font(Typo.serif(15)).foregroundStyle(Ink.text)
                Spacer()
                Button("건너뛰기") { finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.text3)
                    .opacity(page < count - 1 ? 1 : 0)
            }
            .padding(.bottom, 26)

            Group {
                switch page {
                case 0: WelcomeMenuBar()
                case 1: WelcomeQuickAdd()
                case 2: WelcomeAI()
                default: WelcomeSync()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .transition(.opacity)
            .id(page)

            HStack(spacing: 7) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule().fill(i == page ? Ink.text : Ink.rule).frame(width: i == page ? 18 : 6, height: 6)
                }
                Spacer()
                if page > 0 {
                    Button("이전") { withAnimation(.easeOut(duration: 0.18)) { page -= 1 } }.buttonStyle(MacFill(tone: .quiet))
                }
                Button(page < count - 1 ? "다음" : "시작하기") {
                    if page < count - 1 { withAnimation(.easeOut(duration: 0.18)) { page += 1 } } else { finish() }
                }
                .buttonStyle(MacFill(tone: .accent))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("welcome.next")
            }
            .animation(.easeOut(duration: 0.18), value: page)
        }
        .padding(28)
        .frame(width: 640, height: 500)
        .background(Ink.ground)
    }

    private func finish() {
        store.showSettings = false
        if !store.data.seenIntro { store.change { $0.seenIntro = true } }
    }
}

/// 쪽 하나의 틀: 큰 제목 · 설명 · 보기
private struct WelcomePage<Content: View>: View {
    var title: String
    var sub: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(Typo.serif(27)).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                Text(sub).font(.system(size: 13.5)).foregroundStyle(Ink.text2).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            content
        }
    }
}

private struct Bullet: View {
    var symbol: String
    var title: String
    var sub: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(Ink.text).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.text)
                Text(sub).font(.system(size: 12)).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: 1. 메뉴 막대

private struct WelcomeMenuBar: View {
    var body: some View {
        WelcomePage(title: "메뉴 막대에 지금 한 줄", sub: "창을 닫아도 우다다는 화면 맨 위에 남아. 다음 약속까지 남은 시간, 남은 할 일, 집중 시계가 거기 보여.") {
            VStack(alignment: .leading, spacing: 16) {
                // 메뉴 막대를 흉내 낸 띠
                HStack(spacing: 14) {
                    Spacer()
                    HStack(spacing: 5) {
                        Image("MenuMark")
                        Text("치과 1:20").font(.system(size: 12.5, weight: .medium).monospacedDigit())
                    }
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Ink.blockText.opacity(0.16)))
                    Image(systemName: "wifi").font(.system(size: 12, weight: .semibold))
                    Image(systemName: "battery.75percent").font(.system(size: 14))
                    Text("오전 10:20").font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(Ink.blockText)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Ink.block))

                Bullet(symbol: "cursorarrow.click", title: "누르면 오늘이 내려와", sub: "한 줄 넣기, 지금 할 일, 세 띠. 네모 칸을 누르면 끝.")
                Bullet(symbol: "play.fill", title: "집중을 시작하면 시계가 메뉴 막대에", sub: "같은 시계가 iPhone 에서도 이어져. 어느 쪽에서 끝내도 돼.")
                Bullet(symbol: "hand.draw", title: "창에서는 끌어서 옮겨", sub: "할 일을 아침·낮·저녁 띠 사이로 끌어다 놓아. ⌘Z 로 되돌려.")
            }
        }
    }
}

// MARK: 2. 한 줄 넣기

private struct WelcomeQuickAdd: View {
    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var added: String?
    @FocusState private var focused: Bool

    var body: some View {
        WelcomePage(title: "어디서나 한 줄", sub: "무슨 앱을 쓰고 있든 ⌃⌥Space 를 누르면 한 줄 칸이 떠. 날짜·시각·길이를 말하듯 쓰면 알아서 자리를 찾아.") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 5) {
                    KeyCap(text: "⌃"); KeyCap(text: "⌥"); KeyCap(text: "Space")
                    Text("지금 여기서 쳐 봐").font(.system(size: 12)).foregroundStyle(Ink.text3).padding(.leading, 4)
                }
                AddField(text: $text, large: true, prompt: "내일 3시 치과", onAdded: { added = $0 }, focused: $focused)
                    .padding(16)
                    .paper(14)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
                if let added {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Ink.accent)
                        Text(added).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Ink.text)
                    }
                } else {
                    Text("예: 금요일까지 기획서 1시간 · 매주 월수금 아침 운동 · 언젠가 책장 정리")
                        .font(.system(size: 12)).foregroundStyle(Ink.text3)
                }
            }
        }
        .onAppear { focused = true }
    }
}

// MARK: 3. Apple Intelligence

private struct WelcomeAI: View {
    @State private var shown = 0
    private static let said = "엄마한테 전화해야 되고 보고서도 써야 되는데 월세 오르면 어떡하지"
    private static let cards = [("엄마한테 전화하기", "지금"), ("보고서 쓰기", "내일 아침"), ("월세 오르면 어떡하지", "걱정 상자")]

    private var status: (String, Bool) {
        switch Brain.modelStatus() {
        case .ready: ("이 Mac 에서 바로 돼", true)
        case .off: ("꺼져 있어", false)
        case .unavailable(let why): (why + " — 그래도 규칙으로 똑같이 나눠 줘", false)
        }
    }

    var body: some View {
        WelcomePage(title: "Apple Intelligence가 대신 정리해", sub: "⌘D 로 쏟아내기를 열고 머릿속 말을 그대로 적어. 이 Mac 에 내장된 Apple Intelligence가 한 줄씩 떼어 칸에 나눠. 글은 Mac 밖으로 안 나가.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Text("“\(Self.said)”")
                        .font(.system(size: 12.5)).foregroundStyle(Ink.text2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(width: 210, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.fill))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Ink.text3).padding(.top, 14)
                    VStack(spacing: 6) {
                        ForEach(Array(Self.cards.enumerated()), id: \.offset) { i, c in
                            HStack {
                                Text(c.0).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Ink.text)
                                Spacer(minLength: 6)
                                Text(c.1).font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.sheet)
                                    .padding(.horizontal, 7).frame(height: 20)
                                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.text))
                            }
                            .padding(.horizontal, 11).frame(height: 36)
                            .paper(9)
                            .opacity(i < shown ? 1 : 0)
                            .offset(y: i < shown ? 0 : 6)
                        }
                    }
                }
                let s = status
                HStack(spacing: 8) {
                    AppleAIBadge()
                    Image(systemName: s.1 ? "checkmark" : "info.circle").font(.system(size: 10, weight: .bold)).foregroundStyle(s.1 ? Ink.text : Ink.text3)
                    Text(s.0).font(.system(size: 12)).foregroundStyle(s.1 ? Ink.text : Ink.text2)
                }
                Bullet(symbol: "iphone.rear.camera", title: "종이 목록은 아이폰으로 찍어", sub: "쏟아내기에서 ‘아이폰으로 찍기’를 누르면 아이폰 카메라가 열리고, 찍은 글자가 이 Mac 으로 바로 들어와.")
                Bullet(symbol: "figure.walk", title: "첫 동작 · 걱정 살피기", sub: "처음 보는 일엔 2분짜리 첫걸음을, 걱정엔 내 손 안의 한 가지를 찾아 줘.")
            }
        }
        .task {
            for i in 1...Self.cards.count {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 500 : 380))
                withAnimation(.easeOut(duration: 0.22)) { shown = i }
            }
        }
    }
}

// MARK: 4. iPhone 과 맞추기

private struct WelcomeSync: View {
    @Environment(Store.self) private var store

    var body: some View {
        WelcomePage(title: "iPhone 과 알아서 맞춰져", sub: "같은 Apple 계정이면 켤 것이 없어. 내 iCloud 로만 오가고, 개발자는 볼 수 없어.") {
            VStack(alignment: .leading, spacing: 15) {
                SyncLine(on: store.settings.syncOn)
                    .padding(.horizontal, 11).frame(height: 30)
                    .paper(8)
                Bullet(symbol: "arrow.left.arrow.right", title: "여기서 적으면 몇 초 뒤 iPhone 에", sub: "iPhone 위젯에서 끝낸 일은 Mac 메뉴 막대에서도 지워져.")
                Bullet(symbol: "timer", title: "집중 시계가 이어져", sub: "Mac 에서 시작하고 자리를 떠도 iPhone 에서 같은 시계가 돌아.")
                Bullet(symbol: "rectangle.on.rectangle", title: "보던 날을 이어 열어 (Handoff)", sub: "iPhone 에서 보던 날이 Mac 독에 뜨고, 누르면 그날이 열려.")
                Bullet(symbol: "widget.small", title: "iPhone 위젯을 Mac 바탕화면에", sub: "바탕화면에서 위젯 편집을 열면 iPhone 의 우다다 위젯을 그대로 올릴 수 있어.")
            }
        }
    }
}
