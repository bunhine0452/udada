// 사진 보기 평가용 그림을 만든다: swift Eval/make_photos.swift Eval/photos
// 포스터·안내문·진료 카드·시간표처럼 날짜와 이름이 떨어져 있거나 군말(가격·주소·전화)이 섞인 꼴.
import AppKit

struct T { var s: String; var x: CGFloat; var y: CGFloat; var size: CGFloat; var bold = false; var color = NSColor.black }
struct Scene { var name: String; var bg: NSColor; var w: CGFloat = 1200; var h: CGFloat = 1500; var texts: [T]; var expect: [[String: Any]] }

func ev(_ keys: [String], _ m: Int, _ d: Int, _ time: Int?) -> [String: Any] {
    var e: [String: Any] = ["keys": keys, "month": m, "day": d]
    if let time { e["time"] = time }
    return e
}

let paper = NSColor(white: 0.97, alpha: 1), navy = NSColor(red: 0.1, green: 0.15, blue: 0.35, alpha: 1), cream = NSColor(red: 0.99, green: 0.96, blue: 0.88, alpha: 1)
let scenes: [Scene] = [
    Scene(name: "concert", bg: navy, texts: [
        T(s: "제12회", x: 90, y: 1340, size: 44, color: .white),
        T(s: "가을 정기 연주회", x: 90, y: 1200, size: 110, bold: true, color: .white),
        T(s: "시민 오케스트라", x: 90, y: 1100, size: 48, color: .white),
        T(s: "2026. 11. 20 (금) 오후 7시 30분", x: 90, y: 520, size: 56, bold: true, color: .white),
        T(s: "구민회관 대강당", x: 90, y: 430, size: 44, color: .white),
        T(s: "전석 10,000원 · 문의 02-123-4567", x: 90, y: 340, size: 36, color: .white),
    ], expect: [ev(["정기 연주회", "연주회"], 11, 20, 1170)]),
    Scene(name: "clinic", bg: paper, w: 1100, h: 700, texts: [
        T(s: "튼튼치과의원", x: 60, y: 580, size: 52, bold: true),
        T(s: "다음 진료 예약", x: 60, y: 470, size: 44),
        T(s: "11월 24일 (화) 오전 10시 30분", x: 60, y: 370, size: 54, bold: true),
        T(s: "스케일링", x: 60, y: 270, size: 44),
        T(s: "변경은 하루 전까지 031-555-0101", x: 60, y: 120, size: 30),
    ], expect: [ev(["스케일링", "진료", "치과"], 11, 24, 630)]),
    Scene(name: "school", bg: .white, texts: [
        T(s: "11월 가정통신문", x: 80, y: 1380, size: 64, bold: true),
        T(s: "학부모님께 알려 드립니다", x: 80, y: 1290, size: 36),
        T(s: "11월 18일 (수)   현장체험학습", x: 80, y: 1120, size: 46),
        T(s: "11월 25일 (수)   학부모 상담 14:00", x: 80, y: 1010, size: 46),
        T(s: "11월 27일 (금)   독서 감상문 제출", x: 80, y: 900, size: 46),
        T(s: "준비물: 도시락, 물, 편한 신발", x: 80, y: 740, size: 38),
        T(s: "○○초등학교장", x: 760, y: 200, size: 40),
    ], expect: [ev(["현장체험학습"], 11, 18, nil), ev(["학부모 상담", "상담"], 11, 25, 840), ev(["독서 감상문", "감상문"], 11, 27, nil)]),
    Scene(name: "wedding", bg: cream, texts: [
        T(s: "김민준 · 이서연", x: 250, y: 1150, size: 84, bold: true),
        T(s: "결혼합니다", x: 430, y: 1030, size: 56),
        T(s: "2026년 11월 28일 토요일 낮 12시 30분", x: 150, y: 620, size: 48, bold: true),
        T(s: "더컨벤션 3층 그랜드홀", x: 340, y: 520, size: 44),
        T(s: "마음 전하실 곳 국민 123-45-67890", x: 280, y: 250, size: 32),
    ], expect: [ev(["결혼", "김민준", "이서연"], 11, 28, 750)]),
    Scene(name: "gym", bg: .white, texts: [
        T(s: "필라테스 11월 특강", x: 80, y: 1360, size: 72, bold: true),
        T(s: "11/17 (화) 19:00  코어 집중반", x: 80, y: 1140, size: 50),
        T(s: "11/19 (목) 19:00  체형 교정반", x: 80, y: 1030, size: 50),
        T(s: "11/21 (토) 10:00  입문 원데이", x: 80, y: 920, size: 50),
        T(s: "회원 무료 · 비회원 15,000원", x: 80, y: 700, size: 40),
        T(s: "정원 8명 · 선착순 마감", x: 80, y: 620, size: 40),
    ], expect: [ev(["코어 집중반", "코어"], 11, 17, 1140), ev(["체형 교정반", "체형"], 11, 19, 1140), ev(["입문 원데이", "입문"], 11, 21, 600)]),
    Scene(name: "delivery", bg: paper, w: 1100, h: 800, texts: [
        T(s: "부재중 방문 안내", x: 60, y: 660, size: 60, bold: true),
        T(s: "재방문 예정일 11월 17일 오후 2시", x: 60, y: 520, size: 48, bold: true),
        T(s: "보관 장소: 경비실", x: 60, y: 420, size: 40),
        T(s: "기사 연락처 010-0000-1234", x: 60, y: 330, size: 36),
        T(s: "운송장 5512-8830-1177", x: 60, y: 240, size: 34),
    ], expect: [ev(["재방문", "방문"], 11, 17, 840)]),
    Scene(name: "seminar", bg: navy, texts: [
        T(s: "AI 시대의 글쓰기", x: 90, y: 1250, size: 100, bold: true, color: .white),
        T(s: "저자 초청 북토크", x: 90, y: 1130, size: 56, color: .white),
        T(s: "일시", x: 90, y: 700, size: 36, color: .white),
        T(s: "12월 3일 목요일 저녁 7시", x: 240, y: 700, size: 52, bold: true, color: .white),
        T(s: "장소", x: 90, y: 600, size: 36, color: .white),
        T(s: "동네서점 2층", x: 240, y: 600, size: 52, color: .white),
        T(s: "참가비 무료 · 사전 신청 필수", x: 90, y: 420, size: 40, color: .white),
    ], expect: [ev(["북토크", "글쓰기"], 12, 3, 1140)]),
    Scene(name: "memo", bg: cream, w: 1000, h: 1200, texts: [
        T(s: "이번 주 할 것", x: 80, y: 1060, size: 60, bold: true),
        T(s: "- 세탁소 코트 찾기", x: 80, y: 900, size: 50),
        T(s: "- 엄마 생신 선물", x: 80, y: 780, size: 50),
        T(s: "- 11월 19일 저녁 7시 동창 모임", x: 80, y: 660, size: 50),
        T(s: "- 관리비 이체", x: 80, y: 540, size: 50),
    ], expect: [ev(["세탁소", "코트"], 0, 0, nil), ev(["선물", "생신"], 0, 0, nil), ev(["동창 모임", "동창"], 11, 19, 1140), ev(["관리비"], 0, 0, nil)]),
    Scene(name: "moving", bg: .white, texts: [
        T(s: "엘리베이터 정기 점검 안내", x: 80, y: 1350, size: 64, bold: true),
        T(s: "아래와 같이 점검을 실시하오니 양해 바랍니다.", x: 80, y: 1230, size: 36),
        T(s: "점검 일시 : 11월 23일(월) 13:00 ~ 15:00", x: 80, y: 1040, size: 48, bold: true),
        T(s: "대상 : 101동 1,2호기", x: 80, y: 940, size: 44),
        T(s: "점검 중에는 계단을 이용해 주세요.", x: 80, y: 800, size: 38),
        T(s: "관리사무소 ☎ 02-987-6543", x: 80, y: 300, size: 36),
    ], expect: [ev(["점검", "엘리베이터"], 11, 23, 780)]),
    Scene(name: "exam", bg: paper, texts: [
        T(s: "기말고사 시간표", x: 80, y: 1360, size: 72, bold: true),
        T(s: "12월 7일 (월)   국어", x: 80, y: 1150, size: 52),
        T(s: "12월 8일 (화)   수학", x: 80, y: 1040, size: 52),
        T(s: "12월 9일 (수)   영어", x: 80, y: 930, size: 52),
        T(s: "시험 범위는 학급 게시판 참고", x: 80, y: 740, size: 40),
    ], expect: [ev(["국어"], 12, 7, nil), ev(["수학"], 12, 8, nil), ev(["영어"], 12, 9, nil)]),
]

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
var labels: [[String: Any]] = []
for sc in scenes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(sc.w), pixelsHigh: Int(sc.h), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    sc.bg.setFill(); NSRect(x: 0, y: 0, width: sc.w, height: sc.h).fill()
    for t in sc.texts {
        let font = NSFont.systemFont(ofSize: t.size, weight: t.bold ? .bold : .regular)
        (t.s as NSString).draw(at: NSPoint(x: t.x, y: t.y), withAttributes: [.font: font, .foregroundColor: t.color])
    }
    NSGraphicsContext.current?.flushGraphics()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(sc.name).png"))
    labels.append(["file": "\(sc.name).png", "expect": sc.expect])
}
try! JSONSerialization.data(withJSONObject: labels, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "\(out)/labels.json"))
print("\(scenes.count) 장, 기대 일정 \(scenes.reduce(0) { $0 + $1.expect.count })개")
