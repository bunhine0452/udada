import Foundation

// 화면 그대로: 보고 있던 화면(스크린샷)에서 받은 약속이나 챙길 일정을 찾는다.
// 글자 인식이 준 조각의 자리로 '받은 말'과 '내가 한 말'을 가르고, 받은 말의 가장 최근 제안을 답장 규칙에 넘긴다.
// 대화가 아니면(예약 안내 · 공지 · 포스터) 챙길 줄만 뽑는다. 모델 없이 Foundation 만 쓴다.

/// 글자 조각 하나. 자리는 화면 크기에 대한 비율(0~1), top 은 위에서부터.
struct ScreenPiece: Equatable, Sendable {
    var text: String
    var minX: Double
    var maxX: Double
    var top: Double
}

enum ScreenRead: Equatable, Sendable {
    /// 받은 약속 제안 (답장 규칙에 넘길 글)
    case offer(String)
    /// 챙길 일정 · 할 일 줄
    case lines([String])
    case nothing
}

enum ScreenRules {
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

    /// 말풍선 옆의 보낸 시각 · 안 읽은 수 · 날짜 가름줄 · 입력칸 글 — 약속의 때로 읽히면 안 되는 것들
    private static let stamp = rx("^(오전|오후)\\s?\\d{1,2}:\\d{2}$|^\\d{1,2}:\\d{2}$|^\\d{1,3}$|^\\d{4}년\\s?\\d{1,2}월\\s?\\d{1,2}일|^(메시지|메시지 입력|iMessage|문자 메시지|전송|읽음)$")

    /// 위아래 띠(상태 막대 · 방 이름 · 입력칸)와 시각 도장을 뺀 조각을 위에서 아래로
    static func body(_ pieces: [ScreenPiece]) -> [ScreenPiece] {
        pieces
            .map { p in var q = p; q.text = p.text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines); return q }
            .filter { $0.top > 0.09 && $0.top < 0.90 && $0.text.count >= 2 && !has(stamp, $0.text) }
            .sorted { $0.top < $1.top }
    }

    /// 오른쪽에 붙은 말풍선은 내가 한 말
    static func isMine(_ p: ScreenPiece) -> Bool { p.minX > 0.38 && p.maxX > 0.80 }

    /// 받은 말만, 위에서 아래로
    static func theirs(_ pieces: [ScreenPiece]) -> [String] { body(pieces).filter { !isMine($0) }.map(\.text) }

    static func read(_ pieces: [ScreenPiece], now: Date, calendar: Calendar = .current) -> ScreenRead {
        let all = body(pieces)
        let got = all.filter { !isMine($0) }.map(\.text)
        // 가장 최근 제안부터 거슬러 올라간다. 날과 시각을 두 말풍선에 나눠 말했으면 이어 읽는다.
        let from = max(0, got.count - 6)
        var i = got.count - 1
        while i >= from {
            let single = ReplyRules.offer(from: got[i], now: now, calendar: calendar) != nil
            if i > 0 {
                // 이 말풍선에 날이 없고 바로 앞 말풍선에 날이 있으면 둘을 이어 읽는다 ("금요일에 시간 돼?" + "7시에 홍대 어때")
                let two = got[i - 1] + " " + got[i]
                let dayless = Parser.parse(got[i], now: now, calendar: calendar).day == nil
                let before = Parser.parse(got[i - 1], now: now, calendar: calendar).day != nil
                if (!single || (dayless && before)), ReplyRules.offer(from: two, now: now, calendar: calendar) != nil { return .offer(two) }
            }
            if single { return .offer(got[i]) }
            i -= 1
        }
        // 제안이 없으면 화면에 적힌 일정을 그대로 챙긴다. 나와의 채팅처럼 내가 적어 둔 것도 일정이다.
        let lines = events(all.map(\.text), now: now, calendar: calendar)
        return lines.isEmpty ? .nothing : .lines(lines)
    }

    /// 글로 받은 것(문자 · 메일 · 복사한 글)도 같은 갈래로
    static func read(text: String, now: Date, calendar: Calendar = .current) -> ScreenRead {
        let t = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        if ReplyRules.offer(from: t, now: now, calendar: calendar) != nil { return .offer(t) }
        guard !isJunk(t) else { return .nothing }
        let lines = events(t.components(separatedBy: .newlines), now: now, calendar: calendar)
        return lines.isEmpty ? .nothing : .lines(lines)
    }

    /// 화면의 껍데기: 파일 카드(용량 · 유효기간 · 파일 이름), 날짜 가름줄, 숫자뿐인 줄
    private static let chrome = rx("용량|[0-9]\\s?(MB|KB|GB|TB)\\b|^유효\\s?기간|만료일|\\.(pdf|jpe?g|png|zip|hwp|docx?|xlsx?|pptx?|mp4|mov)\\b|^\\d{4}년\\s?\\d{1,2}월\\s?\\d{1,2}일\\s?.요일\\s?[>›]?$")
    private static let weekday = rx("[월화수목금토일]요일|오전|오후|[>›<~·]")

    /// 일정으로 넣어도 되는 줄만: 때가 읽히고, 이름이 있고, 지난 날이 아니고, 화면 껍데기가 아닌 것
    /// strict 가 아니면 때가 없는 줄(손으로 쓴 할 일 목록 같은)은 그대로 둔다.
    static func keep(_ lines: [String], strict: Bool = true, now: Date, calendar: Calendar = .current) -> [String] {
        let today = DayKey(now, calendar: calendar)
        var seen = Set<String>(), out: [String] = []
        for raw in lines {
            let l = raw.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
            guard l.count >= 3, !has(chrome, l), !isJunk(l) else { continue }
            let p = Parser.parse(l, now: now, calendar: calendar)
            guard p.day != nil || p.time != nil else {
                if !strict, seen.insert(l).inserted { out.append(l) }
                continue
            }
            if let d = p.day, d < today { continue }
            let name = weekday.stringByReplacingMatches(in: p.title, range: NSRange(p.title.startIndex..., in: p.title), withTemplate: "")
            guard name.filter({ $0.isLetter }).count >= 2 else { continue }
            let key = "\(p.day.map { "\($0)" } ?? "")|\(p.time ?? -1)|\(name.filter { $0.isLetter || $0.isNumber })"
            if seen.insert(key).inserted { out.append(l) }
        }
        return out
    }

    /// 읽은 줄들 → 챙길 일정 줄 (받은 글 규칙이 고르고, 위의 검사로 거른다)
    static func events(_ lines: [String], now: Date, calendar: Calendar = .current) -> [String] {
        let picked = CaptureRules.lines(lines.joined(separator: "\n"), now: now, calendar: calendar)
        return keep(picked, now: now, calendar: calendar)
    }

    /// 줄 → 넣을 일. 이미 같은 이름 · 같은 날 · 같은 시각으로 있는 것은 뺀다.
    static func items(from lines: [String], data: AppData, now: Date, calendar: Calendar = .current) -> [Item] {
        let today = DayKey(now, calendar: calendar)
        var out: [Item] = []
        for l in lines {
            let p = Parser.parse(l, now: now, calendar: calendar)
            let title = p.title.trimmingCharacters(in: CharacterSet(charactersIn: " ·,.~")).isEmpty ? l : p.title
            let day = p.day ?? today
            let part = p.time.map { data.settings.parts.part(at: $0) } ?? p.part ?? .afternoon
            let item = Item(title: String(title.prefix(60)), day: day, part: part, time: p.time, duration: p.duration ?? (p.time == nil ? 30 : 60), created: now)
            let same: (Item) -> Bool = { $0.title == item.title && $0.day == item.day && $0.time == item.time }
            if !data.items.contains(where: same), !out.contains(where: same) { out.append(item) }
        }
        return out
    }

    /// 넣은 것을 알리는 한 줄: "11/21 15:00 강남역에서 만나 · 내일 밥먹기"
    static func summary(_ items: [Item], today: DayKey, calendar: Calendar = .current) -> String {
        items.prefix(4).map { i in
            var when = i.day.map { ReplyRules.dayWord($0, today: today) } ?? ""
            if let t = i.time { when += String(format: " %d:%02d", t / 60, t % 60) }
            return when.isEmpty ? i.title : "\(when) \(i.title)"
        }.joined(separator: " · ") + (items.count > 4 ? " · 그리고 \(items.count - 4)개" : "")
    }

    /// 자동으로 넘어온 글 가운데 챙길 일이 아닌 것: 인증번호 · 광고 · 카드 승인 · 배송 알림
    private static let junkCue = rx("인증\\s?번호|본인\\s?확인|OTP|\\(광고\\)|수신\\s?거부|무료\\s?거부|승인\\s?번호|일시불|누적\\s?[0-9,]+원|배송\\s?(출발|완료|예정)|택배.{0,6}(도착|배달)")
    static func isJunk(_ text: String) -> Bool { has(junkCue, text) }

    /// 자동으로 받은 글의 알림 한 줄: 무엇을 찾았고, 내 약속과 겹치는지
    static func notice(_ lines: [String], data: AppData, external: [Entry] = [], now: Date, calendar: Calendar = .current) -> String {
        guard let first = lines.first else { return "" }
        let p = Parser.parse(first, now: now, calendar: calendar)
        var out = first
        if let day = p.day, let t = p.time {
            let dur = p.duration ?? 60
            let clash = data.entries(on: day, external: external, calendar: calendar)
                .first { $0.isEvent && !$0.allDay && ($0.time ?? 0) < t + dur && ($0.end ?? 0) > t }
            if let c = clash { out += " — 그때 ‘\(c.title)’와 겹쳐" }
        }
        if lines.count > 1 { out += " · 그리고 \(lines.count - 1)개 더" }
        return out
    }
}
