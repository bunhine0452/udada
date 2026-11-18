import XCTest
import AppIntents
import UniformTypeIdentifiers
@testable import Udada

// 화면 그대로 인텐트를 단축어가 부르듯 직접 실행한다: 대화 그림 → 실제 글자 인식 → 답장 문장, 답장 버튼 → 복사 + 약속 넣기.
// 날짜는 실행하는 날 기준이라 요일 대신 "내일"로 쓴다.

@MainActor
final class ScreenIntentTests: XCTestCase {
    private func chat(_ bubbles: [(mine: Bool, text: String)]) -> Data {
        let size = CGSize(width: 1206, height: 2622)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).pngData { ctx in
            UIColor(red: 0.73, green: 0.81, blue: 0.88, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let font = UIFont.systemFont(ofSize: 48)
            var y: CGFloat = 420
            for b in bubbles {
                let s = NSAttributedString(string: b.text, attributes: [.font: font, .foregroundColor: UIColor.black])
                let w = s.size().width + 64
                let x = b.mine ? size.width - 50 - w : 180
                (b.mine ? UIColor.yellow : UIColor.white).setFill()
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: 110), cornerRadius: 34).fill()
                s.draw(at: CGPoint(x: x + 32, y: y + 26))
                NSAttributedString(string: "오후 2:13", attributes: [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.darkGray])
                    .draw(at: CGPoint(x: b.mine ? x - 190 : x + w + 16, y: y + 60))
                y += 170
            }
        }
    }

    func testScreenToReplyAndCopy() async throws {
        var intent = ScreenIntent()
        intent.screen = IntentFile(data: chat([(false, "요즘 어떻게 지내"), (true, "그냥 그래"), (false, "내일 7시에 강남역에서 저녁 어때?")]), filename: "screen.png", type: .png)
        let result = try await intent.perform()
        let reply = try XCTUnwrap(result.value)
        XCTAssertFalse(reply.isEmpty, "답장 문장이 나온다")
        XCTAssertTrue(reply.contains("7시") || reply.contains("내일") || reply.contains("좋"), reply)

        // 답장 버튼: 복사하고 약속을 넣는다
        let tomorrow = IntentData.today.adding(days: 1, calendar: .current)
        _ = try await CopyReplyIntent(reply: reply, name: "화면 그대로 시험 약속", day: tomorrow, time: 19 * 60, duration: 90).perform()
        XCTAssertEqual(UIPasteboard.general.string, reply)
        let added = IntentData.read().items.filter { $0.title == "화면 그대로 시험 약속" && $0.day == tomorrow && $0.time == 19 * 60 }
        XCTAssertEqual(added.count, 1)
        await IntentData.write { d in d.items.removeAll { $0.title == "화면 그대로 시험 약속" } }
    }

    func testScreenWithNothing() async throws {
        var intent = ScreenIntent()
        intent.screen = IntentFile(data: chat([(false, "ㅋㅋㅋ 진짜 웃기다"), (true, "그러니까")]), filename: "screen.png", type: .png)
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "")
    }

    func testReceiveKeepsWhatMatters() async throws {
        let before = Inbox.items()
        let note = await ReceiveIntent.receive("[Web발신] [서울밝은치과] 11월 20일(금) 오후 2시 스케일링 예약입니다. 변경은 02-123-4567")
        XCTAssertTrue(note.contains("스케일링"), note)
        let fresh = Inbox.items().filter { !before.contains($0) }
        XCTAssertEqual(fresh.count, 1)
        Inbox.remove(fresh)
        let none = await ReceiveIntent.receive("[Web발신] 인증번호 482913 을 입력해 주세요")
        XCTAssertEqual(none, "")
    }
}
