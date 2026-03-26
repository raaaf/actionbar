import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.isAuthenticated {
                notAuthenticatedView
            } else if viewModel.runs.isEmpty && viewModel.isLoading {
                loadingView
            } else if viewModel.runs.isEmpty {
                emptyView
            } else {
                runsListView
            }

            Divider()
                .padding(.vertical, 4)

            footerView
        }
        .frame(width: 380, height: 500)
        .padding(.vertical, 8)
    }

    // MARK: - Not Authenticated

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No GitHub token configured")
                .font(.headline)
            Text("Open Settings to add your Personal Access Token.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                SettingsWindowController.show(viewModel: viewModel)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Fetching workflow runs...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No recent workflow runs")
                .font(.headline)
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        Group {
            if let error = viewModel.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                }
                .font(.caption)
                .padding(8)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            if !viewModel.failedRepos.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.failedRepos.count) repo\(viewModel.failedRepos.count == 1 ? "" : "s") could not be fetched")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .help(viewModel.failedRepos.joined(separator: ", "))
            }
        }
    }

    // MARK: - Runs List

    private var runsListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                errorBanner

                ForEach(viewModel.runsByRepo, id: \.repoName) { group in
                    repoSection(group.repoName, runs: group.runs)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func repoSection(_ repoName: String, runs: [WorkflowRun]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            RepoHeaderView(repoName: repoName)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(runs) { run in
                RunRowView(run: run, viewModel: viewModel)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let username = viewModel.username {
                Image(systemName: "person.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let lastRefresh = viewModel.lastRefresh {
                Text(lastRefresh, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Refresh workflow runs")

            Button {
                SettingsWindowController.show(viewModel: viewModel)
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Repo Header

struct RepoHeaderView: View {
    let repoName: String
    @State private var isHovering = false

    var body: some View {
        Button {
            openRepoInBrowser()
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(repoName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isHovering ? .primary : .secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if isHovering {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.06) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel("Open \(repoName) on GitHub")
    }

    private func openRepoInBrowser() {
        if let url = URL(string: "https://github.com/\(repoName)") {
            NSWorkspace.shared.open(url)
        }
    }
}
