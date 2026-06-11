import SwiftUI

@main
struct ActionBarApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label {
                Text(viewModel.failureCount > 0 ? "\(viewModel.failureCount)" : "")
            } icon: {
                Image(systemName: viewModel.menuBarIcon)
            }
            .accessibilityLabel(
                viewModel.failureCount > 0
                    ? "ActionBar, \(viewModel.failureCount) failed workflow runs"
                    : "ActionBar"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
