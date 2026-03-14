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
        .frame(width: 360)
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
        .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Runs List

    private var runsListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.runsByRepo, id: \.repoName) { group in
                    repoSection(group.repoName, runs: group.runs)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxHeight: 400)
    }

    private func repoSection(_ repoName: String, runs: [WorkflowRun]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Repo header
            HStack {
                Image(systemName: "folder.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(repoName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 2)

            ForEach(runs) { run in
                RunRowView(run: run)
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
