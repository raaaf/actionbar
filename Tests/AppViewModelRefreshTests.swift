import XCTest
@testable import ActionBar

@MainActor
final class AppViewModelRefreshTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeVM() -> AppViewModel {
        let vm = AppViewModel(bootstrap: false)
        vm.service = GitHubService(token: "tok", session: MockURLProtocol.makeSession())
        return vm
    }

    // row: vm-refresh-pipeline
    func testRefreshPopulatesStateAndNotifies() async {
        let reposBody = """
        [{"id":1,"full_name":"raaaf/a","html_url":"https://github.com/raaaf/a","open_issues_count":4}]
        """
        let runsBody = """
        {"total_count":1,"workflow_runs":[
          {"id":100,"status":"completed","conclusion":"success",
           "html_url":"https://github.com/raaaf/a/actions/runs/100",
           "created_at":"2026-06-11T10:00:00Z","updated_at":"2026-06-11T10:05:00Z","run_number":1,
           "repository":{"id":1,"name":"a","full_name":"raaaf/a","html_url":"https://github.com/raaaf/a"}}
        ]}
        """
        MockURLProtocol.handler = { req in
            let body = req.url!.path == "/user/repos" ? reposBody : runsBody
            return (MockURLProtocol.response(req.url!, status: 200), Data(body.utf8))
        }

        let vm = makeVM()
        var notified: [Int] = []
        vm.onNotifyRunCompleted = { notified.append($0.id) }
        // Prior snapshot: run 100 was in progress, so refresh sees a transition -> notifies.
        vm.runs = [Fixtures.run(id: 100, status: "in_progress", conclusion: nil, repo: "raaaf/a")]

        await vm.refresh()

        XCTAssertEqual(vm.runs.map(\.id), [100])
        XCTAssertEqual(vm.openIssuesByRepo["raaaf/a"], 4)
        XCTAssertEqual(vm.runsByRepo.first?.repoName, "raaaf/a")
        XCTAssertNotNil(vm.lastRefresh)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
        XCTAssertEqual(notified, [100], "completion transition fires a notification")
    }

    // row: vm-refresh-error
    func testRefreshSetsErrorOnFailure() async {
        MockURLProtocol.handler = { req in
            (MockURLProtocol.response(req.url!, status: 401), Data("{}".utf8))
        }

        let vm = makeVM()
        await vm.refresh()

        XCTAssertEqual(vm.error, "Invalid or expired token")
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.runs.isEmpty)
    }
}
