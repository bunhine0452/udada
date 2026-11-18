import AppIntents
import SwiftUI

// Siri 안내 카드와 Siri 결과 조각(스니펫). 「차분한 종이 시간표」: 종이 면 + 먹 글자, 강조는 하나만.

/// 설정·소개 화면에 끼워 넣는 작은 카드: "우다다에 적어 줘" 팁 + 단축어 앱 바로가기.
/// - chrome: false 면 카드 테두리 없이 (설정 표의 한 줄로) 쓴다.
/// - 팁의 닫기를 누르면 팁만 접힌다. 말할 문장과 단축어 바로가기는 남는다.
///   isVisible 을 주지 않으면 스스로 기억한다.
struct SiriTipCard: View {
    private var external: Binding<Bool>?
    private var chrome: Bool
    @State private var shown = true
    @Environment(\.colorScheme) private var scheme

    init(isVisible: Binding<Bool>? = nil, chrome: Bool = true) {
        external = isVisible
        self.chrome = chrome
    }

    private var visible: Binding<Bool> { external ?? $shown }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("말로 넣기").font(Typo.serif(18, relativeTo: .headline)).foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Text("“우다다에 적어 줘”라고 말하거나, 동작 버튼·단축어에 붙여 써.")
                    .font(Typo.meta).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if visible.wrappedValue {
                SiriTipView(intent: AddEntryIntent(), isVisible: visible)
                    .siriTipViewStyle(scheme == .dark ? .dark : .light)
            }
            ShortcutsLink()
                .shortcutsLinkStyle(scheme == .dark ? .darkOutline : .lightOutline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("siri.shortcuts")
        }
        Group {
            if chrome { content.card() } else { content.padding(.vertical, 6) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("siri.tip")
    }
}
