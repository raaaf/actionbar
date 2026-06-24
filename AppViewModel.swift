import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Published state

    @Published var runs: [WorkflowRun] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var username: String?
    @Published var lastRefresh: Date?
    @Published var isAuthenticated = false
    @Published var runsByRepo: [(repoName: String, runs: [WorkflowRun])] = []
    @Published var loadingFrame: Int = 0
    @Published var failedRepos: [String] = []
    @Published var isRerunning: Set<Int> = []
    @Published var openIssuesByRepo: [String: Int] = [:]

    // MARK: - Settings

    @AppStorage("pollingInterval") var pollingInterval: Double = 30
    @AppStorage("maxRepos") var maxRepos: Int = 20
    @AppStorage("runsPerRepo") var runsPerRepo: Int = 3
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true

    // MARK: - Private

    private var service: GitHubService?
    private var pollTimer: Timer?
    private var loadingTimer: Timer?
    var completedRunIDs: Set<Int> = [] // Track runs we've already notified about

    // Injectable so tests can observe notification decisions without touching UNUserNotificationCenter.
    var onNotifyRunCompleted: (WorkflowRun) -> Void = { NotificationManager.shared.notifyRunCompleted($0) }

    // Three distinct circular frames — no duplicates, even visual rhythm
    private static let loadingFrames = [
        "circle.dashed",
        "circle.dotted.and.circle",
        "circle.dotted.circle",
    ]

    // MARK: - Computed

    var failureCount: Int {
        runs.count { $0.status == .completed && $0.conclusion == .failure }
    }

    var menuBarIcon: String {
        if !isAuthenticated { return "gearshape" }
        if isLoading {
            return Self.loadingFrames[loadingFrame % Self.loadingFrames.count]
        }

        guard let latest = runs.first else { return "checkmark.circle.fill" }
        return latest.sfSymbol
    }

    // MARK: - Init

    // `bootstrap: false` skips the notification prompt and Keychain read so tests stay isolated.
    init(bootstrap: Bool = true) {
        guard bootstrap else { return }
        NotificationManager.shared.requestPermission()
        loadToken()
    }

    // MARK: - Authentication

    func loadToken() {
        guard let token = KeychainHelper.load(), !token.isEmpty else {
            isAuthenticated = false
            return
        }
        setupService(token: token)
    }

    func authenticate(token: String) async {
        let service = GitHubService(token: token)
        do {
            let login = try await service.validateToken()
            try KeychainHelper.save(token: token)
            activateService(service, username: login)
            await refresh()
        } catch {
            self.error = error.localizedDescription
            self.isAuthenticated = false
        }
    }

    func signOut() {
        KeychainHelper.delete()
        service = nil
        username = nil
        isAuthenticated = false
        runs = []
        openIssuesByRepo = [:]
        updateRunsByRepo()
        completedRunIDs = []
        stopPolling()
    }

    // MARK: - Refresh

    func refresh() async {
        guard let service = service else { return }

        isLoading = true
        startLoadingAnimation()
        error = nil

        do {
            let result = try await service.fetchAllRuns(
                maxRepos: maxRepos,
                runsPerRepo: runsPerRepo
            )

            // Detect newly completed runs for notifications
            if notificationsEnabled {
                checkForCompletedRuns(newRuns: result.runs)
            }

            runs = result.runs
            failedRepos = result.failedRepos
            openIssuesByRepo = result.openIssuesByRepo
            updateRunsByRepo()
            lastRefresh = .now
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
        stopLoadingAnimation()
    }

    // MARK: - Re-run

    func rerunWorkflow(_ run: WorkflowRun) async {
        guard let service = service else { return }

        let owner = run.repoOwner
        let repo = run.repoName
        guard !owner.isEmpty, !repo.isEmpty else { return }

        isRerunning.insert(run.id)
        do {
            try await service.rerunWorkflow(owner: owner, repo: repo, runId: run.id)
            // Brief delay so GitHub can register the new run
            try? await Task.sleep(for: .seconds(2))
            await refresh()
        } catch {
            self.error = "Re-run failed: \(error.localizedDescription)"
        }
        isRerunning.remove(run.id)
    }

    // MARK: - Polling

    // Never poll faster than 15s, regardless of the configured value.
    static func effectivePollingInterval(_ configured: Double) -> Double {
        max(15.0, configured)
    }

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Self.effectivePollingInterval(pollingInterval),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Notifications

    func checkForCompletedRuns(newRuns: [WorkflowRun]) {
        // Look up the runs we currently hold so the membership checks below are O(1) instead of O(n) per run.
        let previousByID = Dictionary(runs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for run in newRuns where run.status == .completed {
            // Only notify if we haven't seen this run as completed before
            if !completedRunIDs.contains(run.id) {
                // On first load, don't spam notifications — just record existing completed runs
                if !runs.isEmpty {
                    // Notify unless our previous snapshot already showed this run as completed.
                    // A run we hadn't seen before (previous == nil) also satisfies this and should notify.
                    if previousByID[run.id]?.status != .completed {
                        onNotifyRunCompleted(run)
                    }
                }
                completedRunIDs.insert(run.id)
            }
        }

        // Prevent unbounded growth: once the set exceeds 500 IDs, keep the 300 most recent.
        // GitHub run IDs increase over time, so the highest IDs are the newest runs.
        if completedRunIDs.count > 500 {
            let sortedIDs = completedRunIDs.sorted()
            completedRunIDs = Set(sortedIDs.suffix(300))
        }
    }

    // MARK: - Private

    private func startLoadingAnimation() {
        loadingFrame = 0
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.6,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadingFrame = (self.loadingFrame + 1) % Self.loadingFrames.count
            }
        }
    }

    private func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingFrame = 0
    }

    private func setupService(token: String) {
        let service = GitHubService(token: token)
        self.service = service

        Task {
            do {
                let login = try await service.validateToken()
                activateService(service, username: login)
                await refresh()
            } catch {
                self.isAuthenticated = false
                self.error = error.localizedDescription
            }
        }
    }

    private func activateService(_ service: GitHubService, username: String) {
        self.service = service
        self.username = username
        self.isAuthenticated = true
        self.error = nil
        startPolling()
    }

    func updateRunsByRepo() {
        let grouped = Dictionary(grouping: runs) { $0.repoFullName }
        runsByRepo = grouped
            .map { (repoName: $0.key, runs: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted { a, b in
                let aDate = a.runs.first?.updatedAt ?? .distantPast
                let bDate = b.runs.first?.updatedAt ?? .distantPast
                return aDate > bDate
            }
    }
}
