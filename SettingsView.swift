import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var tokenInput = ""
    @State private var isAuthenticating = false
    @State private var showToken = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 320)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            // Authentication section
            Section {
                if viewModel.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Authenticated as **\(viewModel.username ?? "unknown")**")
                        Spacer()
                        Button("Sign Out") {
                            viewModel.signOut()
                            tokenInput = ""
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GitHub Personal Access Token")
                            .font(.headline)

                        Text("Create a fine-grained PAT with **Actions (read)** permission.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            if showToken {
                                TextField("ghp_...", text: $tokenInput)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("ghp_...", text: $tokenInput)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                showToken.toggle()
                            } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                            }
                            .accessibilityLabel(showToken ? "Hide token" : "Show token")
                        }

                        HStack {
                            Button("Authenticate") {
                                isAuthenticating = true
                                Task {
                                    await viewModel.authenticate(token: tokenInput)
                                    isAuthenticating = false
                                }
                            }
                            .disabled(tokenInput.isEmpty || isAuthenticating)

                            if isAuthenticating {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Spacer()

                            Link(
                                "Create Token",
                                destination: URL(string: "https://github.com/settings/tokens?type=beta")!
                            )
                            .font(.caption)
                        }

                        if let error = viewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Authentication")
            }

            // Polling section
            Section {
                HStack {
                    Text("Polling interval")
                    Spacer()
                    Picker("Polling interval", selection: $viewModel.pollingInterval) {
                        Text("15s").tag(15.0)
                        Text("30s").tag(30.0)
                        Text("60s").tag(60.0)
                        Text("2 min").tag(120.0)
                        Text("5 min").tag(300.0)
                    }
                    .frame(width: 100)
                    .labelsHidden()
                    .onChange(of: viewModel.pollingInterval) { _, _ in
                        viewModel.startPolling()
                    }
                }

                Stepper(
                    "Max repos to check: \(viewModel.maxRepos)",
                    value: $viewModel.maxRepos,
                    in: 5...50,
                    step: 5
                )

                Stepper(
                    "Runs per repo: \(viewModel.runsPerRepo)",
                    value: $viewModel.runsPerRepo,
                    in: 1...10
                )
            } header: {
                Text("Polling")
            }

            // Notifications section
            Section {
                Toggle("Notify on workflow completion", isOn: $viewModel.notificationsEnabled)
            } header: {
                Text("Notifications")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("ActionBar")
                .font(.title2)
                .fontWeight(.bold)

            Text("GitHub Actions in your menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Text("Built for personal use")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
