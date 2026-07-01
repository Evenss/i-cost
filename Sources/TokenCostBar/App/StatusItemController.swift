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

        button.image = Self.makeMenuBarIcon()
        button.imagePosition = .imageLeading
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

        button.attributedTitle = Self.makeStatusBarTitle(MoneyFormatter.statusBarUSD(value))
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

    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let ring = NSBezierPath()
            ring.appendArc(
                withCenter: NSPoint(x: 9, y: 9),
                radius: 5.3,
                startAngle: 42,
                endAngle: -42,
                clockwise: false
            )
            ring.lineWidth = 1.7
            ring.lineCapStyle = .round
            ring.stroke()

            NSBezierPath(ovalIn: NSRect(x: 11.75, y: 8.05, width: 1.9, height: 1.9)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "TokenCostBar"
        return image
    }

    private static func makeStatusBarTitle(_ title: String) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
                .foregroundColor: NSColor.systemBlue
            ]
        )
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        removeDismissMonitors()
    }
}
