import XCTest
@testable import ActionBar

/// User-facing copy logic extracted from views (pluralization) so it can be unit-tested.
final class ViewCopyTests: XCTestCase {
    // row: ui-failed-repos-label
    func testFailedReposLabelPluralizes() {
        XCTAssertEqual(MenuBarView.failedReposLabel(1), "1 repo could not be fetched")
        XCTAssertEqual(MenuBarView.failedReposLabel(3), "3 repos could not be fetched")
        XCTAssertEqual(MenuBarView.failedReposLabel(0), "0 repos could not be fetched")
    }

    // row: ui-issue-badge-label
    func testIssueBadgeLabelPluralizes() {
        XCTAssertEqual(RepoHeaderView.issueBadgeLabel(1), "1 issue")
        XCTAssertEqual(RepoHeaderView.issueBadgeLabel(5), "5 issues")
    }
}
