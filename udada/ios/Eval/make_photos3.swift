// 표가 있는 그림: swift Eval/make_photos3.swift Eval/photos3
// 줄을 따라 읽으면 깨지는 꼴 — 날짜가 맨 윗줄에 가로로 놓인 주간표, 날짜 칸이 여러 줄에 걸친 표.
import AppKit

func ev(_ keys: [String], _ m: Int, _ d: Int, _ time: Int?) -> [String: Any] {
    var e: [String: Any] = ["keys": keys, "month": m, "day": d]
    if let time { e["time"] = time }
    return e
}

struct Table { var name: String; var title: String; var colW: [CGFloat]; var rowH: CGFloat; var cells: [[String]]; var expect: [[String: Any]] }

let tables: [Table] = [
    // 날짜가 머리줄에 가로로: 열마다 그 날의 일
    Table(name: "week", title: "11월 셋째 주 일정", colW: [300, 300, 300], rowH: 110,
          cells: [["11월 17일 (화)", "11월 18일 (수)", "11월 19일 (목)"], ["기획 회의", "고객 발표", "팀 워크숍"], ["보고서 마감", "저녁 회식", "장비 점검"]],
          expect: [ev(["기획 회의"], 11, 17, nil), ev(["보고서 마감"], 11, 17, nil), ev(["고객 발표"], 11, 18, nil), ev(["저녁 회식"], 11, 18, nil),
                   ev(["팀 워크숍"], 11, 19, nil), ev(["장비 점검"], 11, 19, nil)]),
    // 날짜 칸이 비어 있으면 윗줄의 날짜
    Table(name: "merged", title: "12월 학사 일정", colW: [280, 420, 200], rowH: 100,
          cells: [["날짜", "행사", "시간"], ["12월 2일", "학부모 총회", "14:00"], ["", "급식 모니터링", "11:30"], ["12월 9일", "독서 발표회", "10:00"], ["", "방과후 공개 수업", "15:00"]],
          expect: [ev(["학부모 총회"], 12, 2, 840), ev(["급식 모니터링"], 12, 2, 690), ev(["독서 발표회"], 12, 9, 600), ev(["방과후 공개 수업", "공개 수업"], 12, 9, 900)]),
    // 평범한 줄 표 (지금도 읽히는 꼴 — 나빠지지 않는지 본다)
    Table(name: "rows", title: "스터디 일정표", colW: [260, 220, 420], rowH: 100,
          cells: [["날짜", "시간", "내용"], ["11월 20일", "19:00", "자료 구조 1장"], ["11월 27일", "19:00", "자료 구조 2장"], ["12월 4일", "19:30", "모의 면접"]],
          expect: [ev(["자료 구조 1장", "1장"], 11, 20, 1140), ev(["자료 구조 2장", "2장"], 11, 27, 1140), ev(["모의 면접"], 12, 4, 1170)]),
]

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
var labels: [[String: Any]] = []
for t in tables {
    let w = t.colW.reduce(0, +) + 160, h = CGFloat(t.cells.count) * t.rowH + 320
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    (t.title as NSString).draw(at: NSPoint(x: 80, y: h - 150), withAttributes: [.font: NSFont.systemFont(ofSize: 56, weight: .bold), .foregroundColor: NSColor.black])
    let top = h - 220
    NSColor.black.setStroke()
    for (r, row) in t.cells.enumerated() {
        var x: CGFloat = 80
        for (c, text) in row.enumerated() {
            let rect = NSRect(x: x, y: top - CGFloat(r + 1) * t.rowH, width: t.colW[c], height: t.rowH)
            let path = NSBezierPath(rect: rect); path.lineWidth = 3; path.stroke()
            (text as NSString).draw(at: NSPoint(x: x + 22, y: rect.midY - 22), withAttributes: [.font: NSFont.systemFont(ofSize: 38, weight: r == 0 ? .bold : .regular), .foregroundColor: NSColor.black])
            x += t.colW[c]
        }
    }
    NSGraphicsContext.current?.flushGraphics()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(t.name).png"))
    labels.append(["file": "\(t.name).png", "expect": t.expect])
}
try! JSONSerialization.data(withJSONObject: labels, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: "\(out)/labels.json"))
print("\(tables.count) 장, 기대 일정 \(tables.reduce(0) { $0 + $1.expect.count })개")
