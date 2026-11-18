import AppKit
import Carbon.HIToolbox
import SwiftUI

// 어디서나 ⌃⌥Space → 화면 가운데 한 줄. 치는 대로 읽고, ↩ 로 넣으면 몇 초 뒤 iPhone 에도 있다.

/// 전역 단축키 (Carbon — 손쉬운 사용 권한이 필요 없다)
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private static var action: (() -> Void)?

    init(keyCode: Int = kVK_Space, modifiers: Int = controlKey | optionKey, action: @escaping () -> Void) {
        HotKey.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.action?()
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x5544_4144), id: 1) // 'UDAD'
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { QuickAddPanel.shared.hide() }
}

@MainActor
final class QuickAddPanel: NSObject, NSWindowDelegate {
    static let shared = QuickAddPanel()
    private var panel: NSPanel?

    func toggle(store: Store, ticker: Ticker) {
        if let p = panel, p.isVisible { hide(); return }
        show(store: store, ticker: ticker)
    }

    func show(store: Store, ticker: Ticker) {
        let p = panel ?? make()
        panel = p
        p.contentView = NSHostingView(rootView: QuickAddView().environment(store).environment(ticker))
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let f = screen.visibleFrame
            let size = NSSize(width: 620, height: 150)
            p.setFrame(NSRect(x: f.midX - size.width / 2, y: f.minY + f.height * 0.62, width: size.width, height: size.height), display: true)
        }
        p.makeKeyAndOrderFront(nil)
    }

    func hide() { panel?.orderOut(nil) }

    private func make() -> NSPanel {
        let p = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isMovableByWindowBackground = true
        p.delegate = self
        return p
    }

    /// 다른 곳을 누르면 닫힌다
    func windowDidResignKey(_ notification: Notification) { hide() }
}

struct QuickAddView: View {
    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var placed: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AddField(text: $text, large: true, prompt: "내일 3시 치과", onAdded: { said in
                withAnimation(.easeOut(duration: 0.15)) { placed = said }
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    QuickAddPanel.shared.hide()
                    placed = nil
                }
            }, onCancel: { QuickAddPanel.shared.hide() }, focused: $focused)
            Spacer(minLength: 10)
            Hairline()
            HStack(spacing: 6) {
                if let placed {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Ink.accent)
                    Text(placed).font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.text)
                    if store.settings.syncOn, CloudSync.shared.phase != .off {
                        Text("· iPhone 에도 가고 있어").font(.system(size: 12)).foregroundStyle(Ink.text3)
                    }
                } else {
                    Text("우다다").font(Typo.serif(12)).foregroundStyle(Ink.text2)
                    Text("날짜·시각·길이를 그냥 말하듯 써").font(.system(size: 11.5)).foregroundStyle(Ink.text3)
                }
                Spacer()
                KeyCap(text: "↩"); Text("넣기").font(.system(size: 11)).foregroundStyle(Ink.text3)
                KeyCap(text: "esc"); Text("닫기").font(.system(size: 11)).foregroundStyle(Ink.text3)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 620, height: 150, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.sheet))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
        .onAppear { focused = true; text = ""; placed = nil }
    }
}
