import XCTest
@testable import ActionBar

final class GitHubErrorTests: XCTestCase {
    // row: error-descriptions
    func testErrorDescriptions() {
        XCTAssertEqual(GitHubError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(GitHubError.invalidResponse.errorDescription, "Invalid response")
        XCTAssertEqual(GitHubError.unauthorized.errorDescription, "Invalid or expired token")
        XCTAssertEqual(GitHubError.rateLimited.errorDescription, "GitHub API rate limit exceeded")
        XCTAssertEqual(GitHubError.notFound.errorDescription, "Resource not found")
        XCTAssertEqual(GitHubError.httpError(500).errorDescription, "HTTP error: 500")
    }
}
