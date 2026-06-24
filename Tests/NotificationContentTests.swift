import XCTest
import UserNotifications
@testable import ActionBar

final class NotificationContentTests: XCTestCase {
    // row: notif-content
    func testCompletionContent() {
        let success = Fixtures.run(
            id: 1, status: "completed", conclusion: "success",
            repo: "raaaf/app", name: "CI", displayTitle: "Ship it",
            htmlUrl: "https://github.com/raaaf/app/actions/runs/1"
        )
        let content = NotificationManager.makeContent(for: success)

        XCTAssertEqual(content.title, "app", "repo name as title")
        XCTAssertEqual(content.body, "Ship it succeeded")
        XCTAssertEqual(content.sound, .default)
        XCTAssertEqual(content.interruptionLevel, .active, "success is not time-sensitive")
        XCTAssertEqual(content.userInfo["url"] as? String, "https://github.com/raaaf/app/actions/runs/1")

        // Conclusion wording for each handled case.
        XCTAssertEqual(NotificationManager.makeContent(for: Fixtures.run(id: 2, conclusion: "failure", name: "CI", displayTitle: "Build")).body, "Build failed")
        XCTAssertEqual(NotificationManager.makeContent(for: Fixtures.run(id: 3, conclusion: "cancelled", name: "CI", displayTitle: "Build")).body, "Build was cancelled")
        XCTAssertEqual(NotificationManager.makeContent(for: Fixtures.run(id: 4, conclusion: "timed_out", name: "CI", displayTitle: "Build")).body, "Build timed out")
        XCTAssertEqual(NotificationManager.makeContent(for: Fixtures.run(id: 5, conclusion: "neutral", name: "CI", displayTitle: "Build")).body, "Build completed")

        // Failure is escalated to time-sensitive.
        let failure = Fixtures.run(id: 6, conclusion: "failure")
        XCTAssertEqual(NotificationManager.makeContent(for: failure).interruptionLevel, .timeSensitive)
    }

    // row: notif-open-url
    func testNotificationURLResolution() {
        XCTAssertEqual(
            NotificationManager.notificationURL(from: ["url": "https://github.com/raaaf/app/actions/runs/1"]),
            URL(string: "https://github.com/raaaf/app/actions/runs/1")
        )
        XCTAssertNil(NotificationManager.notificationURL(from: [:]), "missing url => nil")
        XCTAssertNil(NotificationManager.notificationURL(from: ["url": 42]), "non-string url => nil")
    }

    // row: notif-foreground
    func testForegroundPresentationOptions() {
        XCTAssertEqual(NotificationManager.foregroundPresentationOptions, [.banner, .sound])
    }
}
