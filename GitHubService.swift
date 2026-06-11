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

    // Per-URL ETag + payload cache for conditional GETs. A 304 response reuses the cached
    // payload and does not count against the GitHub rate limit.
    private var responseCache: [String: (etag: String, data: Data)] = [:]

    init(token: String) {
        self.token = token
    }

    // MARK: - Fetch recently pushed repos

    func fetchRecentRepos(limit: Int = 30) async throws -> [Repository] {
        let url = "\(baseURL)/user/repos?sort=pushed&direction=desc&per_page=\(limit)&type=all"
        let data = try await perform(url: url)
        return try decoder.decode([Repository].self, from: data)
    }

    // MARK: - Fetch workflow runs for a single repo

    func fetchRuns(repo: String, perPage: Int = 5) async throws -> [WorkflowRun] {
        let url = "\(baseURL)/repos/\(repo)/actions/runs?per_page=\(perPage)"
        let data = try await perform(url: url)
        let response = try decoder.decode(WorkflowRunsResponse.self, from: data)
        return response.workflowRuns
    }

    // MARK: - Fetch runs across all recent repos

    struct FetchResult {
        let runs: [WorkflowRun]
        let failedRepos: [String]
    }

    func fetchAllRuns(maxRepos: Int = 20, runsPerRepo: Int = 3) async throws -> FetchResult {
        let repos = try await fetchRecentRepos(limit: maxRepos)
        var allRuns: [WorkflowRun] = []
        var failedRepos: [String] = []

        await withTaskGroup(of: (String, Result<[WorkflowRun], Error>).self) { group in
            for repo in repos {
                group.addTask {
                    do {
                        let runs = try await self.fetchRuns(repo: repo.fullName, perPage: runsPerRepo)
                        return (repo.fullName, .success(runs))
                    } catch {
                        return (repo.fullName, .failure(error))
                    }
                }
            }

            for await (repoName, result) in group {
                switch result {
                case .success(let runs):
                    allRuns.append(contentsOf: runs)
                case .failure(let error):
                    // 404 means no Actions enabled — not a real error
                    if let ghError = error as? GitHubError, ghError == .notFound {
                        continue
                    }
                    failedRepos.append(repoName)
                }
            }
        }

        return FetchResult(
            runs: allRuns.sorted { $0.updatedAt > $1.updatedAt },
            failedRepos: failedRepos
        )
    }

    // MARK: - Re-run workflow

    func rerunWorkflow(owner: String, repo: String, runId: Int) async throws {
        let encodedOwner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
        let encodedRepo = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
        let url = "\(baseURL)/repos/\(encodedOwner)/\(encodedRepo)/actions/runs/\(runId)/rerun"
        _ = try await perform(url: url, method: "POST")
    }

    // MARK: - Validate token

    func validateToken() async throws -> String {
        let url = "\(baseURL)/user"
        let data = try await perform(url: url)

        struct User: Codable { let login: String }
        let user = try decoder.decode(User.self, from: data)
        return user.login
    }

    // MARK: - HTTP

    private func perform(url urlString: String, method: String = "GET") async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        // Only GETs are idempotent and worth caching; send the stored ETag as a conditional request.
        let isCacheable = method == "GET"
        if isCacheable, let cached = responseCache[urlString] {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch http.statusCode {
        case 304:
            // Not Modified — reuse the cached payload. (Falls back to a fresh fetch next poll if absent.)
            guard let cached = responseCache[urlString] else {
                throw GitHubError.invalidResponse
            }
            return cached.data
        case 200...299:
            if isCacheable, let etag = http.value(forHTTPHeaderField: "Etag") {
                responseCache[urlString] = (etag, data)
            }
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

enum GitHubError: LocalizedError, Equatable {
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
