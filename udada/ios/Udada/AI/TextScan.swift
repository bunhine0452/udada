import CoreGraphics
import Foundation
import ImageIO
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// 사진 속 글자 → 할 일 줄. 손글씨 목록·일정표 캡처를 기기 안에서 읽는다 (Vision, 사진은 저장하지 않음).
/// 조각을 위→아래 줄로 묶고, 같은 줄의 조각은 왼→오른 순서로 잇고, 네모 칸·체크·글머리표·쪽 번호를 뗀다.
enum TextScan {
    /// Vision 이 돌려준 글자 조각 하나. 꼭짓점은 픽셀 좌표, 원점은 왼쪽 아래(y 가 위로 커짐).
    struct Fragment: Equatable {
        var text: String
        var confidence: Float = 1
        var topLeft: CGPoint
        var topRight: CGPoint
        var bottomRight: CGPoint
        var bottomLeft: CGPoint

        /// 기울지 않은 네모 (테스트·하네스용)
        init(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, confidence: Float = 1) {
            self.init(text: text, confidence: confidence,
                      topLeft: CGPoint(x: x, y: y + h), topRight: CGPoint(x: x + w, y: y + h),
                      bottomRight: CGPoint(x: x + w, y: y), bottomLeft: CGPoint(x: x, y: y))
        }
        init(text: String, confidence: Float, topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
            self.text = text
            self.confidence = confidence
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomRight = bottomRight
            self.bottomLeft = bottomLeft
        }
    }

    #if canImport(UIKit)
    /// 사진 한 장 → 정리된 줄들. 못 읽으면 빈 배열.
    static func recognize(_ image: UIImage) async -> [String] {
        guard let cg = upright(image) else { return [] }
        return await recognize(cg)
    }

    /// 방향 정보를 픽셀에 굽는다 (카메라 사진은 보통 .right). 너무 큰 사진은 줄인다.
    static func upright(_ image: UIImage) -> CGImage? {
        let maxSide: CGFloat = 3200
        let px = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let shrink = min(1, maxSide / max(px.width, px.height, 1))
        if image.imageOrientation == .up, shrink == 1, let cg = image.cgImage { return cg }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: (px.width * shrink).rounded(), height: (px.height * shrink).rounded())
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
    #endif

    /// 표가 있는 문서면 칸 구조로 읽은 일정 줄들 (문서 인식 — iOS 26 · macOS 26 부터). 표가 없거나 날짜가 안 읽히면 빈 배열.
    static func tableLines(in image: CGImage, now: Date = Date()) async -> [String] {
        guard #available(iOS 26.0, macOS 26.0, *) else { return [] }
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = false
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ko-KR"), Locale.Language(identifier: "en-US")]
        guard let observations = try? await request.perform(on: image) else { return [] }
        var out: [String] = []
        for o in observations {
            for t in o.document.tables {
                let grid = t.rows.map { row in row.map { $0.content.text.transcript } }
                out += BrainRules.tableLines(grid, now: now)
            }
        }
        return out
    }

    /// 바로 선 이미지 → 정리된 줄들.
    static func recognize(_ image: CGImage) async -> [String] {
        lines(from: await fragments(in: image))
    }

    /// 글자 조각을 화면 크기에 대한 비율 자리로 (화면 그대로 · 공유 확장)
    static func pieces(in image: CGImage) async -> [ScreenPiece] {
        let w = Double(image.width), h = Double(image.height)
        guard w > 0, h > 0 else { return [] }
        return await fragments(in: image).map { f in
            ScreenPiece(text: f.text, minX: Double(min(f.topLeft.x, f.bottomLeft.x)) / w, maxX: Double(max(f.topRight.x, f.bottomRight.x)) / w,
                        top: 1 - Double(max(f.topLeft.y, f.topRight.y)) / h)
        }
    }

    /// Vision 글자 인식 (정확도 우선 · 한국어+영어 · 언어 보정 켬).
    static func fragments(in image: CGImage) async -> [Fragment] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let wanted = [Locale.Language(identifier: "ko-KR"), Locale.Language(identifier: "en-US")]
        let supported = request.supportedRecognitionLanguages
        let langs = wanted.filter { w in supported.contains { $0.languageCode == w.languageCode } }
        request.recognitionLanguages = langs.isEmpty ? wanted : langs
        let size = CGSize(width: image.width, height: image.height)
        guard let observations = try? await request.perform(on: image) else { return [] }
        return observations.compactMap { o in
            let candidates = o.topCandidates(3)
            guard let top = candidates.first else { return nil }
            return Fragment(text: settleLead(candidates.map(\.string)), confidence: top.confidence,
                            topLeft: o.topLeft.toImageCoordinates(size, origin: .lowerLeft),
                            topRight: o.topRight.toImageCoordinates(size, origin: .lowerLeft),
                            bottomRight: o.bottomRight.toImageCoordinates(size, origin: .lowerLeft),
                            bottomLeft: o.bottomLeft.toImageCoordinates(size, origin: .lowerLeft))
        }
    }

    /// 손으로 그린 네모를 Vision 이 「그」「_」「-」처럼 매번 다르게 읽으면, 그 앞 글자는 글이 아니라 칸이다.
    /// 첫 후보의 맨 앞 한 글자 낱말이 다른 후보에서 다른 글자로 바뀌거나 사라지고 나머지는 같으면 뗀다.
    static func settleLead(_ candidates: [String]) -> String {
        guard let top = candidates.first else { return "" }
        let parts = top.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].count == 1 else { return top }
        let rest = parts[1]
        let unsure = candidates.dropFirst().contains { alt in
            if alt == rest { return true }
            let a = alt.split(separator: " ", maxSplits: 1).map(String.init)
            return a.count == 2 && a[0].count == 1 && a[0] != parts[0] && a[1] == rest
        }
        return unsure ? rest : top
    }

    // MARK: - 줄 묶기

    /// 조각 → 줄. 전체 기울기(조각 아래 변 각도의 중앙값)를 바로잡은 뒤 위→아래로 묶는다.
    static func lines(from fragments: [Fragment]) -> [String] {
        let kept = fragments.filter { $0.confidence >= 0.2 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !kept.isEmpty else { return [] }
        let angles = kept.map { atan2($0.bottomRight.y - $0.bottomLeft.y, $0.bottomRight.x - $0.bottomLeft.x) }.sorted()
        let skew = angles[angles.count / 2]
        let boxes = kept.map { Box($0, unskew: skew) }.sorted { $0.midY > $1.midY }

        var rows: [Row] = []
        for b in boxes {
            var best: (index: Int, score: CGFloat)?
            for (i, r) in rows.enumerated() {
                let overlap = min(r.maxY, b.maxY) - max(r.minY, b.minY)
                let score = overlap / max(1, min(r.height, b.height))
                guard score >= 0.5, !r.collides(with: b) else { continue }
                if score > (best?.score ?? 0) { best = (i, score) }
            }
            if let best { rows[best.index].add(b) } else { rows.append(Row(b)) }
        }
        let raw = rows.sorted { $0.midY > $1.midY }.map { r in
            r.items.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ")
        }
        return clean(raw)
    }

    // MARK: - 다듬기

    /// 칸·체크·글머리표를 떼고, 기호뿐인 줄·쪽 번호·날짜뿐인 머리줄·겹친 줄을 버린다.
    static func clean(_ raw: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for line in raw {
            var s = stripMarks(line.trimmingCharacters(in: .whitespaces))
            s = stripMarks(Parser.split(s).first ?? "")
            s = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".,·:;")))
            guard !isNoise(s), seen.insert(s).inserted else { continue }
            out.append(s)
        }
        return out
    }

    /// 앞머리의 네모 칸·체크·동그라미, 그리고 OCR 이 칸을 잘못 읽은 글자(口 · ㅁ · √ · 공백 앞 V/O/[/|)를 뗀다.
    private static func stripMarks(_ line: String) -> String {
        var s = line
        for _ in 0..<3 {
            let before = s
            if let m = leadMark.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let r = Range(m.range, in: s) {
                s = String(s[r.upperBound...])
            }
            s = s.trimmingCharacters(in: .whitespaces)
            if s == before { break }
        }
        return s
    }

    private static func isNoise(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        if s.isEmpty { return true }
        if !s.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) { return true } // 기호·숫자뿐 (쪽 번호, "10:00")
        if dateOnly.firstMatch(in: s, range: range) != nil { return true }
        if s.count == 1, !(s.unicodeScalars.first.map { (0xAC00...0xD7A3).contains($0.value) } ?? false) { return true }
        return false
    }

    private static let leadMark = try! NSRegularExpression(pattern:
        #"^(?:[□■☐☑☒✓✔✗✘○●◯◻◼▢▫▪⬜⬛❏❑❒◇◆√口回]\#u{FE0F}?|[ㅁㅇ](?=\s|[가-힣])|[VvOo\[\]|(){}](?=\s+[가-힣A-Za-z0-9])|[-–—•·*▪◦‣>](?=\s*\S)|\(\s?\)|\[\s?[xXvV✓]?\s?\])"#)
    /// 「11월 15일 (일)」「2026.11.15」「11/15 월요일」 같은 날짜뿐인 머리줄
    private static let dateOnly = try! NSRegularExpression(pattern:
        #"^(?=.*\d)[\d\s./\-~()\[\]년월일]*(?:[월화수목금토일](?:요일)?)?[\s()\[\]]*$"#)
}

// MARK: - 도우미

private struct Box {
    var text: String
    var minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat
    var midY: CGFloat { (minY + maxY) / 2 }
    var height: CGFloat { maxY - minY }

    init(_ f: TextScan.Fragment, unskew angle: CGFloat) {
        let c = cos(-angle), s = sin(-angle)
        let pts = [f.topLeft, f.topRight, f.bottomRight, f.bottomLeft].map { p in
            CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
        }
        text = f.text.trimmingCharacters(in: .whitespaces)
        minX = pts.map(\.x).min()!
        maxX = pts.map(\.x).max()!
        minY = pts.map(\.y).min()!
        maxY = pts.map(\.y).max()!
    }
}

private struct Row {
    var items: [Box]
    var minY: CGFloat, maxY: CGFloat
    var midY: CGFloat { (minY + maxY) / 2 }
    var height: CGFloat { maxY - minY }

    init(_ b: Box) { items = [b]; minY = b.minY; maxY = b.maxY }

    mutating func add(_ b: Box) {
        items.append(b)
        // 띠를 합집합으로 키우면 다음 줄까지 삼킨다 — 평균 높이로 유지
        let n = CGFloat(items.count)
        minY = (minY * (n - 1) + b.minY) / n
        maxY = (maxY * (n - 1) + b.maxY) / n
    }

    /// 가로로 크게 겹치면 같은 줄이 아니라 위아래로 붙은 다른 줄이다.
    func collides(with b: Box) -> Bool {
        items.contains { i in
            let overlap = min(i.maxX, b.maxX) - max(i.minX, b.minX)
            return overlap > 0.3 * min(i.maxX - i.minX, b.maxX - b.minX)
        }
    }
}
