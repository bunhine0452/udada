import Foundation

// 말하는 동안 카드가 떨어지는 쏟아내기: 받아쓴 글이 자랄 때마다 '말이 끝난 조각'만 카드로 내려보낸다.
// 받아쓰기는 앞서 쓴 글을 고쳐 쓰기도 하므로, 조각이 같으면 카드를 그대로 두고(다듬은 것도 지키고) 달라진 자리만 바꾼다.
// Foundation 만 쓴다 (Mac 테스트가 그대로 돌린다).

/// 화면에 떨어진 카드 한 장
struct LiveCard: Identifiable, Hashable, Sendable {
    var id = UUID()
    /// 이 카드를 만든 조각 (받아쓴 글이 바뀌었는지 이걸로 본다)
    var source: String
    var s: DumpSuggestion
    /// Apple Intelligence 가 칸을 다시 봤나
    var refined = false
}

enum LiveDump {
    /// 받아쓴 글 → 말이 끝난 조각들과, 아직 말하는 중인 끝 조각.
    /// 멈췄다 다시 말하면 줄이 바뀐다(VoiceInput) — 앞 줄은 다 끝난 말이다. open 이 false 면(멈춤 · 한동안 조용함) 끝 조각도 끝난 것으로 친다.
    static func cut(_ text: String, open: Bool) -> (settled: [String], pending: String) {
        let pieces = BrainRules.split(text)
        guard open, let last = pieces.last, !text.hasSuffix("\n") else { return (pieces, "") }
        return (Array(pieces.dropLast()), last)
    }

    /// 앞서 있던 카드를 새 조각 목록에 맞춘다. 같은 조각의 카드는 그대로(같은 id · 다듬은 칸), 새 조각만 make 로 만든다.
    static func reconcile(_ old: [LiveCard], settled: [String], make: (String) -> DumpSuggestion) -> [LiveCard] {
        var pool = old
        return settled.enumerated().map { i, piece in
            // 같은 자리의 같은 조각이 먼저, 없으면 자리가 밀린 같은 조각
            if i < old.count, old[i].source == piece, let k = pool.firstIndex(where: { $0.id == old[i].id }) { return pool.remove(at: k) }
            if let k = pool.firstIndex(where: { $0.source == piece }) { return pool.remove(at: k) }
            var s = make(piece)
            s.piece = i
            return LiveCard(source: piece, s: s)
        }
    }
}
