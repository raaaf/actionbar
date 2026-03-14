import SwiftUI

struct RunRowView: View {
    let run: WorkflowRun

    @State private var isHovering = false

    var body: some View {
        Button {
            openInBrowser()
        } label: {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: run.sfSymbol)
                    .font(.body)
                    .foregroundStyle(run.statusColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                // Run info
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.resolvedName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        if let branch = run.headBranch {
                            Label(branch, systemImage: "arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if let event = run.event {
                            Text("·")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                            Text(event)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Time + status
                VStack(alignment: .trailing, spacing: 1) {
                    Text(run.statusLabel)
                        .font(.caption2)
                        .foregroundStyle(run.statusColor)

                    Text(run.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.06) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel("Open \(run.resolvedName) on GitHub, \(run.statusLabel), \(run.timeAgo)")
    }

    private func openInBrowser() {
        if let url = URL(string: run.htmlUrl),
           url.scheme == "https",
           url.host?.hasSuffix("github.com") == true {
            NSWorkspace.shared.open(url)
        }
    }
}
