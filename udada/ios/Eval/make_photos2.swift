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
    Scene(name: "market", bg: cream, texts: [
        T(s: "동네 플리마켓", x: 90, y: 1300, size: 110, bold: true),
        T(s: "안 쓰는 물건, 이웃에게", x: 90, y: 1190, size: 48),
        T(s: "언제", x: 90, y: 800, size: 40), T(s: "11월 22일 일요일 오전 11시", x: 260, y: 800, size: 52, bold: true),
        T(s: "어디서", x: 90, y: 700, size: 40), T(s: "주민센터 앞마당", x: 260, y: 700, size: 52),
        T(s: "셀러 모집 중 · 참가비 5,000원", x: 90, y: 420, size: 38),
    ], expect: [ev(["플리마켓"], 11, 22, 660)]),
    Scene(name: "hospital", bg: .white, w: 1100, h: 900, texts: [
        T(s: "건강검진 예약 확인서", x: 60, y: 770, size: 56, bold: true),
        T(s: "성명  홍길동", x: 60, y: 660, size: 40),
        T(s: "검진일  2026-12-02 (수)", x: 60, y: 570, size: 46, bold: true),
        T(s: "접수 시간  08:30", x: 60, y: 480, size: 46, bold: true),
        T(s: "전날 저녁 9시 이후 금식", x: 60, y: 360, size: 40),
        T(s: "문의 1588-0000", x: 60, y: 160, size: 32),
    ], expect: [ev(["건강검진", "검진"], 12, 2, 510)]),
    Scene(name: "club", bg: navy, texts: [
        T(s: "독서 모임 12월 일정", x: 90, y: 1340, size: 76, bold: true, color: .white),
        T(s: "12/5 (토) 15:00  소설 읽기", x: 90, y: 1120, size: 52, color: .white),
        T(s: "12/12 (토) 15:00  에세이 쓰기", x: 90, y: 1010, size: 52, color: .white),
        T(s: "12/19 (토) 17:00  송년 모임", x: 90, y: 900, size: 52, color: .white),
        T(s: "회비 월 20,000원", x: 90, y: 680, size: 40, color: .white),
    ], expect: [ev(["소설 읽기", "소설"], 12, 5, 900), ev(["에세이 쓰기", "에세이"], 12, 12, 900), ev(["송년 모임", "송년"], 12, 19, 1020)]),
    Scene(name: "fix", bg: paper, w: 1100, h: 800, texts: [
        T(s: "단수 안내", x: 60, y: 660, size: 72, bold: true),
        T(s: "배관 공사로 물이 나오지 않습니다", x: 60, y: 550, size: 40),
        T(s: "11월 26일(목) 오전 9시부터 오후 1시까지", x: 60, y: 420, size: 46, bold: true),
        T(s: "미리 물을 받아 두세요", x: 60, y: 320, size: 40),
        T(s: "○○아파트 관리사무소", x: 600, y: 120, size: 34),
    ], expect: [ev(["단수", "배관 공사"], 11, 26, 540)]),
    Scene(name: "kids", bg: .white, texts: [
        T(s: "해님반 12월 안내", x: 80, y: 1360, size: 68, bold: true),
        T(s: "12월 4일 (금)  겨울 발표회 리허설", x: 80, y: 1140, size: 46),
        T(s: "12월 11일 (금)  부모 참여 수업 10:30", x: 80, y: 1030, size: 46),
        T(s: "12월 24일 (목)  산타 행사", x: 80, y: 920, size: 46),
        T(s: "원비 납부는 매달 25일까지입니다", x: 80, y: 740, size: 38),
    ], expect: [ev(["발표회 리허설", "리허설"], 12, 4, nil), ev(["부모 참여 수업", "참여 수업"], 12, 11, 630), ev(["산타 행사", "산타"], 12, 24, nil)]),
    Scene(name: "ticket", bg: navy, w: 1200, h: 700, texts: [
        T(s: "뮤지컬 겨울 이야기", x: 70, y: 540, size: 78, bold: true, color: .white),
        T(s: "2026.12.13 SUN 14:00", x: 70, y: 400, size: 56, bold: true, color: .white),
        T(s: "R석 1층 C열 12번", x: 70, y: 290, size: 44, color: .white),
        T(s: "예매번호 T2026-889-1023", x: 70, y: 150, size: 34, color: .white),
    ], expect: [ev(["뮤지컬", "겨울 이야기"], 12, 13, 840)]),
    Scene(name: "todo", bg: cream, w: 1000, h: 1200, texts: [
        T(s: "주말에", x: 80, y: 1060, size: 60, bold: true),
        T(s: "1. 겨울 이불 꺼내기", x: 80, y: 900, size: 50),
        T(s: "2. 11/21 오후 3시 미용실", x: 80, y: 780, size: 50),
        T(s: "3. 장보기 (두부, 대파)", x: 80, y: 660, size: 50),
        T(s: "4. 부모님께 전화", x: 80, y: 540, size: 50),
    ], expect: [ev(["이불"], 0, 0, nil), ev(["미용실"], 11, 21, 900), ev(["장보기"], 0, 0, nil), ev(["전화"], 0, 0, nil)]),
    Scene(name: "lecture", bg: .white, texts: [
        T(s: "신입 사원 교육", x: 80, y: 1350, size: 80, bold: true),
        T(s: "보안 · 인사 제도 · 사내 시스템", x: 80, y: 1240, size: 42),
        T(s: "교육 일정", x: 80, y: 900, size: 40), T(s: "12월 1일(화) 오전 10시", x: 330, y: 900, size: 52, bold: true),
        T(s: "교육 장소", x: 80, y: 800, size: 40), T(s: "본사 7층 대회의실", x: 330, y: 800, size: 52),
        T(s: "노트북 지참 · 인사팀 내선 1234", x: 80, y: 520, size: 38),
    ], expect: [ev(["신입 사원 교육", "교육"], 12, 1, 600)]),
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
