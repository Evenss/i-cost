import AppKit
import SwiftUI

@MainActor
final class ManagementWindowController: NSWindowController {
    private let navigation = ManagementNavigation()

    init(model: AppModel) {
        let window = ManagementWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "iCost"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.collectionBehavior.insert(.fullScreenNone)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 840, height: 600)
        window.contentViewController = NSHostingController(
            rootView: ManagementView(model: model, navigation: navigation)
        )
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showWindow(selectedTab: ManagementTab = .sources) {
        guard let window else { return }

        navigation.selectedTab = selectedTab

        if !window.isVisible {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class ManagementWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.type == .keyDown,
           flags == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }

        if event.type == .keyDown,
           flags == .command,
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
