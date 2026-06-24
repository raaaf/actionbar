import XCTest
@testable import ActionBar

final class URLGitHubTests: XCTestCase {
    // row: url-github-gate
    func testIsGitHubURLGate() {
        let allowed = [
            "https://github.com",
            "https://github.com/raaaf/app",
            "https://github.com/raaaf/app/actions/runs/1",
            "https://api.github.com/user",
            "https://gist.github.com/raaaf",
        ]
        for s in allowed {
            XCTAssertTrue(URL(string: s)!.isGitHubURL, s)
        }

        let rejected = [
            "http://github.com/raaaf",            // not https
            "https://github.com.evil.com/x",      // not a github.com subdomain
            "https://notgithub.com/x",
            "https://example.com",
            "ftp://github.com",
        ]
        for s in rejected {
            XCTAssertFalse(URL(string: s)!.isGitHubURL, s)
        }
    }
}
