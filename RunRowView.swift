import SwiftUI

struct RunRowView: View {
    let run: WorkflowRun
    @ObservedObject var viewModel: AppViewModel

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: run.sfSymbol)
                .font(.body)
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
        .accessibilityLabel("\(run.resolvedName), \(run.statusLabel), \(run.timeAgo)")
    }

    // MARK: - Hover Buttons

    private var hoverButtons: some View {
        HStack(spacing: 4) {
            if run.status == .completed {
                Button {
                    Task { await viewModel.rerunWorkflow(run) }
                } label: {
                    if viewModel.isRerunning.contains(run.id) {
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
                .disabled(viewModel.isRerunning.contains(run.id))
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
        if let url = URL(string: run.htmlUrl),
           url.scheme == "https",
           url.host?.hasSuffix("github.com") == true {
            NSWorkspace.shared.open(url)
        }
    }
}
