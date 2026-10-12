# ActionBar

GitHub Actions workflow runs in your macOS menu bar. Personal build, inspired by [ptrchm.com/actionbar](https://ptrchm.com/actionbar/).

## Features

- Monitor workflow runs across all your GitHub repos
- Open-issue badge per repo (click opens the issues page, PRs excluded)
- macOS notifications when runs complete (success, failure, cancelled)
- Click any run to open it directly on GitHub
- Configurable polling interval (15s – 5 min)
- PAT stored securely in macOS Keychain
- No dock icon — lives entirely in the menu bar

## Requirements

- macOS 26.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- GitHub Personal Access Token — classic PAT with `repo` + `workflow` scopes (recommended, covers personal + org repos and re-running workflows), or a fine-grained PAT with `Actions: Read and write` + `Metadata: Read`

## Build & Run

```bash
xcodegen generate
open ActionBar.xcodeproj
```

Then build with Cmd+R in Xcode.

## Creating a GitHub PAT

1. Go to [github.com/settings/tokens?type=beta](https://github.com/settings/tokens?type=beta)
2. Click **Generate new token**
3. Name: `ActionBar`
4. Repository access: **All repositories** (or select specific ones)
5. Permissions → **Repository permissions**:
   - **Actions**: Read and write (write is needed to re-run workflows)
   - **Metadata**: Read-only (auto-granted)
6. Generate and copy the token
7. Paste it into ActionBar's Settings

## Architecture

All source files live flat in the repo root (no nested folders):

```
ActionBarApp.swift           # App entry, MenuBarExtra
AppViewModel.swift           # State, polling, notification tracking
GitHubModels.swift           # API types, display helpers
GitHubService.swift          # REST API client (async/await, actor)
KeychainHelper.swift         # Secure token storage
NotificationManager.swift    # UserNotifications
MenuBarView.swift            # Main popup content
RunRowView.swift             # Single run row
SettingsView.swift           # Token + preferences
SettingsWindowController.swift # AppKit settings window
Info.plist                   # LSUIElement = true
ActionBar.entitlements       # Sandbox + keychain + network
project.yml                  # XcodeGen configuration
```

## Notes

- Uses `MenuBarExtra` with `.window` style for the popup
- GitHub API is polled via `GitHubService` (Swift actor for thread safety)
- Notifications only fire for runs that transition to completed — no spam on first load
- Rate limiting: with 20 repos at 30s intervals, you'll use ~2500 requests/hour — 1 repo-list call plus up to 20 run calls per poll, 120 polls/hour (GitHub allows 5000/hour for authenticated users)

## License

MIT — see [LICENSE](LICENSE).

## Author

Rafael Alex — Designer & Developer from Fürth, Germany.
Websites, apps and AI tools, built by one person.
[rafaelalex.de](https://rafaelalex.de) · [@raaaf](https://github.com/raaaf)
