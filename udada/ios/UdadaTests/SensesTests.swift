import CoreGraphics
import XCTest
@testable import Udada

// 말로 쏟아내기 · 사진으로 옮기기의 순수 규칙 (Vision · 마이크 없이).
// 같은 사례를 scratchpad 하네스가 macOS 에서 실제 Vision · SpeechAnalyzer 와 함께 돌렸다.

final class SensesTests: XCTestCase {
    typealias F = TextScan.Fragment
    typealias T = VoiceInput.Transcript

    // MARK: - 받아쓰기 조립

    func testAnalyzerStyle() {
        var t = T()
        let a = t.begin()
        t.volatile("엄마한테 전화", part: a)
        XCTAssertEqual(t.text, "엄마한테 전화")
        t.final("엄마한테 전화해야 하고", part: a)
        t.volatile(" 보고서", part: a)
        XCTAssertEqual(t.text, "엄마한테 전화해야 하고 보고서")
        let b = t.begin()
        t.volatile("은행 가기", part: b)
        t.final("보고서 세 장", part: a)
        t.close(a)
        XCTAssertEqual(t.text, "엄마한테 전화해야 하고 보고서 세 장\n은행 가기")
        t.final("늦게 온 글", part: a)
        XCTAssertEqual(t.text, "엄마한테 전화해야 하고 보고서 세 장\n은행 가기")
        t.close(b)
        XCTAssertTrue(t.isClosed(a) && t.isClosed(b))
        t.clear()
        XCTAssertEqual(t.text, "")
    }

    func testRecognizerStyle() {
        var s = T()
        let c = s.begin()
        s.cumulative("엄마한테 전화", final: false, part: c)
        s.cumulative("엄마한테 전화해야 돼", final: true, part: c)
        s.cumulative("보고서", final: false, part: c) // 마디 끝 뒤 처음부터 다시
        XCTAssertEqual(s.text, "엄마한테 전화해야 돼 보고서")

        var u = T()
        let d = u.begin()
        u.cumulative("은행 가기", final: true, part: d)
        u.cumulative("은행 가기 택배", final: false, part: d) // 앞부분을 이어서 보냄
        XCTAssertEqual(u.text, "은행 가기 택배")

        var w = T()
        let e = w.begin()
        w.cumulative("엄마한테 전화하고 보고서 쓰기", final: false, part: e)
        w.cumulative("택배", final: false, part: e) // 확정 없이 새로 시작
        XCTAssertEqual(w.text, "엄마한테 전화하고 보고서 쓰기 택배")

        var x = T()
        let f = x.begin()
        x.cumulative("보고서 세 장 써야 돼 그리고", final: false, part: f)
        x.cumulative("보고서 세 장", final: false, part: f) // 고쳐 쓰기
        XCTAssertEqual(x.text, "보고서 세 장")
        x.taskEnded(part: f)
        x.cumulative("은행", final: false, part: f) // 작업 이어 달리기
        XCTAssertEqual(x.text, "보고서 세 장 은행")
    }

    // MARK: - 줄 묶기

    func testGroupsRowsTopToBottom() {
        XCTAssertEqual(TextScan.lines(from: [
            F("치과 예약", x: 300, y: 500, w: 200, h: 40),
            F("14:30", x: 40, y: 504, w: 90, h: 36),
            F("팀 회의", x: 300, y: 600, w: 160, h: 40),
            F("10:00", x: 40, y: 598, w: 90, h: 40),
        ]), ["10:00 팀 회의", "14:30 치과 예약"])
        XCTAssertEqual(TextScan.lines(from: [
            F("우유 사기", x: 40, y: 100, w: 200, h: 40),
            F("빨래 개기", x: 40, y: 135, w: 200, h: 40),
        ]), ["빨래 개기", "우유 사기"])
    }

    func testSkewedRows() {
        func rot(_ f: F, _ deg: CGFloat) -> F {
            let a = deg * .pi / 180
            func r(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * cos(a) - p.y * sin(a), y: p.x * sin(a) + p.y * cos(a)) }
            return F(text: f.text, confidence: 1, topLeft: r(f.topLeft), topRight: r(f.topRight), bottomRight: r(f.bottomRight), bottomLeft: r(f.bottomLeft))
        }
        XCTAssertEqual(TextScan.lines(from: [
            rot(F("엄마한테", x: 100, y: 400, w: 160, h: 40), 10), rot(F("전화", x: 290, y: 400, w: 80, h: 40), 10),
            rot(F("은행", x: 100, y: 330, w: 80, h: 40), 10), rot(F("가기", x: 200, y: 330, w: 80, h: 40), 10),
        ]), ["엄마한테 전화", "은행 가기"])
    }

    // MARK: - 다듬기

    func testStripsMarks() {
        XCTAssertEqual(TextScan.clean([
            "□ 엄마한테 전화", "☐보고서 3장 쓰기", "- 택배 반품 신청", "✓ 은행 가기", "ㅁ 장보기", "口세탁소",
            "1. 이력서 고치기", "• 물 마시기", "[ ] 머리 자르기", "V 우체국", "[ 서류 제출",
        ]), ["엄마한테 전화", "보고서 3장 쓰기", "택배 반품 신청", "은행 가기", "장보기", "세탁소",
             "이력서 고치기", "물 마시기", "머리 자르기", "우체국", "서류 제출"])
    }

    func testDropsNoise() {
        XCTAssertEqual(TextScan.clean(["3", "- 12 -", "□", "11월 15일 (일)", "2026.11.15", "10:00", "잠", "3시 회의", "월세 내기", "월세 내기"]),
                       ["잠", "3시 회의", "월세 내기"])
        XCTAssertEqual(TextScan.clean(["그 사람한테 연락", "O2 충전", "Vlog 편집"]), ["그 사람한테 연락", "O2 충전", "Vlog 편집"])
    }

    func testSettlesUnsureLead() {
        XCTAssertEqual(TextScan.settleLead(["그 엄마한테 전화", "_ 엄마한테 전화", "- 엄마한테 전화"]), "엄마한테 전화")
        XCTAssertEqual(TextScan.settleLead(["그 사람한테 연락", "그 사람한테 연락처"]), "그 사람한테 연락")
    }
}
