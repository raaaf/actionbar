import XCTest
import SwiftUI
import ViewInspector
@testable import ActionBar

@MainActor
final class MenuBarViewInspectionTests: XCTestCase {
    private func makeVM() -> AppViewModel { AppViewModel(bootstrap: false) }

    // row: ui-menu-states
    func testMenuRendersSectionForEachState() throws {
        // Unauthenticated -> token prompt.
        let unauth = makeVM()
        unauth.isAuthenticated = false
        XCTAssertNoThrow(try MenuBarView(viewModel: unauth).inspect().find(text: "No GitHub token configured"))

        // Authenticated, empty, loading -> loading copy.
        let loading = makeVM()
        loading.isAuthenticated = true
        loading.runs = []
        loading.isLoading = true
        XCTAssertNoThrow(try MenuBarView(viewModel: loading).inspect().find(text: "Fetching workflow runs..."))

        // Authenticated, empty, not loading -> empty copy.
        let empty = makeVM()
        empty.isAuthenticated = true
        empty.runs = []
        empty.isLoading = false
        XCTAssertNoThrow(try MenuBarView(viewModel: empty).inspect().find(text: "No recent workflow runs"))

        // Authenticated with runs -> repo section header is rendered.
        let withRuns = makeVM()
        withRuns.isAuthenticated = true
        withRuns.runs = [Fixtures.run(id: 1, repo: "raaaf/app")]
        withRuns.updateRunsByRepo()
        XCTAssertNoThrow(try MenuBarView(viewModel: withRuns).inspect().find(text: "raaaf/app"))
    }

    // row: ui-menu-error-banner
    func testMenuRendersErrorAndFailedReposBanners() throws {
        let vm = makeVM()
        vm.isAuthenticated = true
        vm.runs = [Fixtures.run(id: 1, repo: "raaaf/app")]
        vm.updateRunsByRepo()
        vm.error = "Invalid or expired token"
        vm.failedRepos = ["raaaf/x", "raaaf/y"]

        let view = MenuBarView(viewModel: vm)
        XCTAssertNoThrow(try view.inspect().find(text: "Invalid or expired token"))
        XCTAssertNoThrow(try view.inspect().find(text: "2 repos could not be fetched"))
    }

    // row: ui-repo-header
    func testRepoHeaderShowsNameAndConditionalIssueBadge() throws {
        // With open issues -> badge present.
        let withIssues = RepoHeaderView(repoName: "raaaf/app", openIssueCount: 3)
        XCTAssertNoThrow(try withIssues.inspect().find(text: "raaaf/app"))
        XCTAssertNoThrow(try withIssues.inspect().find(text: "3 issues"))

        // Zero issues -> no badge.
        let noIssues = RepoHeaderView(repoName: "raaaf/app", openIssueCount: 0)
        XCTAssertThrowsError(try noIssues.inspect().find(text: "0 issues"))
    }

    // row: ui-run-row
    func testRunRowShowsRunDetails() throws {
        let vm = makeVM()
        let run = Fixtures.run(
            id: 1, status: "completed", conclusion: "failure",
            repo: "raaaf/app", name: "CI", displayTitle: "Broken build",
            headBranch: "main", event: "push"
        )
        let row = RunRowView(run: run, viewModel: vm, isRerunning: false)

        XCTAssertNoThrow(try row.inspect().find(text: "Broken build"))
        XCTAssertNoThrow(try row.inspect().find(text: "main"))
        XCTAssertNoThrow(try row.inspect().find(text: "push"))
        XCTAssertNoThrow(try row.inspect().find(text: "Failure"))
    }

    // row: ui-run-row-actions
    func testRunRowShowsRerunOnlyWhenCompleted() throws {
        let vm = makeVM()

        // Buttons counted by ViewInspector = the visible toolbar buttons PLUS the
        // `accessibilityActions` buttons (which carry the same gating). The re-run action exists
        // only for completed runs, so a completed row exposes 2 more buttons than an in-progress one.
        let completed = RunRowView(
            run: Fixtures.run(id: 1, status: "completed", conclusion: "success"),
            viewModel: vm, isRerunning: false
        )
        let running = RunRowView(
            run: Fixtures.run(id: 2, status: "in_progress", conclusion: nil),
            viewModel: vm, isRerunning: false
        )

        let completedButtons = try completed.inspect().findAll(ViewType.Button.self).count
        let runningButtons = try running.inspect().findAll(ViewType.Button.self).count

        XCTAssertEqual(runningButtons, 2, "open action only (visible + accessibility)")
        XCTAssertEqual(completedButtons, 4, "re-run + open (visible + accessibility)")
        XCTAssertEqual(completedButtons - runningButtons, 2, "re-run appears only when completed")
    }
}
