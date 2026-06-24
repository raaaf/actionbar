import AppKit
import Foundation

extension URL {
    /// True only for https URLs on github.com or a github.com subdomain. The single trust gate
    /// for opening links; separated from the side effect so it can be unit-tested.
    var isGitHubURL: Bool {
        guard scheme == "https", let host else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    /// Opens the URL in the default browser, but only if it is an https github.com URL.
    /// Every GitHub link in the app comes from the API; this guards against opening anything unexpected.
    func openIfGitHub() {
        guard isGitHubURL else { return }
        NSWorkspace.shared.open(self)
    }
}
