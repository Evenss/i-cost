import AppKit
import Combine
import SwiftUI
import TokenCostBarCore

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(
        model: AppModel,
        openManagement: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configurePopover(openManagement: openManagement, quit: quit)
        bindModel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = Self.makeMenuBarIcon()
        button.imagePosition = .imageLeading
        button.title = MoneyFormatter.statusBarUSD(model.snapshot.todayUSD)
        button.toolTip = "TokenCostBar"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover(openManagement: @escaping () -> Void, quit: @escaping () -> Void) {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 390, height: 390)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                model: model,
                openManagement: openManagement,
                quit: quit
            )
        )
    }

    private func bindModel() {
        model.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.statusItem.button?.title = MoneyFormatter.statusBarUSD(snapshot.todayUSD)
            }
            .store(in: &cancellables)
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let path = NSBezierPath()
            path.move(to: NSPoint(x: 3, y: 11.25))
            path.curve(
                to: NSPoint(x: 7.38, y: 7.25),
                controlPoint1: NSPoint(x: 5.12, y: 11.25),
                controlPoint2: NSPoint(x: 5.18, y: 7.25)
            )
            path.curve(
                to: NSPoint(x: 10.92, y: 10.05),
                controlPoint1: NSPoint(x: 9.1, y: 7.25),
                controlPoint2: NSPoint(x: 9.02, y: 10.05)
            )
            path.curve(
                to: NSPoint(x: 15, y: 5.25),
                controlPoint1: NSPoint(x: 13.02, y: 10.05),
                controlPoint2: NSPoint(x: 12.54, y: 5.25)
            )
            path.lineWidth = 1.65
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            NSBezierPath(ovalIn: NSRect(x: 13.65, y: 3.9, width: 2.7, height: 2.7)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "TokenCostBar"
        return image
    }
}
