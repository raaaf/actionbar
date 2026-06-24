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
        ) { _, _ in }
    }

    // MARK: - Send notification for completed run

    func notifyRunCompleted(_ run: WorkflowRun) {
        let request = UNNotificationRequest(
            identifier: "run-\(run.id)",
            content: Self.makeContent(for: run),
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Builds the notification payload for a completed run. Pure (no delivery) so it can be unit-tested.
    static func makeContent(for run: WorkflowRun) -> UNMutableNotificationContent {
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

        content.sound = .default
        if run.conclusion == .failure {
            content.interruptionLevel = .timeSensitive
        }

        // Store the HTML URL so we can open it when clicked
        content.userInfo = ["url": run.htmlUrl]

        return content
    }

    // MARK: - Handle notification click → open in browser

    /// Parses the stored run URL from a notification's userInfo. Pure, so it can be unit-tested;
    /// the github-host trust check happens in `URL.openIfGitHub`.
    static func notificationURL(from userInfo: [AnyHashable: Any]) -> URL? {
        // Require an https URL up front (defence in depth); the github-host check is in openIfGitHub.
        guard let urlString = userInfo["url"] as? String, urlString.hasPrefix("https://") else { return nil }
        return URL(string: urlString)
    }

    /// Presentation options used when a notification arrives while the app is in the foreground.
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .sound]

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Self.notificationURL(from: response.notification.request.content.userInfo)?.openIfGitHub()
        completionHandler()
    }

    // MARK: - Show notification even when app is in foreground

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(Self.foregroundPresentationOptions)
    }
}
