import SwiftUI

enum Screen: Hashable { case intro, home, dump, sort, finish, breath, drawer }

/// 한 번의 정리: 쏟아내기 → 한 장씩 정리 → 지금 할 단 하나.
@MainActor
@Observable
final class Flow {
    var screen: Screen
    var forward = true

    var before: Int = Store.shared.lastNoise
    var after: Int = 4
    var text = ""
    var cards: [Card] = []
    var index = 0
    /// 끝 화면에서 홈으로 돌아올 때 한 줄 소식
    var banner: String?

    struct Card: Hashable {
        var text: String
        var suggestion: Bin
        var why: String
        var when: When?
        var bin: Bin? = nil
        var chosenWhen: When? = nil
    }

    init() { screen = Store.shared.seenIntro ? .home : .intro }

    var lines: [String] { text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var counts: [Bin: Int] { Dictionary(grouping: cards.compactMap(\.bin), by: { $0 }).mapValues(\.count) }
    var nowItems: [Card] { cards.filter { $0.bin == .now } }

    func go(_ s: Screen, forward f: Bool = true) {
        forward = f
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { screen = s }
    }

    func startDump() {
        Store.shared.lastNoise = before
        text = ""; cards = []; index = 0; banner = nil
        go(.dump)
    }

    func startSort() {
        cards = lines.map { let s = Sorter.suggest($0); return Card(text: $0, suggestion: s.bin, why: s.why, when: s.when) }
        index = 0
        go(.sort)
    }

    /// 지금 카드를 칸에 넣는다. 다 넣으면 끝 화면.
    func put(_ bin: Bin, when: When? = nil) {
        guard index < cards.count else { return }
        cards[index].bin = bin
        cards[index].chosenWhen = bin == .date ? (when ?? cards[index].when ?? .tomorrow) : nil
        index += 1
        if index >= cards.count {
            after = before
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.finishSort() }
        }
    }

    private func finishSort() {
        // 지금 칸의 첫 번째는 '지금 할 단 하나', 나머지와 날짜·걱정은 정리함으로. 버린 건 저장하지 않는다.
        let now = Date()
        var items = Store.shared.items
        for c in cards where c.bin != .drop {
            items.append(Item(text: c.text, bin: c.bin!, when: c.chosenWhen, due: c.chosenWhen?.due(from: now)))
        }
        Store.shared.items = items
        if cards.contains(where: { $0.bin == .date || $0.bin == .worry }) { Reminders.requestPermission() }
        go(.finish)
    }

    func finish() {
        let s = Session(at: Date(), before: before, after: after, counts: counts)
        Store.shared.sessions = Store.shared.sessions + [s]
        Store.shared.lastNoise = after
        var msg = "머리에서 \(s.total)개를 내려놨어."
        if s.delta < 0 { msg += " 소음 \(s.before) → \(s.after)." }
        if let n = counts[.drop], n > 0 { msg += " \(n)개는 진짜로 지웠어." }
        banner = msg
        go(.home, forward: false)
    }
}
