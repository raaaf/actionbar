import XCTest
import SwiftUI
@testable import ActionBar

final class ModelDisplayTests: XCTestCase {
    // row: models-resolved-name
    func testResolvedNameFallbackChain() {
        XCTAssertEqual(
            Fixtures.run(id: 1, name: "CI", displayTitle: "Fix the thing").resolvedName,
            "Fix the thing"
        )
        XCTAssertEqual(
            Fixtures.run(id: 2, name: "Deploy", displayTitle: nil).resolvedName,
            "Deploy"
        )
        XCTAssertEqual(
            Fixtures.run(id: 3, name: nil, displayTitle: nil, runNumber: 7).resolvedName,
            "Workflow #7"
        )
    }

    // row: models-equatable
    func testHashUsesIdOnly() {
        let a = Fixtures.run(id: 99, status: "completed", conclusion: "success")
        let b = Fixtures.run(id: 99, status: "in_progress", conclusion: nil)
        // Different status/conclusion => not equal, but the hash is id-only so they collide in a set.
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // row: models-sf-symbol
    func testSFSymbolMappingAllStates() {
        let completed: [(String?, String)] = [
            ("success", "checkmark.circle.fill"),
            ("failure", "xmark.circle.fill"),
            ("cancelled", "slash.circle.fill"),
            ("skipped", "forward.circle.fill"),
            ("timed_out", "clock.badge.exclamationmark.fill"),
            ("action_required", "exclamationmark.circle.fill"),
            ("neutral", "questionmark.circle.fill"),     // default branch
        ]
        for (conclusion, symbol) in completed {
            XCTAssertEqual(
                Fixtures.run(id: 1, status: "completed", conclusion: conclusion).sfSymbol,
                symbol, "completed/\(conclusion ?? "nil")"
            )
        }

        XCTAssertEqual(Fixtures.run(id: 2, status: "in_progress", conclusion: nil).sfSymbol, "circle.dotted.circle")
        for queuedLike in ["queued", "waiting", "pending", "requested"] {
            XCTAssertEqual(
                Fixtures.run(id: 3, status: queuedLike, conclusion: nil).sfSymbol,
                "clock.circle", queuedLike
            )
        }
    }

    // row: models-status-color
    func testStatusColorMappingAllStates() {
        func desc(_ c: Color) -> String { String(describing: c) }

        XCTAssertEqual(desc(Fixtures.run(id: 1, status: "completed", conclusion: "success").statusColor), desc(.green))
        XCTAssertEqual(desc(Fixtures.run(id: 2, status: "completed", conclusion: "failure").statusColor), desc(.red))
        XCTAssertEqual(desc(Fixtures.run(id: 3, status: "completed", conclusion: "cancelled").statusColor), desc(.secondary))
        XCTAssertEqual(desc(Fixtures.run(id: 4, status: "completed", conclusion: "timed_out").statusColor), desc(.orange))
        XCTAssertEqual(desc(Fixtures.run(id: 5, status: "in_progress", conclusion: nil).statusColor), desc(.orange))
        XCTAssertEqual(desc(Fixtures.run(id: 6, status: "queued", conclusion: nil).statusColor), desc(.secondary))
    }

    // row: models-status-label
    func testStatusLabelMappingAllStates() {
        let completed: [(String?, String)] = [
            ("success", "Success"),
            ("failure", "Failure"),
            ("cancelled", "Cancelled"),
            ("skipped", "Skipped"),
            ("timed_out", "Timed Out"),
            ("action_required", "Action Required"),
            ("neutral", "Neutral"),
            ("stale", "Stale"),
        ]
        for (conclusion, label) in completed {
            XCTAssertEqual(
                Fixtures.run(id: 1, status: "completed", conclusion: conclusion).statusLabel,
                label, "completed/\(conclusion ?? "nil")"
            )
        }

        let active: [(String, String)] = [
            ("in_progress", "In Progress"),
            ("queued", "Queued"),
            ("waiting", "Waiting"),
            ("pending", "Pending"),
            ("requested", "Requested"),
        ]
        for (status, label) in active {
            XCTAssertEqual(Fixtures.run(id: 2, status: status, conclusion: nil).statusLabel, label, status)
        }
    }

    // row: models-time-ago
    func testTimeAgoIsNonEmpty() {
        let run = Fixtures.run(id: 1, updatedAt: "2026-06-11T10:00:00Z")
        XCTAssertFalse(run.timeAgo.isEmpty)
    }
}
