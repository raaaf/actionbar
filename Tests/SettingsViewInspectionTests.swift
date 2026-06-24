import XCTest
import SwiftUI
import ViewInspector
@testable import ActionBar

@MainActor
final class SettingsViewInspectionTests: XCTestCase {
    private func makeVM() -> AppViewModel { AppViewModel(bootstrap: false) }

    // row: ui-settings-authenticated
    func testAuthenticatedShowsSignOut() throws {
        let vm = makeVM()
        vm.isAuthenticated = true
        vm.username = "raaaf"
        let view = SettingsView(viewModel: vm)

        XCTAssertNoThrow(try view.inspect().find(button: "Sign Out"))
        // The token entry button must be absent when already authenticated.
        XCTAssertThrowsError(try view.inspect().find(button: "Authenticate"))
    }

    // row: ui-settings-unauthenticated
    func testUnauthenticatedShowsTokenFormAndControls() throws {
        let vm = makeVM()
        vm.isAuthenticated = false
        let view = SettingsView(viewModel: vm)

        XCTAssertNoThrow(try view.inspect().find(text: "GitHub Personal Access Token"))
        XCTAssertNoThrow(try view.inspect().find(button: "Authenticate"))
        // Polling + notification controls are present.
        XCTAssertNoThrow(try view.inspect().find(text: "Max repos to check: 20"))
        XCTAssertNoThrow(try view.inspect().find(text: "Notify on workflow completion"))
    }
}
