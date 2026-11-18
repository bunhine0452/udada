import Foundation

// 영상 렌더러는 앱 전체를 끌어오지 않는다. 사용법 장면(GuideKit · GuideScenes · AITour)과 색·글꼴(Theme)이 기대는 이름만 최소로 채운다.
enum DataFile { static let group = "film.udada" }
enum ThemeID: String { case paper, sand, forest, plum, ink }
struct Part { var name: String }
enum Brain {
    enum Status { case ready, off, unavailable(String) }
    static func modelStatus() -> Status { .ready }
}
