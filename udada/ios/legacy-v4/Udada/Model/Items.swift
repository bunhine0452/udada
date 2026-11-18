import Foundation

/// 머릿속 열린 고리 하나를 닫는 네 칸. 근거는 udada/design/VALUE.md
/// - 지금: 2분이면 끝날 것 → 지금 할 단 하나
/// - 날짜: '언제'만 정해도 침투 사고가 사라졌다 (Masicampo & Baumeister 2011) → 그때 알림으로 돌아온다
/// - 걱정: 내 손 밖의 일은 정해진 걱정 시간으로 미룬다 (McGowan & Behar 2013)
/// - 버리기: 안 해도 되는 것. 진짜로 지운다 (Briñol 2012)
enum Bin: String, Codable, CaseIterable {
    case now, date, worry, drop
    var name: String { switch self { case .now: "지금"; case .date: "날짜 정하기"; case .worry: "걱정 시간"; case .drop: "버리기" } }
    var tag: String { switch self { case .now: "2분이면 끝"; case .date: "그때 알려 줌"; case .worry: "내 손 밖"; case .drop: "안 해도 됨" } }
    var symbol: String { switch self { case .now: "bolt"; case .date: "calendar"; case .worry: "moon"; case .drop: "scissors" } }
}

/// '날짜 정하기'의 네 가지 때. 고르면 실제 시각이 된다.
enum When: String, Codable, CaseIterable {
    case tonight, tomorrow, weekend, nextWeek
    var label: String { switch self { case .tonight: "오늘 저녁"; case .tomorrow: "내일 아침"; case .weekend: "이번 주말"; case .nextWeek: "다음 주" } }

    /// 오늘 저녁 19:00(지났으면 지금+1시간) · 내일 09:00 · 다가오는 토요일 10:00 · 다음 월요일 09:00
    func due(from now: Date, calendar cal: Calendar = .current) -> Date {
        func at(_ day: Date, _ h: Int, _ m: Int = 0) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: day)! }
        switch self {
        case .tonight:
            let t = at(now, 19)
            return t > now ? t : now.addingTimeInterval(3600)
        case .tomorrow:
            return at(cal.date(byAdding: .day, value: 1, to: now)!, 9)
        case .weekend:
            let wd = cal.component(.weekday, from: now) // 1 일 … 7 토
            let ahead = (7 - wd + 7) % 7
            let sat = at(cal.date(byAdding: .day, value: ahead, to: now)!, 10)
            return sat > now ? sat : at(cal.date(byAdding: .day, value: 7, to: now)!, 10)
        case .nextWeek:
            let wd = cal.component(.weekday, from: now)
            let ahead = (2 - wd + 7) % 7 == 0 ? 7 : (2 - wd + 7) % 7
            return at(cal.date(byAdding: .day, value: ahead, to: now)!, 9)
        }
    }
}

/// 정리된 고리 하나. 버린 건 저장하지 않는다.
struct Item: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var bin: Bin
    var when: When?
    var due: Date?
    var created = Date()
    var done = false
}

/// 한 번 정리한 기록: 머리 소음 전후와 칸별 개수.
struct Session: Codable, Hashable {
    var at: Date
    var before: Int
    var after: Int
    var counts: [Bin: Int]
    var total: Int { counts.values.reduce(0, +) }
    var delta: Int { after - before }
}

/// 정리 칸 제안 (AI 아님, 단어 규칙)
enum Sorter {
    static func when(of t: String) -> When {
        if t.range(of: "오늘|저녁|밤", options: .regularExpression) != nil { return .tonight }
        if t.range(of: "주말|토요일|일요일", options: .regularExpression) != nil { return .weekend }
        if t.range(of: "다음 ?주|다음 ?달", options: .regularExpression) != nil { return .nextWeek }
        return .tomorrow
    }

    static func suggest(_ t: String) -> (bin: Bin, why: String, when: When?) {
        if t.range(of: "어떡|어쩌|걱정|불안|혹시|될까|무섭|망하|싫어하|미래|건강|왜 그랬|후회", options: .regularExpression) != nil {
            return (.worry, "지금 할 수 있는 게 없어 보여. 걱정 시간에 모아서 다시 보여 줄게.", nil)
        }
        if t.range(of: "할까 ?말까|말까|해볼까|언젠가|살까|사고 ?싶", options: .regularExpression) != nil {
            return (.drop, "꼭 안 해도 되는 것 같아. 버리면 진짜 지워져.", nil)
        }
        if t.count <= 14, (t + " ").range(of: "전화|답장|메일|문자|카톡|보내|설거지|빨래|물 |약 |쓰레기|충전|입금|송금", options: .regularExpression) != nil {
            return (.now, "2분이면 끝날 것 같아. 지금 해치우자.", nil)
        }
        let w = when(of: t)
        return (.date, "언제 할지만 정하면 머리에서 내려가. \(w.label)에 알려 줄게.", w)
    }
}

func signed(_ x: Double) -> String {
    let r = (x * 10).rounded() / 10
    let s = r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    return r > 0 ? "+" + s : s
}

func mmss(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

enum Noise {
    static func word(_ v: Int) -> String {
        switch v { case 0...2: "조용함"; case 3...4: "조금 시끄러움"; case 5...6: "시끄러움"; case 7...8: "꽤 시끄러움"; default: "터질 듯" }
    }
}
