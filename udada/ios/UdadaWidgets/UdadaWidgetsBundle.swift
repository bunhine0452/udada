import SwiftUI
import WidgetKit

// 우다다 위젯 확장: 홈 화면 「오늘」 · 잠금 화면 「지금」 · 식히기/집중 실시간 현황 · 제어 센터 버튼 셋.
@main
struct UdadaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        NowWidget()
        UdadaActivityWidget()
        BreathControl()
        AddControl()
        DumpControl()
    }
}
