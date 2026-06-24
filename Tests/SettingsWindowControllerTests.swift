import XCTest
import AppKit
@testable import ActionBar

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    private let title = "ActionBar Settings"

    private func settingsWindows() -> [NSWindow] {
        NSApp.windows.filter { $0.title == title }
    }

    override func tearDown() {
        settingsWindows().forEach { $0.close() }
        super.tearDown()
    }

    // row: ui-settings-window
    func testShowCreatesWindowAndReusesIt() {
        let vm = AppViewModel(bootstrap: false)

        SettingsWindowController.show(viewModel: vm)
        let afterFirst = settingsWindows().count
        XCTAssertEqual(afterFirst, 1, "a settings window is created")

        // Showing again reuses the existing visible window instead of opening a second one.
        SettingsWindowController.show(viewModel: vm)
        XCTAssertEqual(settingsWindows().count, 1, "window is reused, not duplicated")
    }
}
