import XCTest
@testable import ActionBar

@MainActor
final class AppViewModelTests: XCTestCase {
    private func makeVM() -> AppViewModel {
        // bootstrap: false keeps the test off the notification prompt and the real Keychain.
        AppViewModel(bootstrap: false)
    }

    // row: vm-failure-count
    func testFailureCountCountsCompletedFailures() {
        let vm = makeVM()
        vm.runs = [
            Fixtures.run(id: 1, status: "completed", conclusion: "failure"),
            Fixtures.run(id: 2, status: "completed", conclusion: "success"),
            Fixtures.run(id: 3, status: "in_progress", conclusion: nil),
            Fixtures.run(id: 4, status: "completed", conclusion: "failure"),
        ]
        XCTAssertEqual(vm.failureCount, 2)
    }

    // row: vm-menubar-icon
    func testMenuBarIconReflectsState() {
        let vm = makeVM()

        vm.isAuthenticated = false
        XCTAssertEqual(vm.menuBarIcon, "gearshape")

        vm.isAuthenticated = true
        vm.isLoading = true
        vm.loadingFrame = 0
        XCTAssertEqual(vm.menuBarIcon, "circle.dashed")

        vm.isLoading = false
        vm.runs = []
        XCTAssertEqual(vm.menuBarIcon, "checkmark.circle.fill")

        vm.runs = [Fixtures.run(id: 1, status: "completed", conclusion: "failure")]
        XCTAssertEqual(vm.menuBarIcon, "xmark.circle.fill")
    }

    // row: vm-runs-grouping
    func testRunsByRepoGroupsAndSorts() {
        let vm = makeVM()
        vm.runs = [
            Fixtures.run(id: 1, repo: "raaaf/a", updatedAt: "2026-06-11T10:00:00Z"),
            Fixtures.run(id: 2, repo: "raaaf/a", updatedAt: "2026-06-11T12:00:00Z"),
            Fixtures.run(id: 3, repo: "raaaf/b", updatedAt: "2026-06-11T11:00:00Z"),
        ]
        vm.updateRunsByRepo()

        XCTAssertEqual(vm.runsByRepo.map(\.repoName), ["raaaf/a", "raaaf/b"], "groups ordered by newest run")
        XCTAssertEqual(vm.runsByRepo[0].runs.map(\.id), [2, 1], "within-group desc by updatedAt")
        XCTAssertEqual(vm.runsByRepo[1].runs.map(\.id), [3])
    }

    // row: vm-notify-transition
    func testNotifyOnlyOnTransitionNotFirstLoad() {
        let vm = makeVM()
        var notified: [Int] = []
        vm.onNotifyRunCompleted = { notified.append($0.id) }

        // First load: no prior runs => record, do not notify.
        vm.runs = []
        vm.checkForCompletedRuns(newRuns: [Fixtures.run(id: 1, status: "completed", conclusion: "success")])
        XCTAssertEqual(notified, [], "no notifications on first load")
        XCTAssertTrue(vm.completedRunIDs.contains(1))

        // Transition: a run we previously saw as in_progress now completes => notify once.
        let vm2 = makeVM()
        vm2.onNotifyRunCompleted = { notified.append($0.id) }
        notified = []
        vm2.runs = [Fixtures.run(id: 2, status: "in_progress", conclusion: nil)]
        let completed = Fixtures.run(id: 2, status: "completed", conclusion: "success")
        vm2.checkForCompletedRuns(newRuns: [completed])
        XCTAssertEqual(notified, [2], "notifies on transition to completed")

        // Same completed run again => already recorded, no second notification.
        vm2.runs = [completed]
        vm2.checkForCompletedRuns(newRuns: [completed])
        XCTAssertEqual(notified, [2], "no duplicate notification")
    }

    // row: vm-notify-bounded
    func testCompletedRunIDsTrimWhenLarge() {
        let vm = makeVM()
        vm.completedRunIDs = Set(1...501)
        vm.runs = [Fixtures.run(id: 999, status: "completed", conclusion: "success")]
        vm.checkForCompletedRuns(newRuns: [])

        XCTAssertEqual(vm.completedRunIDs.count, 300)
        XCTAssertTrue(vm.completedRunIDs.contains(501), "keeps the highest IDs")
        XCTAssertFalse(vm.completedRunIDs.contains(1), "drops the lowest IDs")
    }

    // row: vm-polling-clamp
    func testEffectivePollingIntervalClamped() {
        XCTAssertEqual(AppViewModel.effectivePollingInterval(5), 15)
        XCTAssertEqual(AppViewModel.effectivePollingInterval(15), 15)
        XCTAssertEqual(AppViewModel.effectivePollingInterval(300), 300)
    }

    // row: app-menubar-badge
    func testMenuBarBadgeAndAccessibilityLabel() {
        let vm = makeVM()

        vm.runs = []
        XCTAssertEqual(vm.menuBarBadgeText, "")
        XCTAssertEqual(vm.menuBarAccessibilityLabel, "ActionBar")

        vm.runs = [
            Fixtures.run(id: 1, status: "completed", conclusion: "failure"),
            Fixtures.run(id: 2, status: "completed", conclusion: "failure"),
        ]
        XCTAssertEqual(vm.menuBarBadgeText, "2")
        XCTAssertEqual(vm.menuBarAccessibilityLabel, "ActionBar, 2 failed workflow runs")
    }

    // row: vm-menu-content
    func testMenuContentPrecedence() {
        let vm = makeVM()

        vm.isAuthenticated = false
        vm.isLoading = true
        vm.runs = [Fixtures.run(id: 1)]
        XCTAssertEqual(vm.menuContent, .unauthenticated, "auth gate wins")

        vm.isAuthenticated = true
        vm.runs = []
        vm.isLoading = true
        XCTAssertEqual(vm.menuContent, .loading, "empty + loading")

        vm.isLoading = false
        XCTAssertEqual(vm.menuContent, .empty, "empty, not loading")

        vm.runs = [Fixtures.run(id: 1)]
        XCTAssertEqual(vm.menuContent, .runs)
    }

    // row: vm-loading-frames
    func testLoadingFrameCyclesAndMapsToSymbols() {
        // Index cycles 0 -> 1 -> 2 -> 0.
        XCTAssertEqual(AppViewModel.nextLoadingFrame(0), 1)
        XCTAssertEqual(AppViewModel.nextLoadingFrame(1), 2)
        XCTAssertEqual(AppViewModel.nextLoadingFrame(2), 0)

        // menuBarIcon maps each frame index to its symbol while loading.
        let vm = makeVM()
        vm.isAuthenticated = true
        vm.isLoading = true
        for (index, symbol) in AppViewModel.loadingFrames.enumerated() {
            vm.loadingFrame = index
            XCTAssertEqual(vm.menuBarIcon, symbol, "frame \(index)")
        }
    }

    // row: vm-sign-out
    func testSignOutClearsState() {
        let vm = makeVM()
        vm.runs = [Fixtures.run(id: 1)]
        vm.updateRunsByRepo()
        vm.username = "raaaf"
        vm.isAuthenticated = true
        vm.openIssuesByRepo = ["raaaf/app": 3]
        vm.completedRunIDs = [1]

        vm.signOut()

        XCTAssertTrue(vm.runs.isEmpty)
        XCTAssertTrue(vm.runsByRepo.isEmpty)
        XCTAssertNil(vm.username)
        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertTrue(vm.openIssuesByRepo.isEmpty)
        XCTAssertTrue(vm.completedRunIDs.isEmpty)
    }
}
