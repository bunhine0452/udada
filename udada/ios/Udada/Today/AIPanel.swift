import SwiftUI
import UIKit

/// 넣기 줄의 Apple Intelligence 버튼이 여는 판: 이 기기의 모델로 할 수 있는 일을 한자리에 모았다.
/// 줄마다 무엇을 하는지와 실제 예시 한 줄. 누르면 바로 그 화면으로 간다.
struct AIPanel: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var status: (text: String, ready: Bool) {
        switch Brain.shared.status {
        case .ready: ("이 iPhone 안에서만 돌아. 적은 글은 밖으로 안 나가.", true)
        case .off: ("설정에서 꺼 둔 상태야. 지금은 규칙으로 같은 흐름이 돌아.", false)
        case .unavailable(let why): (why + ". 규칙으로 같은 흐름이 돌아.", false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.intelligence").font(.system(.title3, weight: .semibold)).foregroundStyle(Ink.accent)
                            .accessibilityHidden(true)
                        Text("Apple Intelligence").font(Typo.serif(24, relativeTo: .title2)).foregroundStyle(Ink.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(status.text).font(.system(.subheadline)).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ai.panel.status")
                }
                .padding(.bottom, 6)

                row("calendar.day.timeline.left", "한 주 풀기", "“이번 주 너무 빡빡해” — 넘치는 칸의 일을 빈 칸으로", id: "ai.replan") {
                    store.replan = ReplanRequest()
                }
                row("mic", "말로 쏟아내기", "떠오르는 대로 말하면 한 줄씩 나눠 줘", id: "ai.voice") {
                    store.dumpMode = .voice; store.cover = .dump
                }
                row("camera", "사진에서 넣기", "포스터 · 안내문 · 손메모에서 일정을 읽어", id: "ai.photo") {
                    store.dumpMode = .photo; store.cover = .dump
                }
                row("text.bubble", "물어보거나 시키기", "“다음 주 병원 언제야” · “치과 내일로 미뤄”", id: "ai.ask") {
                    store.cover = .find
                }
                row("doc.on.clipboard", "받은 글 붙여넣기", "복사한 메시지 · 메일에서 챙길 것만 골라", id: "ai.paste") {
                    guard let t = UIPasteboard.general.string, t.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
                        store.show("복사해 둔 글이 없어")
                        return
                    }
                    Inbox.put(text: t)
                    store.inboxCount = Inbox.items().count
                    store.takeInbox = true
                    store.dumpMode = .text
                    store.cover = .dump
                }
                row("waveform", "Siri에게 시키기", "“우다다한테 시키기” · “우다다로 정리해 줘”", id: "ai.siri") {
                    AITour.openAt = 6
                    store.showAITour = true
                }

                Text("할 일을 길게 누르면 ‘작게 쪼개기’도 있어. 한 줄에 여러 일을 적으면 알아서 나눠 넣어.")
                    .font(Typo.meta).foregroundStyle(Ink.text3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { AITour.openAt = 0; store.showAITour = true }
                } label: {
                    Label("움직이는 사용법 보기", systemImage: "play.circle").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Ink.accent)
                        .frame(minHeight: Metric.tap)
                }
                .accessibilityIdentifier("ai.guide")
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 26)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Ink.ground)
        .accessibilityIdentifier("ai.panel")
    }

    private func row(_ symbol: String, _ title: String, _ example: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            dismiss()
            // 판이 내려간 뒤에 연다 (덮개가 겹치지 않게)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: action)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Ink.accent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Ink.accentSoft))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typo.row).foregroundStyle(Ink.text)
                    Text(example).font(Typo.meta).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(Ink.text3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metric.radiusCard, style: .continuous).fill(Ink.sheet))
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
