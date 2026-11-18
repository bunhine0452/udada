import Foundation

// 기기 안 AI(Brain)가 꺼져 있거나 없거나 늦을 때 같은 흐름을 돌리는 규칙. Foundation 만 쓴다 (macOS 하네스에서도 돈다).
// v4 Sorter(낱말 규칙)를 옮기고, 날짜·시각은 Parser 로 읽고, 말로 쏟아낸 긴 줄은 이음 어미로 자른다.
// AI 결과를 검사하고 마무리하는 것도 여기서 한다 — 규칙과 AI 가 같은 모양을 돌려주게. 근거: udada/design/AI.md

// MARK: - 공개 타입 (AI 를 쓰든 규칙을 쓰든 같은 모양)

/// 비우기 네 칸: 지금(2분이면 끝) · 날짜 정하기 · 걱정 시간 · 버리기
enum DumpBin: String, Codable, CaseIterable, Hashable { case now, date, worry, drop }

/// 비우기 카드 하나에 대한 제안.
/// text 는 사용자가 한 날짜·시각 낱말을 그대로 품는다 ("내일 3시 치과 가기") — 시각은 Parser.parse(text) 로 다시 읽는다.
struct DumpSuggestion: Identifiable, Hashable {
    var id = UUID()
    var text: String
    var bin: DumpBin
    var day: DayKey?
    var part: Part?
    var duration: Int?
    var reason: String
    var fromAI: Bool
    /// 쏟아낸 말의 몇 번째 조각에서 왔나 (모델이 다듬는 대로 그 카드만 바꿔 끼울 때 쓴다). 모르면 -1.
    var piece: Int = -1
}

/// 걱정 하나에 대한 답: 내 손에 든 게 있나, 있으면 아주 작은 한 걸음. crisis 면 상담 전화 안내가 line 에 있다.
struct WorryAdvice: Hashable {
    var inMyHands: Bool
    var step: String?
    var line: String
    var crisis: Bool
}

/// 한 주 기록. clarityDelta: 식히기 전후 맑기 평균 변화(+ 가 맑아짐), noiseDelta: 비우기 전후 머리 소음 평균 변화(- 가 조용해짐),
/// estimateRatio: 집중으로 잰 실제 ÷ 예상.
struct WeekStats: Hashable {
    var done: Int
    var added: Int
    var closedDays: Int
    var rests: Int
    var clarityDelta: Double?
    var noiseDelta: Double?
    var estimateRatio: Double?
    var bestPart: Part?
}

// MARK: - 규칙

enum BrainRules {
    /// AI 가 낸 카드 하나 (검사 전)
    struct Draft: Hashable {
        var text: String
        var bin: DumpBin
    }

    // MARK: 위기 — 어떤 AI 호출보다 먼저

    static let crisisLine = "많이 힘들구나. 혼자 견디지 않아도 돼. 109(자살예방상담)나 1577-0199(정신건강 위기상담)에 전화하면 24시간 바로 들어 줘."

    static func isCrisis(_ text: String) -> Bool { has(R.crisis, text) }

    static func crisisAdvice() -> WorryAdvice { WorryAdvice(inMyHands: false, step: nil, line: crisisLine, crisis: true) }

    // MARK: 비우기

    static func organize(_ raw: String, today: DayKey, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> [DumpSuggestion] {
        split(raw).map { suggest($0, today: today, now: now, parts: parts, calendar: calendar) }
    }

    static func suggest(_ line: String, today: DayKey, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> DumpSuggestion {
        let text = tidy(line)
        let parsed = Parser.parse(text, now: now, parts: parts, calendar: calendar)
        let bin = classify(text, parsed: parsed, today: today)
        return make(text, bin: bin, parsed: parsed, today: today, now: now, parts: parts, calendar: calendar, fromAI: false)
    }

    /// 칸 고르기 (v4 Sorter.suggest 를 옮기고 Parser 로 날짜를 본다)
    static func classify(_ text: String, parsed: Parsed, today: DayKey) -> DumpBin {
        if isCrisis(text) { return .worry }
        if has(R.worry, text), !(has(R.duty, text) && !has(R.strongWorry.self, text) || has(R.duty, text) && has(R.softWorry, text)) { return .worry }
        if has(R.drop, text) { return .drop }
        if parsed.later { return .date }
        let quick = text.filter { !$0.isWhitespace }.count <= 22 && has(R.quick, text) && !has(R.heavy, text)
        // 때를 말했으면 (저녁에 · 3시 · 금요일) 그때 할 일. '오늘'만 말한 짧은 일은 지금.
        let unscheduled = parsed.time == nil && parsed.part == nil && parsed.repeatRule == nil && (parsed.day == nil || parsed.day == today)
        return quick && unscheduled ? .now : .date
    }

    /// 모델의 칸과 규칙의 칸을 같이 본다 — 둘은 서로 다른 데서 틀린다 (Eval: 모델 86% · 규칙 88% → 같이 볼 때가 가장 높다).
    /// - 망설이는 말·걱정 말투처럼 글에 또렷이 적힌 것은 규칙이 이긴다.
    /// - 규칙이 '2분짜리'(전화·이체·답장…)라 보면 모델의 '날짜'를 '지금'으로, 큰일 낱말이 있으면 모델의 '지금'을 '날짜'로.
    static func blend(model: DumpBin, rule: DumpBin, text: String) -> DumpBin {
        if rule == .drop, model != .worry { return .drop }
        // 걱정 말투라도 '해야 함 · 하기'로 맺은 줄은 할 일이다 ("차 막힐까 봐 일찍 출발해야 함")
        if has(R.strongWorry, text), !has(R.duty, text) { return .worry }
        if model == .date, rule == .now { return .now }
        if model == .now, has(R.heavy, text) { return .date }
        return model
    }

    /// AI 가 고른 칸을 사용자가 말한 때와 맞춘다: 때를 말한 일은 '지금'이 아니다. 위기 글은 늘 걱정 칸.
    static func reconcile(_ bin: DumpBin, parsed: Parsed, today: DayKey) -> DumpBin {
        if isCrisis(parsed.title) { return .worry }
        let scheduled = parsed.time != nil || parsed.part != nil || parsed.repeatRule != nil || (parsed.day != nil && parsed.day != today)
        return bin == .now && scheduled ? .date : bin
    }

    /// 긴 쏟아내기 → 한 줄씩. 줄바꿈·목록 기호(Parser.split) 다음, 줄 안에서 이음 어미로 자른다.
    static func split(_ raw: String) -> [String] {
        var seen = Set<String>()
        let all = Parser.split(raw).flatMap(splitSpeech).filter { seen.insert($0).inserted }
        // 푸념만 있는 조각은 뺀다 (그것 하나뿐이면 그대로 둔다)
        let kept = all.filter { asides.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) == nil }
        return Array((kept.isEmpty ? all : kept).prefix(40))
    }

    /// 마음을 말한 문장의 끝 ("… 불안해 | 이번 달 가계부 …")
    private static let feelEnds: Set<String> = ["모르겠다", "모르겠어", "모르겠음", "모르겠네", "생각나", "생각난다", "싶다", "싶어", "불안해", "불안하다", "걱정이야", "걱정이다", "걱정돼", "걱정된다", "무서워", "무섭다", "겁나", "귀찮다", "귀찮아", "싫다", "싫어"]
    /// 앞에 한 말에 붙인 푸념 — 열린 고리가 아니라서 카드로 만들지 않는다
    private static let asides = try! NSRegularExpression(pattern: #"^(?:너무\s*|진짜\s*|좀\s*)?(?:언젠가|나중에|일단|귀찮[다아]|손이\s*안\s*가|아직\s*(?:시작도|반도|하나도|아무것도)\s*못\s*했어|하기\s*싫[다어])$"#)

    /// '-기'로 끝나지만 움직임이 아닌 낱말의 끝 (선풍기 · 이야기 · 분리수거는 '기'로 안 끝난다)
    private static let nounGiTails = ["풍기", "탁기", "소기", "습기", "조기", "전기", "행기", "화기", "산기", "정기", "레기", "야기", "얘기", "위기", "고기",
                                      "일기", "악기", "후기", "감기", "연기", "용기", "공기", "경기", "초기", "중기", "말기", "기기", "자기", "동기",
                                      "포기", "무기", "식기", "향기", "딸기", "모기", "장기", "단기", "시기", "계기", "열기", "인기", "분기", "학기",
                                      "만기", "대기", "상기", "쓰레기", "아기", "거기", "여기", "저기", "얘기"]
    private static let afterGi: Set<String> = ["전에", "전", "싫다", "싫어", "싫은데", "위해", "위한", "때문에", "힘들다", "어렵다", "쉽다", "좋다", "귀찮다",
                                               "시작", "시작하기", "전까지", "위해서", "바람", "마련", "나름", "일쑤",
                                               // 것 같아서 · (전세) 사기 당하면 · 하기 힘든
                                               "같아서", "같아", "같다", "같은데", "같은", "같고", "같애", "당하면", "당할까", "당했어", "당할", "피해",
                                               "됐는데", "됐어", "되면", "돼서", "힘든", "어려운", "싫은", "좋은"]

    /// 메모 말투의 맺음: 잡기 · 내기 · 해야 함 · 사 갈 것 (뒤에 '전에·싫다' 같은 말이 오면 맺음이 아니다)
    private static func endsNote(_ w: String, next: String) -> Bool {
        if afterGi.contains(next) { return false }
        if ["함", "것", "할것", "됨"].contains(w) { return true }
        guard w.count >= 2, w.hasSuffix("기"), !nounGiTails.contains(where: { w.hasSuffix($0) }) else { return false }
        return true
    }

    private static let worryEnds: Set<String> = ["어떡하지", "어떡해", "어떡하냐", "어쩌지", "어쩌나", "어쩌냐", "어떻게하지"]

    /// 줄바꿈 없는 말 받아쓰기 한 줄 → 여러 줄. "엄마한테 전화하고 보고서 써야 되고 월세 오르면 어떡하지" → 3줄
    static func splitSpeech(_ line: String) -> [String] {
        var out: [String] = []
        for sentence in sentences(line) {
            let words = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var cur: [String] = []
            func flush() {
                let s = tidy(trimFillers(cur).joined(separator: " "))
                if s.contains(where: { $0.isLetter || $0.isNumber }) { out.append(s) }
                cur = []
            }
            var i = 0
            while i < words.count {
                if let n = markerLength(words, at: i, inClause: !cur.isEmpty) { flush(); i += n; continue }
                let w = words[i].trimmingCharacters(in: punct)
                cur.append(words[i])
                // 걱정의 끝말(… 어떡하지)은 문장 끝이다 — 뒤에 다른 일이 이어져도 여기서 끊는다
                if i + 1 < words.count, worryEnds.contains(w) || feelEnds.contains(w) { flush(); i += 1; continue }
                // 메모하듯 쓴 말: "날짜 잡기 연차 내기 …" · "출발해야 함 기름도 넣어야 함" · "과일 사 갈 것" — 맺음말 뒤에서 끊는다
                if i + 1 < words.count, endsNote(w, next: words[i + 1].trimmingCharacters(in: punct)) { flush(); i += 1; continue }
                // 쉼표 목록: "보고 자료 수정, 출장비 정산 올리기, …" — 일 이름으로 끝난 쉼표에서 끊는다 ("두부, 대파" 같은 물건 나열은 그대로)
                if i + 1 < words.count, words[i].hasSuffix(","), verbalNouns.contains(w) || (w.hasSuffix("기") && !nounGiTails.contains(where: { w.hasSuffix($0) })) { flush(); i += 1; continue }
                // "…보낼까 그릇은 빌려야 돼" — 스스로 묻는 말(~ㄹ까) 뒤에 다른 일이 이어지면 끊는다 ('할까 말까 · 볼까 싶어 · 할까 봐'는 한 덩어리)
                if i + 1 < words.count, w.count >= 2, w.hasSuffix("까"),
                   !["말까", "봐", "싶", "고민", "하는데", "해서", "생각", "하다가", "하고"].contains(where: { words[i + 1].trimmingCharacters(in: punct).hasPrefix($0) }) { flush(); i += 1; continue }
                // "…확인해야 돼 학점 망하면…" — '해야 돼/해'로 끝난 문장 뒤에 다른 말이 이어지면 거기서 끊는다
                if i + 1 < words.count, ["돼", "해", "돼요", "해요", "한다", "된다"].contains(w),
                   let p = cur.dropLast().last?.trimmingCharacters(in: punct), p.hasSuffix("야") { flush(); i += 1; continue }
                if i + 1 < words.count, let end = connective(w, prev: cur.dropLast().last, next: words[i + 1], alone: cur.count == 1) {
                    cur[cur.count - 1] = end
                    flush()
                }
                i += 1
            }
            // 말이 이음 어미로 끝났으면 (… 전화하고) 끝맺은 꼴로
            if let last = cur.last, let end = connective(last.trimmingCharacters(in: punct), prev: cur.dropLast().last, next: "끝", alone: cur.count == 1) {
                cur[cur.count - 1] = end
            }
            flush()
        }
        // 한 글자짜리 조각은 앞 줄에 붙인다
        var merged: [String] = []
        for s in out {
            if s.filter({ $0.isLetter || $0.isNumber }).count < 2, let last = merged.popLast() { merged.append(last + " " + s) } else { merged.append(s) }
        }
        return merged
    }

    /// AI 카드를 검사해 제안으로 마무리한다.
    /// - 입력에 없는 말로 쓴 카드는 뺀다 (지어낸 일). 입력에 없던 날짜·시각 낱말은 읽지 않는다 (지어낸 날짜).
    /// - '버리기'는 진짜 지워지니 망설이는 말(할까 말까 · 볼까 · 언젠가)이 있을 때만 믿는다. 아니면 규칙 칸.
    /// - 걱정은 사용자 말 그대로 둔다 (감정에 이름 붙이기 — VALUE.md ②).
    /// - 입력 조각의 3분의 1 넘게를 놓쳤으면 nil (→ 규칙).
    static func finish(_ drafts: [Draft], raw: String, today: DayKey, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> [DumpSuggestion]? {
        // 뼈대는 규칙이 자른 조각이다. 모델의 카드는 조각마다 붙여서 글을 다듬고 칸을 고르는 데 쓴다.
        // 그래서 모델이 줄을 뭉개거나 잘라먹어도 **규칙이 찾은 줄은 하나도 잃지 않는다** (Eval verdict2: 모델 길이 규칙보다 더 잃던 것 9 대 6).
        let pieces = split(raw)
        guard !pieces.isEmpty else { return nil }
        let source = letters(raw)
        struct Cand { var text: String; var bin: DumpBin; var parsed: Parsed }
        var byPiece: [Int: [Cand]] = [:]
        var seen = Set<String>()
        for d in drafts.prefix(40) {
            var text = tidy(stripBinTag(d.text))
            let mine = content(text)
            let all = letters(text)
            guard text.count <= 80, !all.isEmpty, overlap(all, source) >= 0.6 else { continue }
            // 이 카드가 어느 조각에서 왔나 (어느 조각과도 안 닮았으면 지어낸 것으로 보고 버린다)
            guard let idx = pieces.indices.max(by: { overlap(mine, content(pieces[$0])) < overlap(mine, content(pieces[$1])) }),
                  overlap(mine, content(pieces[idx])) >= 0.34 else { continue }
            let piece = pieces[idx]
            var bin = d.bin
            if bin == .drop, !has(R.drop, text + " " + piece) {
                bin = classify(piece, parsed: Parser.parse(piece, now: now, parts: parts, calendar: calendar), today: today)
            }
            if bin == .worry { text = piece }
            var parsed = Parser.parse(text, now: now, parts: parts, calendar: calendar)
            // 사용자가 말한 때(이번 주말에 · 3시)를 AI 가 빠뜨렸으면 원래 조각을 쓴다
            if bin != .drop, parsed.day == nil, parsed.time == nil, parsed.part == nil, !parsed.later {
                let pp = Parser.parse(piece, now: now, parts: parts, calendar: calendar)
                if pp.day != nil || pp.time != nil || pp.part != nil || (pp.later && bin == .date) { text = piece; parsed = pp }
            }
            guard seen.insert(text).inserted else { continue }
            if !temporalWordsGrounded(text, title: parsed.title, in: raw) {
                parsed = Parser.parse(parsed.title, now: now, parts: parts, calendar: calendar)
            }
            bin = blend(model: bin, rule: classify(text, parsed: parsed, today: today), text: text)
            byPiece[idx, default: []].append(Cand(text: text, bin: reconcile(bin, parsed: parsed, today: today), parsed: parsed))
        }
        guard !byPiece.isEmpty else { return nil }
        var out: [DumpSuggestion] = []
        for (i, piece) in pieces.enumerated() {
            let cands = byPiece[i] ?? []
            let cover = overlap(content(piece), content(cands.map(\.text).joined(separator: " ")))
            // 카드 하나가 조각의 절반 넘게를, 또는 여러 장이 함께 60% 넘게를 담았을 때만 모델의 글을 쓴다 (모델이 한 조각을 둘로 나눈 것은 살린다)
            if (cands.count == 1 && cover >= 0.5) || (cands.count >= 2 && cover >= 0.6) {
                for c in cands {
                    var s = make(c.text, bin: c.bin, parsed: c.parsed, today: today, now: now, parts: parts, calendar: calendar, fromAI: true)
                    s.piece = i
                    out.append(s)
                }
            } else {
                // 모델이 놓쳤거나 잘라먹은 조각 — 사용자의 말 그대로 규칙 카드로. 모델이 고른 칸은 한 표로 쓴다.
                var s = suggest(piece, today: today, now: now, parts: parts, calendar: calendar)
                if let c = cands.first {
                    let parsed = Parser.parse(piece, now: now, parts: parts, calendar: calendar)
                    let bin = reconcile(blend(model: c.bin, rule: s.bin, text: piece), parsed: parsed, today: today)
                    if bin != s.bin { s = make(piece, bin: bin, parsed: parsed, today: today, now: now, parts: parts, calendar: calendar, fromAI: false) }
                }
                s.piece = i
                out.append(s)
            }
        }
        return out
    }

    // MARK: 사진에서 본 일정

    /// 모델이 사진에서 본 일정 하나 (검사 전)
    struct SeenEvent: Hashable, Sendable {
        var title: String
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
    }

    /// 모델이 본 일정을 글자 인식 결과와 맞춰 본 뒤 한 줄씩으로 만든다 ("11월 20일 오후 7시 정기 공연").
    /// - 제목의 글자 70% 이상이 글자 인식 결과에 있어야 한다 (지어낸 일정 막기).
    /// - 날짜·시각의 숫자도 글자 인식 결과에 있어야 한다. 없으면 그 날짜·시각은 버리고 제목만 둔다.
    /// 이렇게 만든 줄은 Parser 가 다시 읽으니, 여기서 날짜를 '정하지' 않는다.
    static func lines(from events: [SeenEvent], ocr: [String], now: Date = Date(), calendar: Calendar = .current) -> [String] {
        let text = ocr.joined(separator: " ")
        let source = letters(text)
        let numbers = Set(text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.compactMap { Int($0) })
        let midnight = text.contains("자정") || text.range(of: #"(?<!\d)0{1,2}\s*[시:]"#, options: .regularExpression) != nil
        struct Row { var line: String; var title: String; var day: DayKey?; var time: Int? }
        var rows: [Row] = [], seen = Set<String>()
        for e in events.prefix(12) {
            let title = tidy(e.title.replacingOccurrences(of: "\n", with: " "))
            let mine = letters(title)
            guard title.count >= 2, title.count <= 40, !mine.isEmpty, overlap(mine, source) >= 0.7, seen.insert(title).inserted else { continue }
            // 제목에 이미 날짜·시각이 적혀 있으면 (손으로 쓴 목록의 한 줄) 그 줄을 그대로 쓴다
            let own = Parser.parse(title, now: now, calendar: calendar)
            if own.day != nil || own.time != nil {
                rows.append(Row(line: title, title: own.title, day: own.day, time: own.time))
                continue
            }
            var when = ""
            if (1...12).contains(e.month), (1...31).contains(e.day), numbers.contains(e.month), numbers.contains(e.day) {
                when = "\(e.month)월 \(e.day)일 "
            }
            // 0시는 '시각 없음'을 잘못 채운 것일 때가 많다 — 사진에 자정·0시가 적혀 있을 때만 믿는다
            if (1...23).contains(e.hour) || (e.hour == 0 && midnight), numbers.contains(e.hour) || numbers.contains(e.hour % 12 == 0 ? 12 : e.hour % 12) {
                let h12 = e.hour % 12 == 0 ? 12 : e.hour % 12
                when += (e.hour < 12 ? "오전 " : "오후 ") + "\(h12)시" + (e.minute > 0 && numbers.contains(e.minute) ? " \(e.minute)분 " : " ")
            }
            let line = (when + title).trimmingCharacters(in: .whitespaces)
            let p = Parser.parse(line, now: now, calendar: calendar)
            rows.append(Row(line: line, title: title, day: p.day, time: p.time))
        }
        // 날짜가 적힌 일정이 있는 사진에서, 시각만 있고 날짜 없는 줄은 대개 머리글이다
        if rows.contains(where: { $0.day != nil }) { rows.removeAll { $0.day == nil && $0.time != nil } }
        // 모델이 뭉뚱그린 표(시간표·통신문)는 글자 인식의 '날짜가 읽히는 줄'로 채운다 — 같은 날의 같은 일은 한 번만
        for l in ocr {
            let p = Parser.parse(l, now: now, calendar: calendar)
            guard let d = p.day, p.title.count >= 2, p.title.count <= 40 else { continue }
            let mine = content(p.title)
            // 같은 날 같은 시각이면 같은 일정의 '일시' 줄이다 (포스터의 날짜 줄). 시각이 없으면 이름이 겹치는지로 본다.
            let covered = rows.contains { r in
                guard r.day == d else { return false }
                if let t = p.time, r.time == t { return true }
                return overlap(mine, content(r.title)) >= 0.5 || overlap(content(r.title), mine) >= 0.5
            }
            if !covered { rows.append(Row(line: l, title: p.title, day: d, time: p.time)) }
        }
        // 표의 줄들로 채웠으면, 그 표 전체를 한 일정으로 본 모델의 줄(같은 날 · 제목이 다른 머리글)은 뺀다
        let fromTable = Set(rows.filter { r in ocr.contains(r.line) }.compactMap(\.day))
        if fromTable.count >= 2 {
            let snapshot = rows
            rows.removeAll { r in !ocr.contains(r.line) && r.day != nil && fromTable.contains(r.day!) && snapshot.filter { $0.day == r.day }.count > 1 }
        }
        return rows.map(\.line)
    }

    // MARK: 표에서 일정 읽기

    /// 표의 칸들(줄 × 칸의 글자) → 한 줄씩의 일정. 줄을 따라 읽으면 깨지는 두 꼴을 푼다:
    /// · 날짜가 머리줄에 가로로 놓인 표(주간표) → 열마다 "그 날짜 + 그 칸"
    /// · 날짜 칸이 비어 있는 줄(위와 같은 날) → 윗줄의 날짜를 이어 쓴다
    /// 날짜가 하나도 안 읽히는 표는 빈 배열 (그냥 글자 인식 줄을 쓰게).
    static func tableLines(_ grid: [[String]], now: Date = Date(), calendar: Calendar = .current) -> [String] {
        let rows = grid.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ") } }.filter { !$0.allSatisfy(\.isEmpty) }
        func day(_ s: String) -> DayKey? { s.isEmpty ? nil : Parser.parse(s, now: now, calendar: calendar).day }
        // 1) 머리줄에 날짜가 둘 이상 가로로
        if let h = rows.firstIndex(where: { r in r.filter { day($0) != nil }.count >= 2 && r.filter { day($0) != nil }.count * 2 >= r.filter { !$0.isEmpty }.count }),
           rows.count > h + 1, rows[(h + 1)...].allSatisfy({ r in r.filter { day($0) != nil }.count == 0 }) {
            var out: [String] = []
            for c in rows[h].indices where day(rows[h][c]) != nil {
                for r in rows[(h + 1)...] where c < r.count && !r[c].isEmpty { out.append(rows[h][c] + " " + r[c]) }
            }
            return out
        }
        // 2) 날짜 칸이 있는 표 (비면 윗줄의 날짜)
        let width = rows.map(\.count).max() ?? 0
        guard width >= 2, let dc = (0..<width).max(by: { a, b in
            rows.filter { a < $0.count && day($0[a]) != nil }.count < rows.filter { b < $0.count && day($0[b]) != nil }.count
        }), rows.filter({ dc < $0.count && day($0[dc]) != nil }).count >= 1 else { return [] }
        var out: [String] = [], last = ""
        for r in rows {
            let d = dc < r.count ? r[dc] : ""
            if day(d) != nil { last = d } else if !d.isEmpty { continue } // 날짜 칸에 날짜가 아닌 글(머리글 '날짜')이 있는 줄은 건너뛴다
            guard !last.isEmpty else { continue }
            let rest = r.enumerated().filter { $0.offset != dc && !$0.element.isEmpty }.map(\.element)
            guard !rest.isEmpty else { continue }
            out.append(last + " " + rest.joined(separator: " "))
        }
        return out
    }

    /// 모델이 글 끝에 칸 이름을 흘릴 때가 있다: "엄마한테 전화해야 돼 (now" → "엄마한테 전화해야 돼"
    static func stripBinTag(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*[\(\[\{<]?\s*\b(now|date|worry|drop)\b\s*[\)\]\}>]?\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*[\(\[]\s*$"#, with: "", options: .regularExpression)
    }

    /// AI 가 고른 칸을 다시 고를 때 (카드 하나): '버리기'는 망설이는 말이 있을 때만
    static func trustDrop(_ bin: DumpBin, text: String, rule: DumpBin) -> DumpBin {
        bin == .drop && !has(R.drop, text) ? rule : bin
    }

    /// 한 장 마무리 (규칙과 AI 공통): 날·띠·길이 제안과 이유. 길이는 사용자가 쓴 길이 → 낱말 짐작 → nil(설정 기본값).
    static func make(_ text: String, bin: DumpBin, parsed: Parsed, today: DayKey, now: Date,
                     parts: DayParts, calendar: Calendar, fromAI: Bool) -> DumpSuggestion {
        var day: DayKey? = nil, part: Part? = nil, duration: Int? = nil, proposed = false
        let nowPart = parts.part(at: minuteOfDay(now, calendar: calendar))
        switch bin {
        case .now:
            day = today
            part = parsed.day == today ? (parsed.part ?? nowPart) : nowPart
            duration = 5
        case .date:
            duration = parsed.duration ?? estimate(text)
            if let t = parsed.time { part = parts.part(at: t) } else { part = parsed.part }
            if parsed.later {
                day = nil
            } else if let d = parsed.day {
                day = d
            } else if let t = parsed.time {
                day = t > minuteOfDay(now, calendar: calendar) ? today : today.adding(days: 1, calendar: calendar)
            } else {
                proposed = true
                (day, part) = propose(text, part: part, today: today, now: now, parts: parts, calendar: calendar)
            }
        case .worry, .drop:
            break
        }
        let reason = isCrisis(text) ? crisisLine : self.reason(bin, day: day, part: part, time: parsed.time, proposed: proposed, today: today)
        return DumpSuggestion(text: text, bin: bin, day: day, part: part, duration: duration, reason: reason, fromAI: fromAI)
    }

    static func reason(_ bin: DumpBin, day: DayKey?, part: Part?, time: Int?, proposed: Bool, today: DayKey) -> String {
        switch bin {
        case .now: return "2분이면 끝날 것 같아. 바로 하면 머리에서 내려가."
        case .worry: return "지금 손쓸 수 있는 게 없어 보여. 걱정 시간에 다시 꺼내 줄게."
        case .drop: return "꼭 안 해도 되는 것 같아. 버리면 진짜 지워져."
        case .date:
            guard let day else { return "날짜는 나중에 정해도 돼. 나중에 함에 둘게." }
            let when = Fmt.day(day, today: today) + (time.map { " " + Fmt.spoken($0) } ?? part.map { " " + $0.name } ?? "")
            return proposed ? "언제 할지만 정하면 머리에서 내려가. \(when) 어때?" : "\(when)\(ro(when)) 둘게."
        }
    }

    // MARK: 첫 동작

    /// 2분 안에 몸으로 할 수 있는 첫 동작 (25자 이내)
    static func firstStep(for title: String) -> String { knownStep(for: title) ?? "필요한 것 하나 꺼내 두기" }

    /// 다듬어 둔 갈래(문서·전화·청소…)에 드는 일이면 그 첫 동작. 모르는 일이면 nil (→ AI 가 맡는다)
    static func knownStep(for title: String) -> String? {
        R.steps.first { has($0.0, title) }?.1
    }

    /// AI 첫 동작 검사: 한 줄 · 4~30자 · 한국어 · 조언 금지 낱말 없음 · 할 일을 그대로 되풀이한 것이 아님 ("여권 갱신" → "여권 갱신하기" 는 첫 동작이 아니다)
    static func cleanStep(_ s: String, title: String) -> String? {
        guard let line = s.split(whereSeparator: \.isNewline).first.map(String.init),
              var t = cleanSentence(line, max: 40) else { return nil }
        t = t.replacingOccurrences(of: #"^(?:첫\s*동작\s*[:：]|→|-)\s*"#, with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: ".。!").union(.whitespaces))
        guard (4...30).contains(t.count), !has(R.advice, t) else { return nil }
        if !title.isEmpty, letters(t).isSubset(of: letters(title).union(["하", "두"])) { return nil }
        return t
    }

    // MARK: 하루 열기 · 닫기 · 한 주 — 규칙 문장이 제품이다 (하네스에서 모델이 사실을 지어냈다: AI.md)

    static func brief(_ sheet: DaySheet, laterCount: Int, worryCount: Int) -> String {
        let minute = sheet.now?.minute
        let events = sheet.bands.flatMap(\.events).filter { e in !e.done && (minute == nil || (e.end ?? 0) > minute!) }
        let open = sheet.bands.filter { !$0.gone }.reduce(0) { $0 + $1.openTodos }
        if events.isEmpty && open == 0 {
            return laterCount > 0 ? "오늘은 비어 있어. 나중에 함에 \(laterCount)개가 있으니 하나만 골라도 돼." : "오늘은 비어 있어. 쉬어도 되는 날이야."
        }
        var first: String
        if let e = events.first {
            let what = "\(Fmt.spoken(e.time ?? 0)) ‘\(e.title)’"
            first = (sheet.isToday ? "다음은 " : "첫 약속은 ") + what + (open > 0 ? ", 남은 할 일은 \(open)개야." : josa(e.title, "이야.", "야."))
        } else {
            first = "약속은 없고 할 일 \(open)개가 남았어."
        }
        if let over = sheet.bands.first(where: { !$0.gone && $0.overflow > 0 }) {
            return first + " \(over.part.name)\(josa(over.part.name, "이", "가")) \(Fmt.dur(over.overflow)) 넘치니 하나는 미뤄도 돼."
        }
        if let fit = sheet.now?.fit { return first + " 지금은 ‘\(fit.title)’ \(Fmt.dur(fit.duration))이 딱 들어가." }
        if events.count > 1 { return first + " 약속은 모두 \(events.count)개야." }
        return first
    }

    static func closing(done: Int, moved: Int, dropped: Int, tomorrowFirst: String?) -> String {
        var s = done > 0 ? "오늘 \(done)개 끝냈어." : "끝낸 게 없어도 괜찮은 날이야."
        switch (moved > 0, dropped > 0) {
        case (true, true): s += " 남은 \(moved)개는 자리를 정했고 \(dropped)개는 내려놨어."
        case (true, false): s += " 남은 \(moved)개는 자리를 정했어."
        case (false, true): s += " \(dropped)개는 내려놨어."
        case (false, false): break
        }
        if let t = tomorrowFirst.map(tidy), !t.isEmpty { return s + " 내일은 ‘\(t)’부터 하면 돼." }
        return s + " 이제 머리는 쉬어도 돼."
    }

    static func weekly(_ s: WeekStats) -> String {
        var out = s.added > 0 || s.done > 0 ? "이번 주 \(s.added)개를 적고 \(s.done)개를 끝냈어." : "이번 주는 조용히 지나갔어."
        if let n = s.noiseDelta, n <= -0.5 { out += " 비우고 나면 머리 소음이 평균 \(one(-n))만큼 내려갔어." }
        else if let c = s.clarityDelta, c >= 0.5 { out += " 식히고 나면 맑기가 평균 \(one(c))만큼 올랐어." }
        else if let p = s.bestPart, s.done > 0 { out += " \(p.name)에 가장 많이 끝냈어." }
        return out + " " + weeklyTip(s)
    }

    /// 다음 주에 해 볼 작은 것 하나
    static func weeklyTip(_ s: WeekStats) -> String {
        if let r = s.estimateRatio, r >= 1.3 { return "다음 주엔 길이를 조금 넉넉히 잡아 봐." }
        if s.rests == 0 { return "다음 주엔 하루 한 번 1분 숨 고르기 어때?" }
        if s.closedDays < 3 { return "다음 주엔 자기 전에 하루 닫기를 두세 번만 해 봐." }
        if let p = s.bestPart { return "다음 주에도 어려운 일은 \(p.name)에 두어 봐." }
        return "다음 주도 지금처럼 하나씩이면 충분해."
    }

    // MARK: 걱정

    static let inHandsLine = "손댈 수 있는 게 하나 있어 보여. 이것만 하고 나머지는 걱정 시간에 보자."
    static let waitLine = "지금 손댈 수 있는 건 없어 보여. 걱정 시간에 다시 꺼내 보자."

    static func worry(_ text: String) -> WorryAdvice {
        if isCrisis(text) { return crisisAdvice() }
        if has(R.actionable, text) { return WorryAdvice(inMyHands: true, step: firstStep(for: text), line: inHandsLine, crisis: false) }
        return WorryAdvice(inMyHands: false, step: nil, line: waitLine, crisis: false)
    }

    /// AI 걱정 판단 검사: 한 걸음은 짧은 한국어 한 줄이어야 하고 조언 금지 영역(약·투자·법·남의 마음 바꾸기)이면 뺀다.
    /// 걸음이 없으면 '기다림'. 문장은 규칙 문장 (모델의 위로 문장은 하네스에서 뜬구름이었다: AI.md).
    static func finishWorry(inMyHands: Bool, step: String?) -> WorryAdvice {
        let s = inMyHands ? step.flatMap { cleanStep($0, title: "") } : nil
        return s.map { WorryAdvice(inMyHands: true, step: $0, line: inHandsLine, crisis: false) }
            ?? WorryAdvice(inMyHands: false, step: nil, line: waitLine, crisis: false)
    }

    // MARK: 한 줄 읽기 도우미

    /// Parser 가 시각을 못 찾았는데 남은 제목에 날짜·때 낱말이 있을 때만 도울 가치가 있다
    static func needsAssist(_ parsed: Parsed) -> Bool {
        parsed.time == nil && parsed.repeatRule == nil && !parsed.later && has(R.hint, parsed.title)
    }

    /// 규칙으로 고쳐 읽기: "세 시" → "3시", "크리스마스" → "12월 25일", "퇴근하고" → "저녁에", 설날·추석은 음력으로.
    static func assistParse(_ text: String, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> Parsed? {
        let base = Parser.parse(text, now: now, parts: parts, calendar: calendar)
        guard needsAssist(base) else { return nil }
        let fixed = normalizeTemporal(text, today: DayKey(now, calendar: calendar), calendar: calendar)
        guard fixed != text else { return nil }
        return better(Parser.parse(fixed, now: now, parts: parts, calendar: calendar), than: base)
    }

    /// AI 가 고쳐 쓴 때 낱말을 검사해서 적용한다: phrase 는 입력에 있어야 하고, canonical 은 Parser 가 읽을 수 있어야 한다.
    static func applyWhen(phrase: String, canonical: String, to text: String, now: Date, parts: DayParts = DayParts(), calendar: Calendar = .current) -> Parsed? {
        let base = Parser.parse(text, now: now, parts: parts, calendar: calendar)
        let p = phrase.trimmingCharacters(in: .whitespaces)
        let c = canonical.trimmingCharacters(in: .whitespaces)
        guard needsAssist(base), p.count >= 2, !c.isEmpty, let r = text.range(of: p), has(R.canonical, c) else { return nil }
        let today = DayKey(now, calendar: calendar)
        let out = Parser.parse(text.replacingCharacters(in: r, with: " \(c) "), now: now, parts: parts, calendar: calendar)
        // Parser 는 지난 날짜를 내년으로 넘긴다 — 달·명절을 말하지 않았는데 반년 넘게 뒤면 잘못 읽은 것
        let far = has(R.farOK, p) ? 400 : 200
        if let d = out.day, d < today || today.days(to: d, calendar: calendar) > far { return nil }
        return better(out, than: base)
    }

    // MARK: AI 글 검사

    /// 한두 문장 출력 다듬기: 따옴표·목록 기호·이모지 제거, 길이 제한, 한국어여야 함
    static func cleanSentence(_ s: String, max: Int) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"^[-•*·\d.)\s]+|^["“”'‘’「」]+|["“”'‘’「」]+$"#, with: "", options: .regularExpression)
        t = String(t.unicodeScalars.filter { !($0.properties.isEmojiPresentation || (0x1F000...0x1FFFF).contains($0.value)) })
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let hangul = t.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
        guard !t.isEmpty, t.count <= max, hangul * 2 >= t.filter({ $0.isLetter }).count, !has(R.hype, t) else { return nil }
        return t
    }

    // MARK: - 안쪽

    private static let punct = CharacterSet(charactersIn: ",.!?~…·;:\"'“”‘’()[]")

    static func tidy(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.!~…·;:")))
    }

    private static func sentences(_ line: String) -> [String] {
        line.replacingOccurrences(of: #"(?<=[^\d\s])[.!?;。]+(?=\s|$)|[!?;。]+"#, with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static let fillers: Set<String> = ["음", "으음", "음음", "흠", "어", "어어", "아", "아아", "에", "그", "저", "저기", "뭐", "막",
                                                "그러니까", "그니까", "일단", "아무튼", "암튼", "있잖아", "그래서", "근데", "그리고",
                                                "뭐야", "뭐냐", "뭐더라", "뭐였지", "뭐지", "그거"]

    private static func trimFillers(_ words: [String]) -> [String] {
        var w = words
        while let f = w.first, fillers.contains(f.trimmingCharacters(in: punct)) { w.removeFirst() }
        while let l = w.last, fillers.contains(l.trimmingCharacters(in: punct)) { w.removeLast() }
        return w
    }

    /// 앞 줄을 끊는 이음말: 그리고 · 그다음에 · 근데 · 아 맞다 · 또 … (몇 낱말인지)
    private static func markerLength(_ words: [String], at i: Int, inClause: Bool) -> Int? {
        let w = words[i].trimmingCharacters(in: punct)
        let next = i + 1 < words.count ? words[i + 1].trimmingCharacters(in: punct) : ""
        if ["그리고", "그리구", "그다음", "그다음에", "그담에", "그러고"].contains(w) { return ["나서", "또"].contains(next) ? 2 : 1 }
        if ["근데", "그런데", "아참", "아맞다", "그리고요", "그래서", "그래도", "그러니까"].contains(w) { return 1 }
        if w == "그" && (next == "다음에" || next == "다음") { return 2 }
        if w == "아" && ["맞다", "참", "그리고", "그리고요"].contains(next) { return 2 }
        // '또'는 앞말이 맺어졌을 때만 새 줄이다 ("허리 또 아프면"은 한 덩어리)
        if w == "또" && inClause && i + 1 < words.count, i > 0,
           ["고", "돼", "해", "기", "지", "다", "요", "함", "야", "어"].contains(where: { words[i - 1].trimmingCharacters(in: punct).hasSuffix($0) }) { return 1 }
        if ["일단", "우선", "이러다", "이러다가", "그냥"].contains(w) && inClause && i + 1 < words.count { return 1 }
        return nil
    }

    private static let people: Set<String> = ["엄마", "아빠", "친구", "동생", "형", "누나", "언니", "오빠", "남편", "아내", "와이프", "남친", "여친", "애인",
                                               "팀장님", "선배", "후배", "동기", "교수님", "선생님", "사장님", "부장님", "과장님", "할머니", "할아버지", "이모",
                                               "삼촌", "고모", "아들", "딸", "애들", "가족", "부모님", "누구"]
    private static let verbalNouns: Set<String> = ["전화", "통화", "운동", "공부", "정리", "청소", "연락", "준비", "예약", "신청", "확인", "출근", "퇴근",
                                                    "등록", "결제", "주문", "취소", "제출", "작성", "수정", "검토", "회의", "상담", "세탁", "산책", "요리",
                                                    "설거지", "빨래", "샤워", "숙제", "복습", "예습", "연습", "독서", "명상", "답장", "송금", "입금", "이체",
                                                    "충전", "환불", "반품", "교환", "수리", "점검", "검사", "진료", "이사", "포장", "발송", "인쇄", "정산",
                                                    "발표", "마감", "신고", "결정", "고민", "공유", "설치", "가입", "해지", "외출", "쇼핑", "세차", "납부",
                                                    "요청", "문의", "부탁", "방문", "장보기", "스트레칭", "출발", "업로드", "기획", "분석", "백업"]
    private static let nounGo: Set<String> = ["광고", "창고", "최고", "재고", "참고", "원고", "경고", "신고", "수고", "금고", "잔고", "냉장고", "공고",
                                               "회고", "기고", "초고", "노고", "숙고", "탈고", "투고", "퇴고", "고고"]

    /// 줄을 끊는 이음 어미면 그 낱말을 끝맺은 꼴로 바꿔 돌려준다. 끊지 않으면 nil.
    private static func connective(_ w: String, prev: String?, next: String, alone: Bool) -> String? {
        let n = next.trimmingCharacters(in: punct)
        if has(R.aux, n) { return nil }                                    // 하고 싶어 · 하고 있어 · 하고 나서
        if let p = prev?.trimmingCharacters(in: punct), p.hasSuffix("야") {  // 써야 되고 → 써야 돼
            if ["되고", "돼고", "되구", "되는데", "돼는데"].contains(w) { return "돼" }
            if ["하고", "하구", "하는데"].contains(w) { return "해" }
        }
        if ["않고", "말고"].contains(w) || has(R.quoteEnd, w) { return nil } // 하지 않고 · 커피 말고 · 하라고 · 하려고
        if ["하고", "하구"].contains(w), prev?.hasSuffix("기도") == true { return "해" }  // 해 볼까 싶기도 하고 → 싶기도 해
        if w == "없고" { return "없어" }
        if w == "있고" { return "있어" }
        if w.hasSuffix("하고") || w.hasSuffix("하구") {
            let stem = String(w.dropLast(2))
            if stem.isEmpty { return "하기" }                               // 운동 하고
            if people.contains(stem) || has(R.together, n) { return nil }  // 엄마하고 통화 · 친구하고 밥
            if alone && !verbalNouns.contains(stem) { return nil }         // 우유하고 계란 사기
            return stem + "하기"
        }
        guard w.hasSuffix("고"), w.count >= 2, !nounGo.contains(w) else { return nil }
        if w.hasSuffix("사고") && w.count > 2 { return nil }                // 교통사고
        if w == "보고", has(R.reportNext, n) { return nil }                 // 주간 보고 올리기
        let stem = String(w.dropLast())
        if let last = stem.unicodeScalars.last, jong(last) == 20 { return stem + "어" } // 했고 → 했어
        // 받침 있는 낱말 + 이고 는 대개 '이다' (고민 중이고 → 고민 중이야). 줄이고 · 먹이고 같은 움직씨는 뺀다
        if stem.hasSuffix("이"), let before = stem.dropLast().unicodeScalars.last, (jong(before) ?? 0) > 0,
           !["줄", "먹", "붙", "높", "늘", "끓", "죽", "속", "녹", "숨", "섞", "깎", "꺾"].contains(String(stem.dropLast().suffix(1))) {
            return stem + "야"
        }
        return stem + "기"                                                   // 사고 → 사기, 보내고 → 보내기
    }

    /// 날짜를 정하지 않은 '날짜 정하기' 카드에 붙일 때 (v4 Sorter.when + 띠)
    private static func propose(_ text: String, part: Part?, today: DayKey, now: Date, parts: DayParts, calendar: Calendar) -> (DayKey, Part) {
        let m = minuteOfDay(now, calendar: calendar)
        if let p = part { return (parts.range(p).upperBound > m ? today : today.adding(days: 1, calendar: calendar), p) }
        if has(R.nextMonth, text), let d = calendar.date(byAdding: .month, value: 1, to: today.date(calendar: calendar)) {
            let k = DayKey(d, calendar: calendar)
            return (DayKey(y: k.y, m: k.m, d: 1), .morning)
        }
        return (today.adding(days: 1, calendar: calendar), .morning)
    }

    /// 길이 짐작 (분). 모르면 nil → 설정의 기본 길이
    private static func estimate(_ text: String) -> Int? {
        for (re, m) in R.durations where has(re, text) { return m }
        return nil
    }

    /// AI 카드의 날짜·시각 낱말이 입력에 정말 있었나 (제목 밖으로 빠진 낱말이 원문에 있어야 한다)
    private static func temporalWordsGrounded(_ text: String, title: String, in raw: String) -> Bool {
        let flat = raw.filter { !$0.isWhitespace }
        let kept = Set(title.split(separator: " ").map(String.init))
        let removed = text.split(separator: " ").map(String.init).filter { !kept.contains($0) }
        return removed.allSatisfy { w in
            let core = w.replacingOccurrences(of: #"(에는|에|엔|까지|부터|쯤|은|는|도)$"#, with: "", options: .regularExpression)
            return core.isEmpty || flat.contains(core)
        }
    }

    /// 날·시각을 더 많이 읽은 쪽. 아무것도 못 더 읽었으면 nil.
    private static func better(_ p: Parsed, than base: Parsed) -> Parsed? {
        let gained = (p.time != nil && base.time == nil) || (p.day != nil && p.day != base.day) || (p.part != nil && base.part == nil)
        return gained ? p : nil
    }

    static func normalizeTemporal(_ text: String, today: DayKey, calendar: Calendar) -> String {
        var s = " " + text + " "
        func sub(_ re: NSRegularExpression, _ f: ([String]) -> String?) {
            let ns = s as NSString
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)).reversed() {
                let g = (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
                if let r = f(g) { s = (s as NSString).replacingCharacters(in: m.range, with: " " + r + " ") }
            }
        }
        let natives = ["한": 1, "두": 2, "세": 3, "네": 4, "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10, "열한": 11, "열두": 12]
        sub(R.nativeHour) { g in natives[g[1]].map { "\($0)시" } }
        sub(R.tenDays) { g in g[1] == "열흘" ? "10일" : "15일" }
        func md(_ k: DayKey) -> String { "\(k.m)월 \(k.d)일" }
        func monthEnd(_ add: Int) -> DayKey? {
            guard let d = calendar.date(byAdding: .month, value: add, to: DayKey(y: today.y, m: today.m, d: 1).date(calendar: calendar)),
                  let n = calendar.range(of: .day, in: .month, for: d)?.count else { return nil }
            let k = DayKey(d, calendar: calendar)
            return DayKey(y: k.y, m: k.m, d: n)
        }
        sub(R.nthWeekday) { g in nthWeekday(g, today: today, calendar: calendar).map(md) }
        sub(R.monthEndNext) { _ in monthEnd(1).map(md) }
        sub(R.nextMonthDay) { g in monthEnd(1).flatMap { k in Int(g[1]).flatMap { $0 <= k.d ? "\(k.m)월 \($0)일" : nil } } }
        sub(R.monthEnd) { _ in monthEnd(0).map(md) }
        sub(R.monthWithin) { _ in monthEnd(0).map(md) }
        sub(R.xun) { g in
            let d = ["초순": 5, "중순": 15, "하순": 25][g[2]] ?? 15
            let next = g[1].hasPrefix("다음") || g[1].hasPrefix("담") || (g[1].isEmpty && today.d > d)
            return monthEnd(next ? 1 : 0).map { "\($0.m)월 \(d)일" }
        }
        sub(R.monthStartNext) { _ in monthEnd(1).map { "\($0.m)월 1일" } }
        sub(R.yearEnd) { _ in "12월 31일" }
        for (re, date) in R.holidays { sub(re) { _ in date } }
        sub(R.lunar) { g in lunar(g[1].hasPrefix("추석") || g[1].hasPrefix("한가위") ? (8, 15) : (1, 1), from: today, calendar: calendar).map(md) }
        sub(R.evening) { _ in "저녁에" }
        sub(R.noonish) { _ in "낮에" }
        sub(R.morning) { _ in "아침에" }
        sub(R.soon) { _ in "오늘" }
        sub(R.thisWeek) { _ in (2...5).contains(today.weekday(calendar: calendar)) ? "이번 주 금요일" : "오늘" }
        sub(R.beforeWeekend) { _ in "금요일" }
        return s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// 다가오는 음력 month/day 의 양력 날짜 (설날 1/1 · 추석 8/15)
    private static func lunar(_ md: (Int, Int), from today: DayKey, calendar: Calendar) -> DayKey? {
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = calendar.timeZone
        var d = today.date(calendar: calendar)
        for _ in 0..<400 {
            let c = chinese.dateComponents([.month, .day], from: d)
            if c.month == md.0, c.day == md.1, c.isLeapMonth != true { return DayKey(d, calendar: calendar) }
            guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { return nil }
            d = n
        }
        return nil
    }

    /// (이번 달|다음 달) 둘째 주 화요일 → 그달 두 번째 화요일. 요일이 없으면 그 주의 첫날 (둘째 주 → 8일, 마지막 주 → 말일 6일 전)
    private static func nthWeekday(_ g: [String], today: DayKey, calendar: Calendar) -> DayKey? {
        let wd = g[3].isEmpty ? nil : Array("일월화수목금토").firstIndex(of: Character(g[3])).map { $0 + 1 }
        let nth = ["첫째": 1, "첫": 1, "둘째": 2, "셋째": 3, "넷째": 4, "다섯째": 5, "마지막": -1][g[2]] ?? 1
        func find(_ add: Int) -> DayKey? {
            guard let first = calendar.date(byAdding: .month, value: add, to: DayKey(y: today.y, m: today.m, d: 1).date(calendar: calendar)) else { return nil }
            let k = DayKey(first, calendar: calendar)
            let month = (0..<31).map { k.adding(days: $0, calendar: calendar) }.filter { $0.m == k.m }
            guard let wd else { return nth == -1 ? month[max(0, month.count - 7)] : month.count >= (nth - 1) * 7 + 1 ? month[(nth - 1) * 7] : nil }
            let days = month.filter { $0.weekday(calendar: calendar) == wd }
            return nth == -1 ? days.last : (nth <= days.count ? days[nth - 1] : nil)
        }
        if !g[1].isEmpty { return find(g[1].hasPrefix("이번") || g[1].hasPrefix("이달") ? 0 : 1) }
        if let k = find(0), k >= today { return k }
        return find(1)
    }

    // MARK: 글자 도우미

    private static func has(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    /// 한글 음절 집합. 줄어든 꼴은 밑꼴로 (써→쓰 · 마셔→마시 · 돼→되) — '써야 돼'와 '쓰기'를 같은 말로 본다
    private static func letters(_ s: String) -> Set<Character> {
        Set(s.compactMap { c -> Character? in
            guard let u = c.unicodeScalars.first, (0xAC00...0xD7A3).contains(u.value) else { return nil }
            return contracted[c] ?? c
        }).subtracting(["기", "요", "다"])
    }

    /// 뜻을 실은 음절만 (조사·어미에 흔한 음절은 뺀다) — AI 가 군말을 덜어 낸 줄도 원문 조각과 견줄 수 있게
    private static func content(_ s: String) -> Set<Character> { letters(s).subtracting(grammar) }

    private static let contracted: [Character: Character] = ["써": "쓰", "봐": "보", "해": "하", "돼": "되", "줘": "주", "둬": "두", "꿔": "꾸",
                                                               "셔": "시", "려": "리", "쳐": "치", "겨": "기", "져": "지", "혀": "히", "펴": "피",
                                                               "켜": "키", "껴": "끼", "놔": "놓"]

    private static let grammar: Set<Character> = ["이", "가", "을", "를", "은", "는", "에", "의", "도", "고", "하", "해", "했", "한", "할", "야", "돼", "되",
                                                   "된", "서", "지", "기", "요", "다", "좀", "게", "거", "것", "수", "데", "면", "께", "랑", "와", "과",
                                                   "로", "으", "나", "니", "만", "까", "어", "아", "네", "죠", "음"]

    private static func overlap(_ a: Set<Character>, _ b: Set<Character>) -> Double {
        a.isEmpty ? 0 : Double(a.intersection(b).count) / Double(a.count)
    }

    /// 받침 번호 (0 없음 · 8 ㄹ · 20 ㅆ)
    private static func jong(_ u: Unicode.Scalar) -> Int? {
        (0xAC00...0xD7A3).contains(u.value) ? Int(u.value - 0xAC00) % 28 : nil
    }

    /// '로/으로' — 마지막 한글 받침이 없거나 ㄹ이면 '로'
    private static func ro(_ s: String) -> String {
        guard let u = s.unicodeScalars.last(where: { jong($0) != nil }), let j = jong(u) else { return "로" }
        return j == 0 || j == 8 ? "로" : "으로"
    }

    /// 받침에 따라 조사 고르기: josa("치과", "이야", "야") → "야"
    private static func josa(_ s: String, _ withFinal: String, _ without: String) -> String {
        guard let u = s.unicodeScalars.last(where: { jong($0) != nil }), let j = jong(u) else { return without }
        return j == 0 ? without : withFinal
    }

    private static func one(_ x: Double) -> String {
        let r = (x * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

}

// MARK: - 정규식 (한 번만 만든다)

private enum R {
    static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }

    static let crisis = rx(#"죽고\s*싶|죽어\s*버리고|자살|자해|극단적\s*(?:선택|생각)|목숨을?\s*끊|목\s*매|뛰어\s*내리고|투신|유서|손목을?\s*긋|살기\s*싫|살고\s*싶지\s*않|사라지고\s*싶|없어지고\s*싶|죽는\s*게\s*나|죽으면\s*편|살\s*이유가?\s*없|삶을?\s*끝내|생을?\s*마감"#)

    // v4 Sorter: 걱정 · 버리기 · 지금 (건강·미래 같은 넓은 낱말은 빼고 걱정의 말투를 본다)
    static let worry = rx(#"어떡|어쩌|어떻게\s*하지|걱정|불안|두렵|무섭|무서|아무것도\s*하기\s*싫|겁나|초조|혹시|될까|안\s*되면|못\s*하면|망하|망했|망칠|큰일|싫어하|미워하|눈치|후회|왜\s*그랬|괜찮을까|잘리|떨어지면|떨어질까|까\s*봐|할까\s*봐"#)
    static let drop = rx(#"[가-힣]지\s*(?:말지|고민)|고민\s*중|(?:할|갈|살|볼|닐|쓸|둘|울)까[.?!]?$|됐고|됐어$|먹고\s*싶|고\s*싶[다어][.!]?$|(?:킬|낼|줄)까[.?!]?$|할까\s*말까|말까|[아어여워해]\s*볼까|볼까\s*싶|할까\s*(?:고민|생각)|언젠가|살까|사고\s*싶|갖고\s*싶|면\s*좋겠|굳이|안\s*해도\s*되"#)
    static let quick = rx(#"전화|통화|답장|회신|메일|문자|카톡|DM|연락|보내|입금|송금|이체|납부|결제|충전|예약|신청|주문|취소|확인|물어|버리|버려|쓰레기|물\S*\s*(?:좀\s*)?마[시셔]|약\s*(?:챙겨\s*)?먹|알람|메모|공유|해지|과태료|내야|(?:^|\s)내기|올리기"#)
    static let heavy = rx(#"보고서|기획서|제안서|과제|레포트|논문|자소서|자기소개서|이력서|발표|공부|시험|청소|정리|이사|준비|작성|만들|기획|분석|연습|운동|장보기|장\s*봐|요리|빨래|설거지|세탁|세차|수리|고쳐|고치|갈아|맡겨|맡기|사야|사\s*가|찍어|병원|가야|다녀|산책"#)
    /// 걱정을 이유로 댄 말투 ("~까 봐 …해야 함")
    static let softWorry = rx(#"까\s*봐|혹시|안\s*되면|못\s*하면"#)
    /// 할 일로 맺은 줄
    static let duty = rx(#"야\s*(?:돼|해|함|한다|된다|지|겠다)[.!]?$|기[.!]?$|것[.!]?$"#)
    /// 걱정이라고 볼 또렷한 말투 (모델이 다른 칸을 골라도 걱정으로)
    static let strongWorry = rx(#"어떡|어쩌|까\s*봐|걱정(?:이|돼|된)|불안|무서|무섭|겁나|괜찮을까"#)
    static let nextMonth = rx(#"다음\s*달|담\s*달"#)

    static let aux = rx(#"^(?:싶|있|없|나서|나면|나니|난|말|계시|계셔)"#)
    static let together = rx(#"^(?:통화|얘기|이야기|만나|만날|약속|같이|상의|대화|놀|밥|점심|저녁|싸우|싸웠|화해|연락|여행|영화|데이트|회의|미팅|술)"#)
    static let quoteEnd = rx(#"(?:라고|다고|자고|냐고|려고|으라고)$"#)
    static let reportNext = rx(#"^(?:서|올리|쓰|작성|드리|하|준비|자료)"#)

    static let durations: [(NSRegularExpression, Int)] = [
        (rx(#"보고서|기획서|제안서|과제|레포트|논문|자소서|발표|공부|시험|병원|치과|미용실|은행|관공서|주민센터|운동|헬스|러닝|장보기"#), 60),
        (rx(#"청소|정리|빨래|설거지|요리|서류"#), 30),
        (rx(#"전화|통화|답장|회신|메일|문자|카톡|연락|예약|신청|주문|입금|송금|이체|결제"#), 10),
    ]

    /// 다듬어 둔 첫 동작. 갈래 낱말은 좁게 — 넓으면 엉뚱하게 걸린다 ("책상 정리" → 책 읽기, "이사 업체 알아보기" → 상자 펴기). 안 걸리면 AI.
    static let steps: [(NSRegularExpression, String)] = [
        (rx(#"예약"#), "예약 화면 열어 두기"),
        (rx(#"전화|통화"#), "연락처 열고 이름 찾아 두기"),
        (rx(#"답장|회신|메일"#), "메일 열고 첫 줄만 쓰기"),
        (rx(#"카톡|문자|DM|메시지|연락"#), "대화창 열고 첫 마디 쓰기"),
        (rx(#"발표|PPT|ppt|슬라이드"#), "슬라이드 열고 첫 장 제목 쓰기"),
        (rx(#"보고서|기획서|제안서|문서|레포트|논문|원고|자소서|자기소개서|과제|숙제|회의록"#), "문서 열고 제목만 쓰기"),
        (rx(#"공부|시험|복습|예습"#), "책 펴고 첫 쪽만 읽기"),
        (rx(#"책\s*읽|독서"#), "책 펴서 한 쪽 읽기"),
        (rx(#"빨래\s*개|옷\s*개"#), "옷 한 벌만 개기"),
        (rx(#"빨래"#), "빨래를 세탁기에 넣기"),
        (rx(#"설거지"#), "그릇 하나만 씻기"),
        (rx(#"운동|헬스|러닝|달리기|요가|스트레칭|산책"#), "운동화 꺼내 신기"),
        (rx(#"장보기|장\s*보|마트"#), "살 것 세 개만 메모하기"),
        (rx(#"병원|치과|진료|검진"#), "병원 번호 찾아 두기"),
        (rx(#"세금|연말정산|종합소득세|종소세"#), "홈택스 열어 두기"),
        (rx(#"은행|입금|송금|이체|납부|공과금|월세|카드값|통장"#), "은행 앱 열기"),
        (rx(#"택배\s*(?:보내|부치)|반품|발송|소포"#), "보낼 물건 문 앞에 두기"),
        (rx(#"서류|제출|접수"#), "필요한 서류 이름 적기"),
        (rx(#"이삿짐|짐\s*싸"#), "상자 하나 펴 두기"),
        (rx(#"요리"#), "재료 하나 꺼내 놓기"),
        (rx(#"청소|정리|치우"#), "눈앞의 물건 하나 제자리에 두기"),
    ]

    static let actionable = rx(#"시험|면접|발표|마감|제출|과제|보고서|숙제|공부|준비|연락|답장|전화|예약|신청|검진|서류"#)
    /// 걱정 답에 들어가면 안 되는 조언 (약 · 투자 · 법)
    static let advice = rx(#"복용|처방|진단|약을|약은|투자|매수|매도|주식|코인|대출|소송|고소|변호사|합의금|긍정적인\s*말|칭찬하기|잘\s*보이"#)
    static let hype = rx(#"화이팅|파이팅|대박|최고야|힘내|생산성|반드시|무조건"#)

    // 한 줄 읽기 도우미: Parser 가 못 읽는 때 낱말
    static let hint = rx(#"(?:열한|열두|다섯|여섯|일곱|여덟|아홉|한|두|세|네|열)\s*시(?!간)|열흘|보름|월말|월초|말일|연말(?!\s*정산)|이번\s*달|이달|다음\s*달|담\s*달|이번\s*주|크리스마스|성탄|(?<![가-힣])이브|설날|설\s*연휴|구정|추석|한가위|어린이날|어버이날|스승의\s*날|한글날|광복절|삼일절|현충일|개천절|빼빼로|발렌타인|밸런타인|화이트\s*데이|할로윈|핼러윈|신정|새해|퇴근|출근|(?:아침|점심|저녁)\s*먹고|자기\s*전|잠들기\s*전|일어나서|이따가?(?![가-힣])|좀\s*있다|(?:수업|학교|일)\s*끝나고|주말\s*전|째\s*주|마지막\s*주|중순|초순|하순"#)
    static let nativeHour = rx(#"(?<![가-힣])(열한|열두|다섯|여섯|일곱|여덟|아홉|한|두|세|네|열)\s*시(?!간)"#)
    static let tenDays = rx(#"(열흘|보름)\s*(?=뒤|후)"#)
    static let monthEndNext = rx(#"(?:다음|담)\s*달\s*(?:말|말일|마지막\s*날)"#)
    static let monthEnd = rx(#"월말|이번\s*달\s*(?:말|말일|마지막\s*날)|이달\s*(?:말|말일)|말일"#)
    static let monthStartNext = rx(#"(?:다음|담)\s*달(?!\s*(?:말|중순|하순|초순))\s*초?|월초"#)
    static let monthWithin = rx(#"(?:이번\s*달|이달)\s*(?:안에|중에?|까지|내로)"#)
    static let xun = rx(#"(?:(이번\s*달|이달|다음\s*달|담\s*달)\s*)?(초순|중순|하순)"#)
    static let yearEnd = rx(#"연말(?!\s*정산)"#)
    static let nextMonthDay = rx(#"(?:다음|담)\s*달\s*(\d{1,2})\s*일"#)
    static let holidays: [(NSRegularExpression, String)] = [
        (rx(#"(?:크리스마스|성탄)\s*이브|(?<![가-힣])이브"#), "12월 24일"), (rx(#"크리스마스|성탄절|성탄"#), "12월 25일"),
        (rx(#"어린이날"#), "5월 5일"), (rx(#"어버이날"#), "5월 8일"), (rx(#"스승의\s*날"#), "5월 15일"),
        (rx(#"한글날"#), "10월 9일"), (rx(#"광복절"#), "8월 15일"), (rx(#"삼일절"#), "3월 1일"),
        (rx(#"현충일"#), "6월 6일"), (rx(#"개천절"#), "10월 3일"), (rx(#"빼빼로\s*데이"#), "11월 11일"),
        (rx(#"발렌타인\s*데이|밸런타인\s*데이|발렌타인|밸런타인"#), "2월 14일"), (rx(#"화이트\s*데이"#), "3월 14일"),
        (rx(#"할로윈|핼러윈"#), "10월 31일"), (rx(#"신정|새해\s*첫날|새해"#), "1월 1일"),
    ]
    static let lunar = rx(#"(설날|설\s*연휴|구정|추석|한가위)"#)
    static let nthWeekday = rx(#"(?:(이번\s*달|이달|다음\s*달|담\s*달)\s*)?(첫째|첫|둘째|셋째|넷째|다섯째|마지막)\s*주(?:\s*([월화수목금토일])요일)?"#)
    static let evening = rx(#"퇴근\s*(?:하고|하면|후에?|길에?)?|저녁\s*먹고|자기\s*전에?|잠들기\s*전에?|일\s*끝나고"#)
    static let noonish = rx(#"점심\s*(?:먹고|후에?|시간에?)|수업\s*끝나고|학교\s*끝나고"#)
    static let morning = rx(#"출근\s*(?:전에?|하자마자|하면)|일어나서|아침\s*먹고|등교\s*전에?"#)
    static let soon = rx(#"이따가?(?![가-힣])|좀\s*있다가?"#)
    static let thisWeek = rx(#"이번\s*주(?!\s*[월화수목금토일]요일|말)\s*(?:안에|중에?|까지|내로)?"#)
    static let beforeWeekend = rx(#"주말\s*전에?"#)
    static let farOK = rx(#"내년|\d+\s*월|설|추석|한가위|크리스마스|성탄|날"#)
    /// AI 가 고쳐 쓴 때 낱말이 따라야 하는 꼴
    static let canonical = rx(#"^\s*(?:오늘|내일|모레|\d{1,2}월\s*\d{1,2}일|(?:이번|다음)\s*주\s*[월화수목금토일]요일|[월화수목금토일]요일)?\s*(?:아침|낮|저녁|밤)?\s*(?:(?:오전|오후)\s*)?(?:\d{1,2}시(?:\s*(?:반|\d{1,2}분))?)?\s*$"#)

}
