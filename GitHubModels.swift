import Foundation
import SwiftUI

// MARK: - Workflow Runs Response

struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

// MARK: - Workflow Run

struct WorkflowRun: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let headBranch: String?
    let status: RunStatus?
    let conclusion: RunConclusion?
    let htmlUrl: String
    let createdAt: Date
    let updatedAt: Date
    let runNumber: Int
    let event: String?
    let displayTitle: String?
    let repository: RunRepository?

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event
        case headBranch = "head_branch"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runNumber = "run_number"
        case displayTitle = "display_title"
        case repository
    }

    var resolvedName: String {
        displayTitle ?? name ?? "Workflow #\(runNumber)"
    }

    var repoFullName: String {
        repository?.fullName ?? "unknown/repo"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WorkflowRun, rhs: WorkflowRun) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.conclusion == rhs.conclusion
    }
}

// MARK: - Run Repository (embedded in run response)

struct RunRepository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case htmlUrl = "html_url"
    }
}

// MARK: - Repository (from /user/repos)

struct Repository: Codable, Identifiable {
    let id: Int
    let fullName: String
    let htmlUrl: String
    let pushedAt: Date?
    let hasActions: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case pushedAt = "pushed_at"
        case hasActions = "has_actions"
    }
}

// MARK: - Enums

enum RunStatus: String, Codable {
    case queued
    case inProgress = "in_progress"
    case completed
    case waiting
    case requested
    case pending
}

enum RunConclusion: String, Codable {
    case success
    case failure
    case cancelled
    case skipped
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case neutral
    case stale
}

// MARK: - Display Helpers

extension WorkflowRun {
    var sfSymbol: String {
        if status == .completed {
            switch conclusion {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            case .cancelled: return "slash.circle.fill"
            case .skipped: return "forward.circle.fill"
            case .timedOut: return "clock.badge.exclamationmark.fill"
            case .actionRequired: return "exclamationmark.circle.fill"
            default: return "questionmark.circle.fill"
            }
        }
        switch status {
        case .inProgress: return "circle.dotted.circle"
        case .queued, .waiting, .pending, .requested: return "clock.circle"
        default: return "questionmark.circle"
        }
    }

    var statusColor: Color {
        if status == .completed {
            switch conclusion {
            case .success: return .green
            case .failure: return .red
            case .cancelled: return .secondary
            default: return .orange
            }
        }
        switch status {
        case .inProgress: return .orange
        default: return .secondary
        }
    }

    var statusLabel: String {
        if status == .completed {
            switch conclusion {
            case .success: return "Success"
            case .failure: return "Failure"
            case .cancelled: return "Cancelled"
            case .skipped: return "Skipped"
            case .timedOut: return "Timed Out"
            case .actionRequired: return "Action Required"
            case .neutral: return "Neutral"
            case .stale: return "Stale"
            default: return "Completed"
            }
        }
        switch status {
        case .inProgress: return "In Progress"
        case .queued: return "Queued"
        case .waiting: return "Waiting"
        case .pending: return "Pending"
        case .requested: return "Requested"
        default: return "Unknown"
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var timeAgo: String {
        Self.relativeFormatter.localizedString(for: updatedAt, relativeTo: .now)
    }
}
