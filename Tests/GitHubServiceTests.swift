import XCTest
@testable import ActionBar

final class GitHubServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(token: String = "tok") -> GitHubService {
        GitHubService(token: token, session: MockURLProtocol.makeSession())
    }

    // row: service-error-mapping
    func testHTTPStatusMapsToErrors() async throws {
        let cases: [(Int, GitHubError)] = [
            (401, .unauthorized),
            (403, .rateLimited),
            (404, .notFound),
            (500, .httpError(500)),
        ]
        for (status, expected) in cases {
            MockURLProtocol.handler = { req in
                (MockURLProtocol.response(req.url!, status: status), Data("{}".utf8))
            }
            let service = makeService()
            do {
                _ = try await service.fetchRecentRepos()
                XCTFail("expected error for status \(status)")
            } catch let error as GitHubError {
                XCTAssertEqual(error, expected, "status \(status)")
            }
        }
    }

    // row: service-etag-cache
    func testETagConditionalGETReusesCache() async throws {
        let body = Data("""
        [{"id":1,"full_name":"raaaf/a","html_url":"https://github.com/raaaf/a","open_issues_count":1}]
        """.utf8)

        MockURLProtocol.handler = { req in
            if req.value(forHTTPHeaderField: "If-None-Match") == "etag-1" {
                // Not modified: empty body. The service must reuse the cached payload.
                return (MockURLProtocol.response(req.url!, status: 304), nil)
            }
            return (MockURLProtocol.response(req.url!, status: 200, headers: ["Etag": "etag-1"]), body)
        }

        let service = makeService()
        let first = try await service.fetchRecentRepos()
        let second = try await service.fetchRecentRepos()

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second.first?.fullName, "raaaf/a")
    }

    // row: service-fetch-repos
    func testFetchRecentReposDecodes() async throws {
        let body = Data("""
        [
          {"id":1,"full_name":"raaaf/a","html_url":"https://github.com/raaaf/a","open_issues_count":3},
          {"id":2,"full_name":"raaaf/b","html_url":"https://github.com/raaaf/b"}
        ]
        """.utf8)
        MockURLProtocol.handler = { req in
            (MockURLProtocol.response(req.url!, status: 200), body)
        }

        let repos = try await makeService().fetchRecentRepos()
        XCTAssertEqual(repos.map(\.fullName), ["raaaf/a", "raaaf/b"])
        XCTAssertEqual(repos[0].openIssuesCount, 3)
        XCTAssertNil(repos[1].openIssuesCount)
    }

    // row: service-fetch-runs
    func testFetchRunsDecodes() async throws {
        let body = Data("""
        {"total_count":1,"workflow_runs":[
          {"id":10,"name":"CI","status":"completed","conclusion":"success",
           "html_url":"https://github.com/raaaf/a/actions/runs/10",
           "created_at":"2026-06-11T10:00:00Z","updated_at":"2026-06-11T10:05:00Z","run_number":1}
        ]}
        """.utf8)
        MockURLProtocol.handler = { req in
            (MockURLProtocol.response(req.url!, status: 200), body)
        }

        let runs = try await makeService().fetchRuns(repo: "raaaf/a")
        XCTAssertEqual(runs.map(\.id), [10])
    }

    // row: service-fetch-all
    func testFetchAllRunsAggregatesSkipsAndSorts() async throws {
        let reposBody = Data("""
        [
          {"id":1,"full_name":"raaaf/a","html_url":"https://github.com/raaaf/a","open_issues_count":2},
          {"id":2,"full_name":"raaaf/b","html_url":"https://github.com/raaaf/b","open_issues_count":0},
          {"id":3,"full_name":"raaaf/c","html_url":"https://github.com/raaaf/c","open_issues_count":5}
        ]
        """.utf8)
        let runsA = Data("""
        {"total_count":2,"workflow_runs":[
          {"id":100,"status":"completed","conclusion":"success","html_url":"https://github.com/raaaf/a/actions/runs/100",
           "created_at":"2026-06-11T09:00:00Z","updated_at":"2026-06-11T09:00:00Z","run_number":1},
          {"id":101,"status":"completed","conclusion":"failure","html_url":"https://github.com/raaaf/a/actions/runs/101",
           "created_at":"2026-06-11T12:00:00Z","updated_at":"2026-06-11T12:00:00Z","run_number":2}
        ]}
        """.utf8)

        MockURLProtocol.handler = { req in
            let path = req.url!.path
            switch path {
            case "/user/repos":
                return (MockURLProtocol.response(req.url!, status: 200), reposBody)
            case "/repos/raaaf/a/actions/runs":
                return (MockURLProtocol.response(req.url!, status: 200), runsA)
            case "/repos/raaaf/b/actions/runs":
                return (MockURLProtocol.response(req.url!, status: 404), nil)   // no Actions: skipped
            case "/repos/raaaf/c/actions/runs":
                return (MockURLProtocol.response(req.url!, status: 500), nil)   // real failure
            default:
                return (MockURLProtocol.response(req.url!, status: 404), nil)
            }
        }

        let result = try await makeService().fetchAllRuns(maxRepos: 30, runsPerRepo: 5)

        XCTAssertEqual(result.runs.map(\.id), [101, 100], "sorted by updatedAt desc")
        XCTAssertEqual(result.failedRepos, ["raaaf/c"], "404 skipped, 500 recorded")
        XCTAssertEqual(result.openIssuesByRepo["raaaf/a"], 2)
        XCTAssertEqual(result.openIssuesByRepo["raaaf/b"], 0)
        XCTAssertEqual(result.openIssuesByRepo["raaaf/c"], 5)
    }

    // row: service-rerun
    func testRerunWorkflowPostsToCorrectURL() async throws {
        var captured: URLRequest?
        MockURLProtocol.handler = { req in
            captured = req
            return (MockURLProtocol.response(req.url!, status: 201), Data())
        }

        try await makeService().rerunWorkflow(owner: "raaaf", repo: "my repo", runId: 7)

        XCTAssertEqual(captured?.httpMethod, "POST")
        XCTAssertEqual(
            captured?.url?.absoluteString,
            "https://api.github.com/repos/raaaf/my%20repo/actions/runs/7/rerun"
        )
    }

    // row: service-validate-token
    func testValidateTokenReturnsLogin() async throws {
        MockURLProtocol.handler = { req in
            (MockURLProtocol.response(req.url!, status: 200), Data(#"{"login":"raaaf"}"#.utf8))
        }
        let login = try await makeService().validateToken()
        XCTAssertEqual(login, "raaaf")
    }
}
