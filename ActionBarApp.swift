import SwiftUI

@main
struct ActionBarApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label {
                Text(viewModel.menuBarBadgeText)
            } icon: {
                Image(systemName: viewModel.menuBarIcon)
            }
            .accessibilityLabel(viewModel.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.window)
    }
}
