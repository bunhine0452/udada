import SwiftUI
import UIKit
import AudioToolbox

/// 기계(시안 D)의 색. 파랑은 '다음에 누를 것' 하나에만.
enum Palette {
    static let body = Color(hex: 0xD9D7D1)
    static let body2 = Color(hex: 0xCAC7BF)
    static let edge = Color(hex: 0xA9A69E)
    static let ink = Color(hex: 0x1D1D1B)
    static let ink2 = Color(hex: 0x6F6C65)
    static let lcd = Color(hex: 0xB9C3A8)
    static let seg = Color(hex: 0x1E2619)
    static let blue = Color(hex: 0x2E4BF0)
    static let blue2 = Color(hex: 0x1B2FAE)
    static let paper = Color(hex: 0xF6F4EE)
    static let night = Color(hex: 0x23251F)
    static let lcdOff = Color(hex: 0x1A1D17)
    static let glow = Color(hex: 0xA9C79A)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum Fonts {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .monospaced) }
    static func lcd(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
}

/// 누름·딸깍·차임. 진동은 햅틱 엔진, 소리는 시스템 사운드(무음 스위치를 따른다).
@MainActor
enum Feel {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let select = UISelectionFeedbackGenerator()
    private static let note = UINotificationFeedbackGenerator()

    static func press() { rigid.impactOccurred(intensity: 0.8); AudioServicesPlaySystemSound(1104) }
    static func release() { light.impactOccurred(intensity: 0.4) }
    static func detent() { select.selectionChanged() }
    static func breathe() { soft.impactOccurred(intensity: 0.6) }
    static func step() { rigid.impactOccurred(); AudioServicesPlaySystemSound(1057) }
    static func done() { note.notificationOccurred(.success); AudioServicesPlaySystemSound(1025) }
    /// 파쇄기: 짧은 드르륵
    static func shred() { for i in 0..<9 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) { rigid.impactOccurred(intensity: 0.55) } } }
    static func printReceipt() { for i in 0..<6 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) { soft.impactOccurred(intensity: 0.5) } } }
}
