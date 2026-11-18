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
        // 대화 화면이면 내가 한 말은 챙길 일로 읽지 않는다
        let mixed = all.contains(where: isMine)
        let lines = CaptureRules.lines((mixed ? got : all.map(\.text)).joined(separator: "\n"), now: now, calendar: calendar)
        return lines.isEmpty ? .nothing : .lines(lines)
    }

    /// 글로 받은 것(문자 · 메일 · 복사한 글)도 같은 갈래로
    static func read(text: String, now: Date, calendar: Calendar = .current) -> ScreenRead {
        let t = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        if ReplyRules.offer(from: t, now: now, calendar: calendar) != nil { return .offer(t) }
        let lines = CaptureRules.lines(t, now: now, calendar: calendar)
        return lines.isEmpty ? .nothing : .lines(lines)
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
