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

    // MARK: - Settings

    @AppStorage("pollingInterval") var pollingInterval: Double = 30
    @AppStorage("maxRepos") var maxRepos: Int = 20
    @AppStorage("runsPerRepo") var runsPerRepo: Int = 3
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true

    // MARK: - Private

    private var service: GitHubService?
    private var pollTimer: Timer?
    private var loadingTimer: Timer?
    private var completedRunIDs: Set<Int> = [] // Track runs we've already notified about

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

    init() {
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

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: max(15.0, pollingInterval),
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

    private func checkForCompletedRuns(newRuns: [WorkflowRun]) {
        for run in newRuns where run.status == .completed {
            // Only notify if we haven't seen this run as completed before
            if !completedRunIDs.contains(run.id) {
                // On first load, don't spam notifications — just record existing completed runs
                if !runs.isEmpty {
                    // Check if this run was previously in-progress or not yet seen
                    let wasInProgress = runs.first(where: { $0.id == run.id })?.status != .completed
                    let isNew = !runs.contains(where: { $0.id == run.id })

                    if wasInProgress || isNew {
                        NotificationManager.shared.notifyRunCompleted(run)
                    }
                }
                completedRunIDs.insert(run.id)
            }
        }

        // Prune old IDs to prevent memory growth — keep the most recent 300
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

    private func updateRunsByRepo() {
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
