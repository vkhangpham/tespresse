import AppKit
import SwiftUI

@main
struct TesPresseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var alarmManager = AlarmManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(alarmManager)
        } label: {
            Label("T'es pressé ?", systemImage: alarmManager.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var challengeWindowController: ChallengeWindowController?
    private var controlCenterWindowController: ControlCenterWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        challengeWindowController = ChallengeWindowController(manager: .shared)
        controlCenterWindowController = ControlCenterWindowController(manager: .shared)
        if let challengeWindowController {
            AlarmManager.shared.attachWindowController(challengeWindowController)
        }
        if let controlCenterWindowController {
            AlarmManager.shared.attachControlCenterWindowController(controlCenterWindowController)
        }
        AlarmManager.shared.bootstrap()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
