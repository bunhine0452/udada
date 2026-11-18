import SwiftUI

/// 숏폼 앞에 잠깐: 단축어 자동화(유튜브·인스타·틱톡이 열릴 때)가 이 화면을 먼저 띄운다.
/// 막지 않는다. 지금 할 것 하나와 1분 숨을 보여 주고, 그냥 가도 15분은 다시 끼어들지 않는다.
/// 숏폼 사이를 빨리 오가면 '하려던 일'을 기억하는 힘이 떨어졌다 (Chiossi et al., CHI 2023).
struct GateView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var next: FlowNext?

    var body: some View {
        ZStack {
            if let next {
                FlowNextView(next: next).transition(.opacity)
            } else {
                gate.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: next)
    }

    private func go(_ after: FlowNext) {
        FlowNextView.prepare(after, store: store)
        next = after
    }

    /// 큰 글자에서는 버튼까지 한 장으로 스크롤 — 큰 버튼 셋을 아래에 박아 두면 위 내용이 가려진다
    @ViewBuilder private var gate: some View {
        let now = store.sheet(for: store.today).now
        if typeSize.isAccessibilitySize {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    message(now)
                    actions(now)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 24)
            }
            .background(Ink.ground.ignoresSafeArea())
        } else {
            VStack(spacing: 0) {
                FlowCenteredScroll {
                    message(now).padding(.horizontal, Metric.gutter)
                }
                actions(now).padding(.horizontal, Metric.gutter)
            }
            .padding(.bottom, 12)
            .background(Ink.ground.ignoresSafeArea())
        }
    }

    private func message(_ now: NowLine?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("잠깐.").font(Typo.serif(44, relativeTo: .largeTitle)).foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("gate.title")
            Text("쇼츠 열기 전에 하나만 보고 가.").font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
            if let now {
                // 하루 한 장의 '지금 줄'을 그대로 옮겨 온 한 장 (코발트는 선 하나만 — 누를 것과 겹치지 않게)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Capsule().fill(Ink.accent).frame(width: 18, height: 3)
                        Text("지금 \(Fmt.hm(now.minute))").font(Typo.num(.caption, .semibold)).foregroundStyle(Ink.accent)
                    }
                    Text(now.headline).font(.system(.headline, weight: .bold)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(now.advice).font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("gate.now")
            }
        }
    }

    private func actions(_ now: NowLine?) -> some View {
        VStack(spacing: 10) {
            if let fit = now?.fit {
                Button(fit.title.count <= 12 ? "‘\(fit.title)’ 먼저 할래" : "이거 먼저 할래") { go(.focus(fit)) }
                    .buttonStyle(FillButton(tone: .accent))
                    .accessibilityLabel("‘\(fit.title)’ 먼저 할래")
                    .accessibilityIdentifier("gate.focus")
            }
            Button("1분 숨 쉬고 갈래") { go(.rest(.breath)) }
                .buttonStyle(FillButton(tone: .mint))
                .accessibilityIdentifier("gate.breath")
            Button("그냥 갈래") {
                GatePass.grant()
                dismiss()
            }
            .buttonStyle(FillButton(tone: .line))
            .accessibilityIdentifier("gate.pass")
            Text("그냥 가도 돼. 15분 동안은 다시 안 끼어들게.").font(.system(.footnote)).foregroundStyle(Ink.text3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
