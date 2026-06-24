import XCTest
@testable import ActionBar

final class KeychainHelperTests: XCTestCase {
    // Isolated account so the test never touches the user's real stored PAT ("github-pat").
    private let account = "github-pat-test-roundtrip"

    override func tearDown() {
        KeychainHelper.delete(account: account)
        super.tearDown()
    }

    // row: keychain-roundtrip
    func testSaveLoadOverwriteDelete() throws {
        KeychainHelper.delete(account: account) // clean slate

        try KeychainHelper.save(token: "ghp_first", account: account)
        XCTAssertEqual(KeychainHelper.load(account: account), "ghp_first")

        // Saving again overwrites rather than duplicating.
        try KeychainHelper.save(token: "ghp_second", account: account)
        XCTAssertEqual(KeychainHelper.load(account: account), "ghp_second")

        KeychainHelper.delete(account: account)
        XCTAssertNil(KeychainHelper.load(account: account))
    }
}
