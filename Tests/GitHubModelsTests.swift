import XCTest
@testable import ActionBar

final class GitHubModelsTests: XCTestCase {
    // Mirrors the decoder configured in GitHubService.
    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private let sampleResponse = """
    {
      "total_count": 2,
      "workflow_runs": [
        {
          "id": 101,
          "name": "CI",
          "head_branch": "main",
          "status": "completed",
          "conclusion": "success",
          "html_url": "https://github.com/raaaf/actionbar/actions/runs/101",
          "created_at": "2026-06-11T10:00:00Z",
          "updated_at": "2026-06-11T10:05:00Z",
          "run_number": 42,
          "event": "push",
          "display_title": "Fix the thing",
          "repository": {
            "id": 5,
            "name": "actionbar",
            "full_name": "raaaf/actionbar",
            "html_url": "https://github.com/raaaf/actionbar"
          }
        },
        {
          "id": 102,
          "name": "Deploy",
          "head_branch": "main",
          "status": "in_progress",
          "conclusion": null,
          "html_url": "https://github.com/raaaf/actionbar/actions/runs/102",
          "created_at": "2026-06-11T11:00:00Z",
          "updated_at": "2026-06-11T11:01:00Z",
          "run_number": 43,
          "event": "workflow_dispatch",
          "display_title": null,
          "repository": null
        }
      ]
    }
    """

    func testDecodesWorkflowRunsResponse() throws {
        let data = Data(sampleResponse.utf8)
        let response = try makeDecoder().decode(WorkflowRunsResponse.self, from: data)

        XCTAssertEqual(response.totalCount, 2)
        XCTAssertEqual(response.workflowRuns.count, 2)

        let first = response.workflowRuns[0]
        XCTAssertEqual(first.id, 101)
        XCTAssertEqual(first.headBranch, "main")
        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(first.conclusion, .success)
        XCTAssertEqual(first.runNumber, 42)
    }

    func testRepoOwnerAndNameParsing() throws {
        let data = Data(sampleResponse.utf8)
        let runs = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns

        XCTAssertEqual(runs[0].repoFullName, "raaaf/actionbar")
        XCTAssertEqual(runs[0].repoOwner, "raaaf")
        XCTAssertEqual(runs[0].repoName, "actionbar")

        // Missing repository falls back to "unknown/repo" and yields empty owner/name splits.
        XCTAssertEqual(runs[1].repoFullName, "unknown/repo")
        XCTAssertEqual(runs[1].repoOwner, "unknown")
        XCTAssertEqual(runs[1].repoName, "repo")
    }

    func testResolvedNamePrefersDisplayTitle() throws {
        let data = Data(sampleResponse.utf8)
        let runs = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns

        XCTAssertEqual(runs[0].resolvedName, "Fix the thing")  // display_title
        XCTAssertEqual(runs[1].resolvedName, "Deploy")          // falls back to name
    }

    func testSFSymbolMapping() throws {
        let data = Data(sampleResponse.utf8)
        let runs = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns

        XCTAssertEqual(runs[0].sfSymbol, "checkmark.circle.fill")  // completed + success
        XCTAssertEqual(runs[1].sfSymbol, "circle.dotted.circle")   // in_progress
    }

    func testStatusLabelMapping() throws {
        let data = Data(sampleResponse.utf8)
        let runs = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns

        XCTAssertEqual(runs[0].statusLabel, "Success")
        XCTAssertEqual(runs[1].statusLabel, "In Progress")
    }

    func testEquatableComparesStatusAndConclusion() throws {
        let data = Data(sampleResponse.utf8)
        let base = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns[0]

        // Same id + same status/conclusion => equal.
        let same = try makeDecoder().decode(WorkflowRunsResponse.self, from: data).workflowRuns[0]
        XCTAssertEqual(base, same)

        // Same id but a different conclusion must NOT be equal (drives SwiftUI row diffing).
        let changedJSON = sampleResponse.replacingOccurrences(
            of: "\"conclusion\": \"success\"",
            with: "\"conclusion\": \"failure\""
        )
        let changed = try makeDecoder()
            .decode(WorkflowRunsResponse.self, from: Data(changedJSON.utf8))
            .workflowRuns[0]
        XCTAssertEqual(base.id, changed.id)
        XCTAssertNotEqual(base, changed)
    }
}
