import SwiftUI

// 첫 실행 소개: 움직이는 사용법(아홉 장면) → 필요한 것만 켜기. 건너뛰어도 켜기 쪽은 한 번 보여 준다.

struct IntroView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var setup = false

    var body: some View {
        ZStack {
            if setup {
                setupPage.transition(reduceMotion ? .opacity : Motion.rise)
            } else {
                AITour(intro: true,
                       onTry: { what in finish(seed: false); store.tryFromTour(what) },
                       onClose: { withAnimation(reduceMotion ? nil : Motion.page) { setup = true } })
                    .transition(.opacity)
            }
        }
        .background(Ink.ground.ignoresSafeArea())
    }

    private var setupPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation(reduceMotion ? nil : Motion.page) { setup = false } } label: {
                    Label("사용법", systemImage: "chevron.left").font(.system(.body, weight: .semibold))
                }
                .foregroundStyle(Ink.text2)
                .frame(minHeight: Metric.tap)
                .accessibilityIdentifier("intro.back")
                Spacer()
            }
            .padding(.horizontal, Metric.gutter)
            IntroSetupPage()
            VStack(spacing: 8) {
                Button("시작하기") { finish(seed: false) }
                    .buttonStyle(FillButton())
                    .accessibilityIdentifier("intro.start")
                // 예시는 빈 앱에서만 — 소개를 다시 볼 때 내 할 일을 덮지 않게
                if canSeed {
                    Button("예시로 채워서 둘러보기") { finish(seed: true) }
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, minHeight: Metric.tap)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("intro.seed")
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 12)
        }
    }

    private var canSeed: Bool { store.data.items.isEmpty }

    private func finish(seed: Bool) {
        let now = store.now
        let fill = seed && canSeed
        store.tab = .today
        store.selectedDay = store.today
        store.change { d in
            if fill { d = Seed.day(now: now, keep: d) }
            d.seenIntro = true
        }
        Haptic.success()
    }
}
