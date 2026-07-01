import AppKit
import Darwin
import Foundation
import TokenCostBarCore

if CommandLine.arguments.contains("--scan-once") {
    do {
        let store = try SQLiteStore()
        let coordinator = ScanCoordinator(store: store)
        let summary = try coordinator.scanAll()
        let snapshot = summary.snapshot

        print("Inserted events: \(summary.insertedEventCount)")
        print("Today: \(MoneyFormatter.usd(snapshot.todayUSD)) / \(MoneyFormatter.cny(snapshot.todayCNY))")
        print("This week: \(MoneyFormatter.usd(snapshot.weekUSD))")

        if snapshot.agentTotals.isEmpty {
            print("Agents: no usage today")
        } else {
            print("Agents:")
            for agent in snapshot.agentTotals {
                print("- \(agent.source.displayName): \(MoneyFormatter.usd(agent.costUSD))")
            }
        }

        exit(0)
    } catch {
        fputs("iCost scan failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
