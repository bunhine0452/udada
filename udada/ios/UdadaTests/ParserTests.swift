import XCTest
@testable import Udada

// 한국어 한 줄 읽기 (Shared/Parser.swift). 기준 시각은 2026-11-15 (일) 14:20 Asia/Seoul.
// 사례 목록은 독립 하네스와 같은 것이다.

final class ParserTests: XCTestCase {
    func testCases() {
        for c in parserCases {
            let got = Parser.parse(c.text, now: caseDate(c.now), calendar: seoul)
            XCTAssertEqual(got, c.want, "[\(c.text)] @\(c.now)", line: UInt(c.line))
        }
    }

    func testSplit() {
        XCTAssertEqual(Parser.split(splitInput), splitWant)
        XCTAssertEqual(Parser.split("\n  \n"), [])
    }

    func testEmpty() {
        XCTAssertEqual(Parser.parse("", now: caseDate("14:20"), calendar: seoul), Parsed(title: ""))
    }
}

// MARK: - 공통 사례 (하네스와 XCTest 가 같은 목록을 쓴다)

fileprivate struct ParserCase { let text: String; let now: String; let want: Parsed; let line: Int }

fileprivate let seoul: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Seoul")!
    c.locale = Locale(identifier: "ko_KR")
    return c
}()

/// "14:20" → 2026-11-15 (일) 14:20, 또는 "2026-11-18 10:00"
fileprivate func caseDate(_ s: String) -> Date {
    let full = s.count <= 5 ? "2026-11-15 " + s : s
    let p = full.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" }).compactMap { Int($0) }
    return seoul.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: p[3], minute: p[4]))!
}

/// "11-16" (2026년) 또는 "2027-01-05"
fileprivate func dk(_ s: String) -> DayKey {
    let p = s.split(separator: "-").compactMap { Int($0) }
    return p.count == 2 ? DayKey(y: 2026, m: p[0], d: p[1]) : DayKey(y: p[0], m: p[1], d: p[2])
}

fileprivate func P(_ title: String, day: String? = nil, later: Bool = false, time: Int? = nil, dur: Int? = nil, part: Part? = nil, rep: RepeatRule? = nil) -> Parsed {
    Parsed(title: title, day: day.map(dk), later: later, time: time, duration: dur, part: part, repeatRule: rep)
}

fileprivate func C(_ text: String, _ want: Parsed, now: String = "14:20", line: Int = #line) -> ParserCase {
    ParserCase(text: text, now: now, want: want, line: line)
}

fileprivate let parserCases: [ParserCase] = [
    // 꼭 통과
    C("3시 치과", P("치과", time: 900)),
    C("보고서 30분", P("보고서", dur: 30)),
    C("내일 저녁 빨래", P("빨래", day: "11-16", part: .evening)),
    C("9시 회의", P("회의", time: 1260)),
    C("9시 회의", P("회의", time: 540), now: "08:00"),
    C("금요일까지 보고서", P("보고서", day: "11-20")),
    C("다음 주 수요일 오후 2시 반 미팅", P("미팅", day: "11-25", time: 870)),
    C("매주 월수금 아침 운동", P("운동", day: "11-16", part: .morning, rep: .weekly([2, 4, 6]))),
    C("엄마한테 전화 10분", P("엄마한테 전화", dur: 10)),
    C("30분 뒤 약 먹기", P("약 먹기", day: "11-15", time: 890)),
    C("월세 내기", P("월세 내기")),
    C("일기 쓰기", P("일기 쓰기")),
    C("12월 3일 건강검진", P("건강검진", day: "2026-12-03")),
    C("3시부터 5시까지 스터디", P("스터디", time: 900, dur: 120)),
    C("나중에 여권 갱신", P("여권 갱신", later: true)),

    // 날
    C("오늘 장보기", P("장보기", day: "11-15")),
    C("모레 택배 보내기", P("택배 보내기", day: "11-17")),
    C("글피 이사", P("이사", day: "11-18")),
    C("내일모레 시험", P("시험", day: "11-17")),
    C("낼 병원", P("병원", day: "11-16")),
    C("월요일 회의", P("회의", day: "11-16")),
    C("일요일 3시 브런치", P("브런치", day: "11-15", time: 900)),
    C("일요일 2시 산책", P("산책", day: "11-22", time: 840)),
    C("일욜 대청소", P("대청소", day: "11-15")),
    C("수욜에 미용실", P("미용실", day: "11-18")),
    C("금요일날 회식", P("회식", day: "11-20")),
    C("이번 주 금요일 발표", P("발표", day: "11-20")),
    C("다음 주 월요일", P("", day: "11-23")),
    C("담주 화요일 병원", P("병원", day: "11-24")),
    C("다음주 금요일까지 과제", P("과제", day: "11-27")),
    C("다음 주에 계획 세우기", P("계획 세우기", day: "11-23")),
    C("주말에 대청소", P("대청소", day: "11-15")),
    C("이번 주말 영화", P("영화", day: "11-15")),
    C("다음 주말 캠핑", P("캠핑", day: "11-21")),
    C("3일 뒤 반납", P("반납", day: "11-18")),
    C("2주 후 재검", P("재검", day: "11-29")),
    C("이틀 뒤에 연락", P("연락", day: "11-17")),
    C("하루 후", P("", day: "11-16")),
    C("한 달 뒤 정기검진", P("정기검진", day: "12-15")),
    C("11/20 마감", P("마감", day: "11-20")),
    C("1.5 회의", P("회의", day: "2027-01-05")),
    C("3월 1일 여행", P("여행", day: "2027-03-01")),
    C("2027년 5월 5일 결혼식", P("결혼식", day: "2027-05-05")),
    C("20일까지 과제", P("과제", day: "11-20")),
    C("10일 세금", P("세금", day: "12-10")),
    C("31일 카드값", P("카드값", day: "12-31")),
    C("3일 동안 출장", P("3일 동안 출장")),
    C("회의 내일까지", P("회의", day: "11-16")),
    C("월요일까지 월세 내기", P("월세 내기", day: "11-16")),
    C("수요일 일기 쓰기", P("일기 쓰기", day: "11-18")),
    C("일정 정리", P("일정 정리")),
    C("시간 날 때 책장 정리", P("책장 정리", later: true)),
    C("언젠가 제주도 한 달 살기", P("제주도 한 달 살기", later: true)),

    // 시각
    C("오후 3시 미팅", P("미팅", time: 900)),
    C("오전 10시 은행", P("은행", time: 600)),
    C("새벽 5시 기상", P("기상", time: 300)),
    C("저녁 7시 저녁 약속", P("저녁 약속", time: 1140)),
    C("밤 11시", P("", time: 1380)),
    C("밤 12시 불끄기", P("불끄기", time: 0)),
    C("12시 점심", P("점심", time: 720)),
    C("8시 반 조깅", P("조깅", time: 510), now: "08:00"),
    C("10시에 회의", P("회의", time: 1320)),
    C("내일 10시 회의", P("회의", day: "11-16", time: 600)),
    C("오늘 3시 치과", P("치과", day: "11-15", time: 900)),
    C("2시 반에 은행", P("은행", time: 870)),
    C("3시 30분 상담", P("상담", time: 930)),
    C("14:30 면접", P("면접", time: 870)),
    C("정오에 점심 약속", P("점심 약속", time: 720)),
    C("3시 반찬 만들기", P("반찬 만들기", time: 900)),
    C("2시간 뒤 회의", P("회의", day: "11-15", time: 980)),
    C("1시간 반 뒤 출발", P("출발", day: "11-15", time: 950)),
    C("한 시간 후에 전화", P("전화", day: "11-15", time: 920)),
    C("3시간 후", P("", day: "11-16", time: 90), now: "22:30"),
    C("30분 뒤 양치", P("양치", day: "11-15", time: 1380), now: "22:30"),
    C("9시 회의", P("회의", time: 1260), now: "22:30"),
    C("3시~5시 회의", P("회의", time: 900, dur: 120)),
    C("3-5시 세미나", P("세미나", time: 900, dur: 120)),
    C("15:00-16:30 회의", P("회의", time: 900, dur: 90)),
    C("오후 2시부터 4시까지", P("", time: 840, dur: 120)),
    C("10시부터 오후 1시까지 워크숍", P("워크숍", time: 600, dur: 180)),

    // 길이
    C("운동 1시간", P("운동", dur: 60)),
    C("독서 1시간 반", P("독서", dur: 90)),
    C("코딩 2시간 30분", P("코딩", dur: 150)),
    C("명상 10분 동안", P("명상", dur: 10)),
    C("대청소 반나절", P("대청소", dur: 240)),
    C("산책 한 시간", P("산책", dur: 60)),
    C("1.5시간 회의", P("회의", dur: 90)),
    C("3시간 공부", P("공부", dur: 180)),
    C("20분 산책", P("산책", dur: 20)),
    C("내일 3시 치과 1시간", P("치과", day: "11-16", time: 900, dur: 60)),
    C("30분 뒤 10분 스트레칭", P("스트레칭", day: "11-15", time: 890, dur: 10)),

    // 띠
    C("저녁 약속", P("저녁 약속", part: .evening)),
    C("점심 먹기", P("점심 먹기", part: .afternoon)),
    C("아침 운동", P("아침 운동", part: .morning)),
    C("저녁에 빨래", P("빨래", part: .evening)),
    C("아침엔 스트레칭", P("스트레칭", part: .morning)),
    C("오후에 은행", P("은행", part: .afternoon)),
    C("오늘 밤 일기", P("일기", day: "11-15", part: .evening)),
    C("내일저녁 빨래", P("빨래", day: "11-16", part: .evening)),
    C("내일 저녁에 친구 만나기", P("친구 만나기", day: "11-16", part: .evening)),
    C("월요일 아침 회의", P("회의", day: "11-16", part: .morning)),
    C("낮잠 자기", P("낮잠 자기")),

    // 반복
    C("매일 영양제", P("영양제", day: "11-15", rep: .daily)),
    C("날마다 물 2리터", P("물 2리터", day: "11-15", rep: .daily)),
    C("매일 9시 운동", P("운동", day: "11-16", time: 540, rep: .daily)),
    C("매일 아침 운동", P("운동", day: "11-15", part: .morning, rep: .daily)),
    C("아침마다 스트레칭", P("스트레칭", day: "11-15", part: .morning, rep: .daily)),
    C("평일 출근", P("출근", day: "11-16", rep: .weekdaysOnly)),
    C("평일마다 8시 출근", P("출근", day: "11-16", time: 480, rep: .weekdaysOnly)),
    C("주중에 헬스", P("헬스", day: "11-16", rep: .weekdaysOnly)),
    C("주말마다 등산", P("등산", day: "11-15", rep: .weekendsOnly)),
    C("매주말 빨래", P("빨래", day: "11-15", rep: .weekendsOnly)),
    C("매주 화요일 수영", P("수영", day: "11-17", rep: .weekly([3]))),
    C("화요일마다 수영", P("수영", day: "11-17", rep: .weekly([3]))),
    C("매주 월·수·금 요가", P("요가", day: "11-16", rep: .weekly([2, 4, 6]))),
    C("매주 월,수,금 요가", P("요가", day: "11-16", rep: .weekly([2, 4, 6]))),
    C("매주 화목 피아노", P("피아노", day: "11-17", rep: .weekly([3, 5]))),
    C("매주 일요일 7시 저녁 예배", P("저녁 예배", day: "11-15", time: 1140, rep: .weekly([1]))),
    C("매주 일요일 저녁 7시 예배", P("예배", day: "11-15", time: 1140, rep: .weekly([1]))),
    C("매주 회의", P("회의", day: "11-15", rep: .weekly([1]))),
    C("매주 일기 쓰기", P("일기 쓰기", day: "11-15", rep: .weekly([1]))),
    C("매달 25일 월세", P("월세", day: "11-25", rep: .monthly(25))),
    C("매월 1일 정산", P("정산", day: "12-01", rep: .monthly(1))),
    C("매달 31일 카드값", P("카드값", day: "11-30", rep: .monthly(31))),
    C("매달 보고", P("보고", day: "11-15", rep: .monthly(15))),
    C("3일마다 물주기", P("물주기", day: "11-15", rep: .interval(3))),
    C("이틀마다 빨래", P("빨래", day: "11-15", rep: .interval(2))),
    C("격주 회의", P("격주 회의")),

    // 제목
    C("치과, 3시", P("치과", time: 900)),
    C("   ", P("")),
    C("내일", P("", day: "11-16")),
    C("3시에", P("", time: 900)),
    C("월요일 월세", P("월세", day: "11-16")),
    C("치과 3시 에", P("치과", time: 900)),
    C("부터 시작", P("부터 시작")),
    C("여기까지 읽기 내일", P("여기까지 읽기", day: "11-16")),
    C("일요일에도 출근", P("출근", day: "11-15")),
    C("치과.", P("치과")),

    // 수요일 2026-11-18 10:00 기준 주 낱말
    C("이번 주 금요일 발표", P("발표", day: "11-20"), now: "2026-11-18 10:00"),
    C("이번 주 일요일 등산", P("등산", day: "11-22"), now: "2026-11-18 10:00"),
    C("다음 주 수요일", P("", day: "11-25"), now: "2026-11-18 10:00"),
    C("다음 주", P("", day: "11-23"), now: "2026-11-18 10:00"),
    C("주말 대청소", P("대청소", day: "11-21"), now: "2026-11-18 10:00"),
    C("다음 주말", P("", day: "11-28"), now: "2026-11-18 10:00"),
    C("수요일 9시 회의", P("회의", day: "11-25", time: 540), now: "2026-11-18 10:00"),
    C("수요일 11시 회의", P("회의", day: "11-18", time: 660), now: "2026-11-18 10:00"),
    C("다음 주 수요일 7시 동창 모임", P("동창 모임", day: "11-25", time: 1140)),
    C("내일 8시 회식", P("회식", day: "11-16", time: 1200)),
    C("토요일 7시 영화", P("영화", day: "11-21", time: 1140)),
    C("내일 7시 반 저녁 약속", P("저녁 약속", day: "11-16", time: 1170)),
    C("내일 9시 회의", P("회의", day: "11-16", time: 540)),
    C("내일 아침 7시 모임", P("모임", day: "11-16", time: 420)),
    C("7시 수술", P("수술", time: 1140)),
]

fileprivate let splitInput = "- 우유\n• 빵\n\n* 계란\n1. 사과\n2) 배\n☐ 감자\n[ ] 양파\n  고구마  \r\n1.5시간 회의\n- [ ] 메일"
fileprivate let splitWant = ["우유", "빵", "계란", "사과", "배", "감자", "양파", "고구마", "1.5시간 회의", "메일"]
