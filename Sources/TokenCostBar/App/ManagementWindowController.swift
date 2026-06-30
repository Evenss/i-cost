import AppKit
import SwiftUI

@MainActor
final class ManagementWindowController: NSWindowController {
    init(model: AppModel) {
        let window = ManagementWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "TokenCostBar"
        window.minSize = NSSize(width: 680, height: 480)
        window.contentViewController = NSHostingController(rootView: ManagementView(model: model))

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showWindow() {
        guard let window else { return }

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
