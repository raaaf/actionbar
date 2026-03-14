import Foundation

actor GitHubService {
    private let baseURL = "https://api.github.com"
    private let token: String

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(token: String) {
        self.token = token
    }

    // MARK: - Fetch recently pushed repos

    func fetchRecentRepos(limit: Int = 30) async throws -> [Repository] {
        let url = "\(baseURL)/user/repos?sort=pushed&direction=desc&per_page=\(limit)&type=all"
        let data = try await request(url: url)
        return try decoder.decode([Repository].self, from: data)
    }

    // MARK: - Fetch workflow runs for a single repo

    func fetchRuns(repo: String, perPage: Int = 5) async throws -> [WorkflowRun] {
        let url = "\(baseURL)/repos/\(repo)/actions/runs?per_page=\(perPage)"
        let data = try await request(url: url)
        let response = try decoder.decode(WorkflowRunsResponse.self, from: data)
        return response.workflowRuns
    }

    // MARK: - Fetch runs across all recent repos

    func fetchAllRuns(maxRepos: Int = 20, runsPerRepo: Int = 3) async throws -> [WorkflowRun] {
        let repos = try await fetchRecentRepos(limit: maxRepos)
        var allRuns: [WorkflowRun] = []

        // Fetch runs concurrently with TaskGroup
        try await withThrowingTaskGroup(of: [WorkflowRun].self) { group in
            for repo in repos {
                group.addTask {
                    do {
                        return try await self.fetchRuns(repo: repo.fullName, perPage: runsPerRepo)
                    } catch {
                        // Repo might not have Actions enabled — skip silently
                        return []
                    }
                }
            }

            for try await runs in group {
                allRuns.append(contentsOf: runs)
            }
        }

        // Sort by most recent first
        return allRuns.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Validate token

    func validateToken() async throws -> String {
        let url = "\(baseURL)/user"
        let data = try await request(url: url)

        struct User: Codable { let login: String }
        let user = try decoder.decode(User.self, from: data)
        return user.login
    }

    // MARK: - HTTP

    private func request(url urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.rateLimited
        case 404:
            throw GitHubError.notFound
        default:
            throw GitHubError.httpError(http.statusCode)
        }
    }
}

enum GitHubError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case notFound
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Invalid or expired token"
        case .rateLimited: return "GitHub API rate limit exceeded"
        case .notFound: return "Resource not found"
        case .httpError(let code): return "HTTP error: \(code)"
        }
    }
}
