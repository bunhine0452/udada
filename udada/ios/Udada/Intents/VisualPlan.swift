// 시뮬레이터 SDK 에는 VisualIntelligence 가 없다 → 기기 빌드에서만 들어간다
#if os(iOS) && canImport(VisualIntelligence)
import AppIntents
import CoreImage
import Foundation
import VisualIntelligence

// 시각 지능(카메라 컨트롤을 길게 눌러 비추기 · 화면 캡처에서 검색): 포스터·안내문을 비추면 시스템 화면에 우다다가 찾은 일정이 뜨고,
// 하나를 누르면 그 줄이 넣기 칸에 채워진 채 앱이 열린다 (확인하고 넣는다 — 바로 넣지 않는다).
// 읽는 길은 앱 안 '사진으로 넣기'와 같다: 글자 인식 → 표면 칸 구조 → 그림을 볼 수 있으면 Apple Intelligence → 글자 인식 결과와 맞춰 보기.

/// 비춘 것에서 찾은 일정 한 줄. 저장하지 않는다 — id 가 곧 그 줄이다.
@available(iOS 26.0, *)
struct SeenPlanEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "찾은 일정")
    static let defaultQuery = SeenPlanQuery()

    /// "11월 20일 오후 7시 30분 가을 정기 연주회"
    var id: String

    var displayRepresentation: DisplayRepresentation {
        let p = Parser.parse(id)
        let when = [p.day.map { "\($0.m)월 \($0.d)일" }, p.time.map(Fmt.hm)].compactMap { $0 }.joined(separator: " ")
        return DisplayRepresentation(title: "\(p.title.isEmpty ? id : p.title)", subtitle: when.isEmpty ? "우다다에 넣기" : "\(when) · 우다다에 넣기",
                                     image: .init(systemName: p.time != nil ? "clock" : "square"))
    }
}

@available(iOS 26.0, *)
struct SeenPlanQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SeenPlanEntity] { identifiers.map { SeenPlanEntity(id: $0) } }
    func suggestedEntities() async throws -> [SeenPlanEntity] { [] }
}

/// 시스템이 비춘 그림을 넘기면 찾은 일정들을 돌려준다
@available(iOS 26.0, *)
struct SeenPlanValueQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [SeenPlanEntity] {
        guard let buffer = input.pixelBuffer else { return [] }
        let image: CGImage? = buffer.withUnsafeBuffer { pb in
            let ci = CIImage(cvPixelBuffer: pb)
            return CIContext().createCGImage(ci, from: ci.extent)
        }
        guard let image else { return [] }
        let ocr = await TextScan.recognize(image)
        guard !ocr.isEmpty else { return [] }
        let seen = await Brain.shared.readPhoto(image, ocr: ocr)
        // 모델이 못 본 기기에서는 날짜가 읽히는 줄만 (군말 줄을 일정이라고 내밀지 않게)
        let lines = seen.fromAI ? seen.lines : seen.lines.filter { Parser.parse($0).day != nil }
        return lines.prefix(8).map { SeenPlanEntity(id: $0) }
    }
}

/// 찾은 일정을 누르면: 넣기 칸에 그 줄을 채워 앱을 연다
@available(iOS 26.0, *)
struct OpenSeenPlanIntent: OpenIntent {
    static let title: LocalizedStringResource = "우다다에 넣기"
    static let openAppWhenRun = true
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "찾은 일정")
    var target: SeenPlanEntity

    init() {}
    init(target: SeenPlanEntity) { self.target = target }

    @MainActor
    func perform() async throws -> some IntentResult {
        var c = URLComponents(); c.scheme = "udada"; c.host = "add"
        c.queryItems = [URLQueryItem(name: "text", value: target.id)]
        if let u = c.url { await AppOpener.open(u) }
        return .result()
    }
}
#endif
