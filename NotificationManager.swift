import AppKit
import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Request permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Send notification for completed run

    func notifyRunCompleted(_ run: WorkflowRun) {
        let content = UNMutableNotificationContent()

        let repoName = run.repository?.name ?? "Unknown"
        let conclusionText: String

        switch run.conclusion {
        case .success:
            conclusionText = "succeeded"
        case .failure:
            conclusionText = "failed"
        case .cancelled:
            conclusionText = "was cancelled"
        case .timedOut:
            conclusionText = "timed out"
        default:
            conclusionText = "completed"
        }

        content.title = repoName
        content.body = "\(run.resolvedName) \(conclusionText)"

        if run.conclusion == .failure {
            content.interruptionLevel = .critical
            content.sound = .defaultCritical
        } else {
            content.sound = .default
        }

        // Store the HTML URL so we can open it when clicked
        content.userInfo = ["url": run.htmlUrl]

        let request = UNNotificationRequest(
            identifier: "run-\(run.id)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Handle notification click → open in browser

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString),
           url.scheme == "https",
           url.host?.hasSuffix("github.com") == true {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }

    // MARK: - Show notification even when app is in foreground

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
