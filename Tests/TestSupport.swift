import Foundation
@testable import ActionBar

/// Shared fixtures for building decoded model values from JSON, mirroring the production decoder.
enum Fixtures {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Builds a `WorkflowRun` by serializing a JSON object and decoding it, so tests exercise the
    /// real Codable path. Pass `name: nil` and `displayTitle: nil` to hit the `Workflow #n` fallback,
    /// or `repo: nil` to omit the repository.
    static func run(
        id: Int,
        status: String? = "completed",
        conclusion: String? = "success",
        repo: String? = "raaaf/app",
        updatedAt: String = "2026-06-11T10:00:00Z",
        createdAt: String = "2026-06-11T09:00:00Z",
        name: String? = "CI",
        displayTitle: String? = nil,
        headBranch: String? = "main",
        event: String? = "push",
        runNumber: Int = 1,
        htmlUrl: String = "https://github.com/raaaf/app/actions/runs/1"
    ) -> WorkflowRun {
        var dict: [String: Any] = [
            "id": id,
            "html_url": htmlUrl,
            "created_at": createdAt,
            "updated_at": updatedAt,
            "run_number": runNumber,
        ]
        if let status { dict["status"] = status }
        if let conclusion { dict["conclusion"] = conclusion }
        if let name { dict["name"] = name }
        if let displayTitle { dict["display_title"] = displayTitle }
        if let headBranch { dict["head_branch"] = headBranch }
        if let event { dict["event"] = event }
        if let repo {
            let parts = repo.split(separator: "/")
            dict["repository"] = [
                "id": 1,
                "name": parts.count > 1 ? String(parts[1]) : repo,
                "full_name": repo,
                "html_url": "https://github.com/\(repo)",
            ]
        }

        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! decoder().decode(WorkflowRun.self, from: data)
    }
}
