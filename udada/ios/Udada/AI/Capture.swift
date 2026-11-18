import Foundation

// 밖에서 받기: 남이 보낸 글(메시지 · 메일 · 공지 · 받아쓴 녹음)에서 내가 챙길 일정과 할 일만 줄로 뽑는다.
// 모델(Apple Intelligence)은 '무엇을'과 '글에 적힌 때 낱말'을 **베껴** 오기만 하고, 날짜 계산은 Parser 가 한다.
// 글에 없는 이름·때는 버린다. 모델이 없으면 때가 읽히거나 부탁하는 말이 든 문장을 그대로 쓴다.
// 뽑은 줄은 비우기 정리(Brain.organize)로 들어가 카드가 된다. 측정: Eval/run.sh capture · design/AI.md 17절

enum CaptureRules {
    /// 모델이 읽은 것 하나 (검사 전)
    struct Found: Hashable, Sendable {
        var title: String
        var when: String
    }

    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }
    private static func strip(_ r: NSRegularExpression, _ s: String) -> String { r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "") }

    /// 부탁·챙길 것을 말하는 끝 ("보내 주세요", "챙겨", "사 와", "제출")
    private static let ask = rx(#"주세요|주시면|부탁|해\s*줘|해\s*줄래|챙겨|사\s*와|준비해|제출|접수|납부|반납|올려|보내\s*줘|까지"#)
    /// 머리말: "[Web발신]", "엄마:", "공지:", "안녕하세요 김대리님,"
    private static let head = rx(#"^\s*(?:\[[^\]]{1,20}\]\s*)?(?:[가-힣A-Za-z]{1,8}\s*[:：]\s*)?(?:안녕하세요[^,.!\n]{0,12}[,.!]?\s*)?"#)
    /// 일이 아닌 줄: 번호·금액만 있는 안내, 인사
    private static let noise = rx(#"운송장|승인번호|고객센터|문의\s*[:는]|수신거부|좋은\s*하루|감사합니다\.?$|^[ㅋㅎㅠㅜ\s]+$|[었았했]어\s*[??]$|[었았했]니\s*[??]?$|(?:네요|군요|구나|더라)\s*[.!]?$"#)
    private static let digits = rx(#"\d{2,4}-\d{3,4}-\d{4}|\d{1,3}(?:,\d{3})+\s*원"#)

    /// 글을 문장으로 (줄바꿈 · 마침표 · 물음표 · "그리고")
    static func sentences(_ text: String) -> [String] {
        let t = text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: #"(?<=[.?!。])\s+|\n+|,?\s*그리고\s+"#, with: "\n", options: .regularExpression)
        // 받아쓴 말처럼 마침표 없이 길게 이어진 문장은 이음 어미에서 한 번 더 자른다
        return t.split(separator: "\n").map { strip(head, String($0)).trimmingCharacters(in: .whitespaces) }
            .flatMap { $0.count > 60 ? BrainRules.splitSpeech($0) : [$0] }
            .filter { $0.count >= 2 }
    }

    /// 모델 없이: 때가 읽히거나 부탁하는 말이 든 문장을 그대로 (60자까지)
    static func lines(_ text: String, now: Date, calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        var last: Parsed?
        for s in sentences(text) where !has(noise, s) {
            let clean = readable(strip(digits, s)).trimmingCharacters(in: CharacterSet(charactersIn: " .·"))
            let p = Parser.parse(clean, now: now, calendar: calendar)
            guard p.title.count >= 2, p.day != nil || p.time != nil || has(ask, clean), clean.count <= 60 else { continue }
            // 날만 말한 문장 뒤에 시각만 말한 문장이 오면 같은 약속이다 ("수요일 저녁에 시간 돼? 6시 반 홍대 어때")
            if let l = last, l.day != nil, l.time == nil, p.day == nil, p.time != nil, let i = out.indices.last, out[i].count + clean.count <= 70 {
                out[i] += " " + clean
                last = Parser.parse(out[i], now: now, calendar: calendar)
                continue
            }
            if !out.contains(clean) { out.append(clean); last = p }
        }
        return Array(out.prefix(8))
    }

    /// Parser 가 읽게: "11월 20일(금)" 의 괄호 요일을 떼고, "19일입니다" 는 "19일" 로
    static func readable(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*[\((][월화수목금토일][\))]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(\d\s*[일시분]|내일|모레|오늘|요일|까지)(?:입니다|이에요|예요|이야|이고|야)(?![가-힣])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    /// 규칙이 고른 문장(뼈대)에 모델이 읽은 것을 보탠다.
    /// - 글이 길어 문장이 많이 걸렸으면(넷 넘게) 모델도 챙길 일이라고 본 문장만 남긴다.
    /// - 규칙이 놓친 일은 모델의 줄 가운데 **때가 읽히는 것만** 더한다 (때 없는 덧붙임은 지어낸 것일 때가 많다).
    static func blend(rule: [String], model: [String], now: Date, calendar: Calendar = .current) -> [String] {
        func share(_ a: String, _ b: String) -> Double {
            let x = Set(letters(Parser.parse(a, now: now, calendar: calendar).title)), y = Set(letters(b))
            return x.isEmpty ? 0 : Double(x.intersection(y).count) / Double(x.count)
        }
        var out = rule
        if rule.count > 4, !model.isEmpty { out = rule.filter { r in model.contains { share($0, r) >= 0.5 } } }
        for m in model where !rule.contains(where: { share(m, $0) >= 0.5 }) {
            let p = Parser.parse(m, now: now, calendar: calendar)
            guard p.day != nil || p.time != nil else { continue }
            // 이미 받은 줄과 같은 날·같은 시각이면 그 때를 다른 일에 잘못 붙인 것이다 ("화요일 2시 미팅" 옆의 "화요일 2시 회의 내용 정리")
            let taken = rule.contains { r in
                let q = Parser.parse(r, now: now, calendar: calendar)
                return q.day == p.day && q.time == p.time
            }
            if !taken { out.append(m) }
        }
        return Array(out.prefix(8))
    }

    private static func flat(_ s: String) -> String { s.precomposedStringWithCanonicalMapping.filter { !$0.isWhitespace } }
    private static func letters(_ s: String) -> [Character] { s.filter { $0.isLetter || $0.isNumber } }

    /// 모델이 읽은 것을 줄로: 이름의 글자 70% 이상이 글에 있어야 하고, 때 낱말은 글에 **그대로** 있어야 한다 (없으면 때를 뗀다).
    /// 이름에 이미 때가 들어 있으면 그대로 쓴다. 같은 이름은 한 번, 8줄까지.
    static func lines(from found: [Found], source: String, now: Date, calendar: Calendar = .current) -> [String] {
        let src = flat(source), have = Set(letters(src))
        var out: [String] = [], seen = Set<String>()
        for f in found.prefix(10) {
            let title = readable(strip(digits, f.title.replacingOccurrences(of: "\n", with: " "))).trimmingCharacters(in: CharacterSet(charactersIn: " .·,"))
            let mine = letters(title)
            guard title.count >= 2, title.count <= 40, !mine.isEmpty, !has(noise, title),
                  Double(mine.filter(have.contains).count) / Double(mine.count) >= 0.7, seen.insert(flat(title)).inserted else { continue }
            var when = f.when.trimmingCharacters(in: .whitespacesAndNewlines)
            if when.isEmpty || !src.contains(flat(when)) || when.count > 30 { when = "" }
            when = readable(when)
            let own = Parser.parse(title, now: now, calendar: calendar)
            // 이름에 이미 그 때가 있으면 덧붙이지 않는다
            if own.day != nil || own.time != nil || flat(title).contains(flat(when)) { when = "" }
            let line = (when.isEmpty ? title : when + " " + title)
            out.append(line)
        }
        return Array(out.prefix(8))
    }
}
