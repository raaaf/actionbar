import AppKit
import Foundation

extension URL {
    /// Opens the URL in the default browser, but only if it is an https github.com URL.
    /// Every GitHub link in the app comes from the API; this guards against opening anything unexpected.
    func openIfGitHub() {
        guard scheme == "https",
              let host, host == "github.com" || host.hasSuffix(".github.com")
        else { return }
        NSWorkspace.shared.open(self)
    }
}
