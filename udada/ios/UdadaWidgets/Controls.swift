import AppIntents
import SwiftUI
import WidgetKit

// 제어 센터·잠금 화면·동작 버튼: 누르면 앱이 그 화면으로 열린다.

struct BreathControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "udada.control.breath") {
            ControlWidgetButton(action: UdadaControlOpenIntent(path: "rest/breath")) {
                Label("1분 숨", systemImage: "wind")
            }
        }
        .displayName("1분 숨")
        .description("바로 숨 고르기를 시작해.")
    }
}

struct AddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "udada.control.add") {
            ControlWidgetButton(action: UdadaControlOpenIntent(path: "add")) {
                Label("적기", systemImage: "plus")
            }
        }
        .displayName("적기")
        .description("넣기 줄에 바로 커서를 둬.")
    }
}

struct DumpControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "udada.control.dump") {
            ControlWidgetButton(action: UdadaControlOpenIntent(path: "dump")) {
                Label("쏟아내기", systemImage: "tray.and.arrow.down")
            }
        }
        .displayName("쏟아내기")
        .description("머릿속에 있는 걸 다 적어.")
    }
}
