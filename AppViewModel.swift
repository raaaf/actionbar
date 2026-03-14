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

    // MARK: - Settings

    @AppStorage("pollingInterval") var pollingInterval: Double = 30
    @AppStorage("maxRepos") var maxRepos: Int = 20
    @AppStorage("runsPerRepo") var runsPerRepo: Int = 3
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true

    // MARK: - Private

    private var service: GitHubService?
    private var pollTimer: Timer?
    private var completedRunIDs: Set<Int> = [] // Track runs we've already notified about

    // MARK: - Computed

    var menuBarIcon: String {
        if !isAuthenticated { return "gearshape" }
        if isLoading { return "arrow.triangle.2.circlepath" }

        var hasFailure = false
        var hasInProgress = false
        for run in runs {
            if run.status == .completed && run.conclusion == .failure { hasFailure = true; break }
            if run.status == .inProgress { hasInProgress = true }
        }

        if hasFailure { return "xmark.circle.fill" }
        if hasInProgress { return "circle.dotted.circle" }
        return "checkmark.circle.fill"
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
        error = nil

        do {
            let newRuns = try await service.fetchAllRuns(
                maxRepos: maxRepos,
                runsPerRepo: runsPerRepo
            )

            // Detect newly completed runs for notifications
            if notificationsEnabled {
                checkForCompletedRuns(newRuns: newRuns)
            }

            runs = newRuns
            updateRunsByRepo()
            lastRefresh = .now
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
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

        // Prune old IDs to prevent memory growth
        if completedRunIDs.count > 500 {
            let activeIDs = Set(newRuns.map(\.id))
            completedRunIDs = completedRunIDs.intersection(activeIDs)
        }
    }

    // MARK: - Private

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
            .map { (repoName: $0.key, runs: $0.value) }
            .sorted { a, b in
                let aDate = a.runs.first?.updatedAt ?? .distantPast
                let bDate = b.runs.first?.updatedAt ?? .distantPast
                return aDate > bDate
            }
    }
}
