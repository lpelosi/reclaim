import Foundation
import ServiceManagement

enum LoginItem {
    /// True if Reclaim is registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        let svc = SMAppService.mainApp
        if enabled {
            if svc.status != .enabled {
                try svc.register()
            }
        } else {
            if svc.status == .enabled {
                try svc.unregister()
            }
        }
    }
}

/// Daily background scan, registered from the bundled LaunchAgent
/// (Contents/Library/LaunchAgents/com.reclaim.scanner.plist). Lets the schedule
/// work on machines that installed by dragging the .app to /Applications and
/// never ran install.sh.
enum ScanAgent {
    static let plistName = "com.reclaim.scanner.plist"

    static var isEnabled: Bool {
        SMAppService.agent(plistName: plistName).status == .enabled
    }

    /// Idempotent — safe to call every launch.
    static func enableIfNeeded() {
        let svc = SMAppService.agent(plistName: plistName)
        guard svc.status != .enabled else { return }
        do { try svc.register() } catch {
            NSLog("Reclaim: failed to register scan agent: \(error)")
        }
    }
}
