import SwiftUI

// Apple Intelligence(아이폰 내장 모델)가 한 일에는 이름을 붙여 알린다 — 코발트 한 색으로, 또렷하게.
// 그라데이션 · 빛 번짐 · 반짝임은 없다.

/// Apple Intelligence 가 만든 글 옆에 붙는 표시. 모든 처리는 기기 안에서만 한다는 뜻.
struct AIBadge: View {
    var text = "Apple Intelligence"
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "apple.intelligence").font(.system(.caption2, weight: .semibold)).accessibilityHidden(true)
            Text(text).font(.system(.caption, weight: .semibold))
        }
        .foregroundStyle(Ink.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Ink.accentSoft))
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apple Intelligence가 정리함. 기기 안에서만 처리해.")
        .accessibilityIdentifier("ai.badge")
    }
}

/// 생각하는 동안 자리를 지키는 한 줄. 돌아가는 표시 대신 글자가 천천히 숨 쉰다.
/// 동작 줄이기를 켰으면 가만히 있다.
struct ThinkingLine: View {
    var text: String
    @State private var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.system(.subheadline))
            .foregroundStyle(Ink.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(reduceMotion ? 0.75 : (dim ? 0.4 : 1))
            .onAppear { pulse() }
            .onChange(of: reduceMotion) { _, _ in pulse() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("ai.thinking")
    }

    private func pulse() {
        guard !reduceMotion else { dim = false; return }
        dim = false
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { dim = true }
    }
}
