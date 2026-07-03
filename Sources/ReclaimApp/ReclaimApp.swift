import SwiftUI
import AppKit
import ReclaimCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var reportWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationManager.shared.start()
        // Register the daily scan schedule (no-op if already enabled). Needed
        // for drag-to-Applications installs that never ran install.sh.
        ScanAgent.enableIfNeeded()
        // Open the report window so the user sees real UI on first launch
        // (not just a Dock icon and an invisible menu bar item).
        showReportWindow()
    }

    /// Triggered when the user clicks the Dock icon while the app is already
    /// running and there are no visible windows. Re-open the report window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showReportWindow()
        }
        return true
    }

    /// Keep the menu bar item alive after the user closes the report window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showReportWindow() {
        if let win = reportWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: ReportView(model: AppModel.shared))
        let win = NSWindow(contentViewController: host)
        win.title = "Reclaim Report"
        win.setContentSize(NSSize(width: 900, height: 650))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        reportWindow = win
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ReclaimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("Reclaim", systemImage: "externaldrive.badge.minus") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
