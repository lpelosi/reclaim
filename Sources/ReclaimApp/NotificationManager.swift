import Foundation
import UserNotifications
import ReclaimCore

/// Posts UN notifications when scanner publishes a Darwin notification.
/// Falls back to a no-op if authorization is denied.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    static let scanCompleteName = Notification.Name("com.reclaim.scanComplete")

    private init() {}

    func start() {
        requestAuth()
        DistributedNotificationCenter.default().addObserver(
            forName: Self.scanCompleteName,
            object: nil,
            queue: .main
        ) { _ in
            Task { await self.handleScanComplete() }
        }
    }

    private func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    private func handleScanComplete() async {
        guard let report = Report.load() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Reclaim scan complete"
        content.body = "\(report.items.count) items · \(report.totalReclaimable.humanSize) reclaimable"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "com.reclaim.scanComplete.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(req)
    }
}
