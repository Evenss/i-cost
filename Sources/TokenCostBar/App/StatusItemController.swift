import AppKit
import Combine
import SwiftUI
import TokenCostBarCore

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let quitAction: () -> Void
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var keyboardMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    init(
        model: AppModel,
        openManagement: @escaping (ManagementTab) -> Void,
        quit: @escaping () -> Void
    ) {
        self.model = model
        quitAction = quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configurePopover(openManagement: openManagement)
        bindModel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        updateStatusBarTitle(model.snapshot.todayUSD)
        button.toolTip = "TokenCostBar"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover(openManagement: @escaping (ManagementTab) -> Void) {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 390, height: 444)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                model: model,
                openManagement: openManagement,
                quit: quitAction
            )
        )
    }

    private func bindModel() {
        model.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.updateStatusBarTitle(snapshot.todayUSD)
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarTitle(_ value: Decimal) {
        guard let button = statusItem.button else { return }

        let image = Self.makeStatusBarImage(MoneyFormatter.statusBarUSD(value))
        statusItem.length = image.size.width + 12
        button.image = image
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        installDismissMonitors()
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "q" {
                self.quitAction()
                return nil
            }

            return event
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }

            if self.shouldKeepPopoverOpen(for: event) {
                return event
            }

            self.popover.performClose(nil)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.popover.performClose(nil)
            }
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.popover.performClose(nil)
            }
        }
    }

    private func shouldKeepPopoverOpen(for event: NSEvent) -> Bool {
        if event.window == popover.contentViewController?.view.window {
            return true
        }

        guard let button = statusItem.button, event.window == button.window else {
            return false
        }

        let point = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(point)
    }

    private func removeDismissMonitors() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }

        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private static func makeStatusBarImage(_ title: String) -> NSImage {
        let iconSize: CGFloat = 18
        let spacing: CGFloat = 5
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let title = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
        let titleSize = title.size()
        let size = NSSize(
            width: ceil(iconSize + spacing + titleSize.width),
            height: iconSize
        )

        let image = NSImage(size: size, flipped: false) { rect in
            let iconRect = NSRect(x: rect.minX, y: rect.minY, width: iconSize, height: iconSize)
            drawMenuBarIcon(in: iconRect)

            let titlePoint = NSPoint(
                x: iconRect.maxX + spacing,
                y: floor(rect.midY - titleSize.height / 2)
            )
            title.draw(at: titlePoint)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "TokenCostBar \(title.string)"
        return image
    }

    private static func drawMenuBarIcon(in rect: NSRect) {
        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let center = NSPoint(x: rect.midX, y: rect.midY)
        let ring = NSBezierPath()
        ring.appendArc(
            withCenter: center,
            radius: 5.3,
            startAngle: 42,
            endAngle: -42,
            clockwise: false
        )
        ring.lineWidth = 1.7
        ring.lineCapStyle = .round
        ring.stroke()

        NSBezierPath(
            ovalIn: NSRect(
                x: rect.minX + 11.75,
                y: rect.minY + 8.05,
                width: 1.9,
                height: 1.9
            )
        )
        .fill()
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        removeDismissMonitors()
    }
}
