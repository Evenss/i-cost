import AppKit
import TokenCostBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItemController: StatusItemController?
    private var managementWindowController: ManagementWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistrar.registerBundledFonts()

        do {
            let store = try SQLiteStore()
            let coordinator = ScanCoordinator(store: store)
            let model = AppModel(coordinator: coordinator)
            self.model = model

            statusItemController = StatusItemController(
                model: model,
                openManagement: { [weak self] in
                    self?.showManagementWindow()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )

            model.refresh()
            model.startAutoRefresh()
        } catch {
            let model = AppModel(errorMessage: error.localizedDescription)
            self.model = model
            statusItemController = StatusItemController(
                model: model,
                openManagement: { [weak self] in
                    self?.showManagementWindow()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        }
    }

    private func showManagementWindow() {
        guard let model else { return }

        if managementWindowController == nil {
            managementWindowController = ManagementWindowController(model: model)
        }

        managementWindowController?.showWindow()
    }
}
