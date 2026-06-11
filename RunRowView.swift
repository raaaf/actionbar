import SwiftUI

struct RunRowView: View {
    let run: WorkflowRun
    // Plain reference, not @ObservedObject: the row only calls methods on the view model and must not
    // re-render on unrelated @Published changes (e.g. the 0.6s loading-icon tick). In-flight state for
    // this specific run is passed in via `isRerunning`.
    let viewModel: AppViewModel
    let isRerunning: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: run.sfSymbol)
                .font(.callout)
                .foregroundStyle(run.statusColor)
                .frame(width: 20)
                .accessibilityHidden(true)

            // Run info
            VStack(alignment: .leading, spacing: 2) {
                Text(run.resolvedName)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(run.resolvedName)

                HStack(spacing: 4) {
                    if let branch = run.headBranch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let event = run.event {
                        Text("·")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(event)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if isHovering {
                // Hover action buttons
                hoverButtons
            } else if isRerunning {
                // Re-run still in flight while not hovering — keep showing progress
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                // Time + status
                VStack(alignment: .trailing, spacing: 2) {
                    Text(run.statusLabel)
                        .font(.caption)
                        .fontWeight(run.conclusion == .failure ? .semibold : .regular)
                        .foregroundStyle(run.statusColor)

                    Text(run.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.06) : .clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .accessibilityLabel("\(run.resolvedName), \(run.statusLabel), \(run.timeAgo)")
        .accessibilityActions {
            if run.status == .completed && !isRerunning {
                Button("Re-run workflow") {
                    Task { await viewModel.rerunWorkflow(run) }
                }
            }
            Button("Open in GitHub") { openInBrowser() }
        }
    }

    // MARK: - Hover Buttons

    private var hoverButtons: some View {
        HStack(spacing: 4) {
            if run.status == .completed {
                Button {
                    Task { await viewModel.rerunWorkflow(run) }
                } label: {
                    if isRerunning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Re-run workflow")
                .disabled(isRerunning)
            }

            Button {
                openInBrowser()
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open in GitHub")
        }
    }

    private func openInBrowser() {
        URL(string: run.htmlUrl)?.openIfGitHub()
    }
}
