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
            let model = AppModel(store: store)
            self.model = model

            statusItemController = StatusItemController(
                model: model,
                openManagement: { [weak self] tab in
                    self?.showManagementWindow(selectedTab: tab)
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
                openManagement: { [weak self] tab in
                    self?.showManagementWindow(selectedTab: tab)
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        }
    }

    private func showManagementWindow(selectedTab: ManagementTab = .sources) {
        guard let model else { return }

        if managementWindowController == nil {
            managementWindowController = ManagementWindowController(model: model)
        }

        managementWindowController?.showWindow(selectedTab: selectedTab)
    }
}
