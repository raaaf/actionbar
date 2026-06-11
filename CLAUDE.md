# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ActionBar is a macOS menu bar app (SwiftUI) that monitors GitHub Actions workflow runs. It polls the GitHub REST API, displays run statuses in a MenuBarExtra popup, and sends native macOS notifications when runs complete. Personal build, no App Store distribution.

- **Bundle ID:** `de.rafaelalex.ActionBar`
- **Minimum target:** macOS 26.0
- **Xcode:** 16+
- **UI framework:** SwiftUI with `MenuBarExtra(.window)` style
- **No dock icon:** `LSUIElement = true` in Info.plist

## Build & Run

```bash
xcodegen generate
xcodebuild -project ActionBar.xcodeproj -scheme ActionBar -configuration Release -derivedDataPath build -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
cp -R build/Build/Products/Release/ActionBar.app /Applications/
```

Or open `ActionBar.xcodeproj` in Xcode and build with Cmd+R. The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `ActionBar.xcodeproj` from `project.yml`. There is no SPM, CocoaPods, or other dependency manager — zero external runtime dependencies.

- **Apple Developer Team:** `9LA5969PJ2`
- **Code Signing:** Automatic, Hardened Runtime enabled
- **PAT type:** Classic PAT with `repo` + `workflow` scopes (covers personal + org repos)

## Architecture

The app follows a simple MVVM pattern — all in a flat file structure at the repo root:

- **ActionBarApp.swift** — `@main` entry point. Creates `MenuBarExtra` scene with failure-count badge.
- **AppViewModel.swift** — `@MainActor ObservableObject`. Owns all app state: auth, polling timer, runs list, notification tracking, re-run state. Uses `@AppStorage` for user preferences (polling interval, max repos, runs per repo, notifications toggle).
- **GitHubService.swift** — Swift `actor` wrapping GitHub REST API. Fetches repos (`/user/repos`), workflow runs (`/repos/{owner}/{repo}/actions/runs`), re-runs workflows (`POST .../rerun`), validates tokens (`/user`). Returns partial results with error tracking via `FetchResult`.
- **GitHubModels.swift** — Codable structs (`WorkflowRun`, `Repository`, `RunRepository`) and enums (`RunStatus`, `RunConclusion`). Includes display helpers (SF Symbols, colors, time formatting) as extensions on `WorkflowRun`.
- **KeychainHelper.swift** — Thin wrapper around Security framework for PAT storage (`kSecClassGenericPassword`).
- **NotificationManager.swift** — Singleton managing `UNUserNotificationCenter`. Sends notifications on run completion, opens GitHub URL on click.
- **MenuBarView.swift** — Main popup view: shows auth prompt, loading state, empty state, error banners, or grouped run list. Includes `RepoHeaderView` (clickable, opens repo on GitHub).
- **RunRowView.swift** — Single workflow run row with status icon, branch, event, time ago. Action buttons (re-run, open in GitHub) are always visible, dimmed at rest and full opacity on hover.
- **SettingsView.swift** — Tabbed settings window (General + About). Token input, polling config, notification toggle.
- **SettingsWindowController.swift** — AppKit-based window controller for opening Settings from `MenuBarExtra` context.
- **URL+GitHub.swift** — `URL.openIfGitHub()`: opens a URL in the browser only if it is `https` on `github.com` or a subdomain. The single gate for all GitHub link opening.
- **Tests/GitHubModelsTests.swift** — Unit tests (target `ActionBarTests`): Codable decoding, repo parsing, status/symbol mapping, Equatable. Run with `xcodebuild -scheme ActionBar test`.

## Key Patterns

- `GitHubService` is a Swift actor — all API calls are async and thread-safe
- `fetchAllRuns()` returns `FetchResult` with partial results — failed repos are tracked separately, 404s (no Actions) are silently skipped
- Notifications only fire for runs that **transition** to completed (not on first load) — tracked via `completedRunIDs` set in `AppViewModel`
- PAT is stored in macOS Keychain, never in UserDefaults or on disk
- App Sandbox is enabled with outgoing network + keychain entitlements (`ActionBar.entitlements`)
- GitHub API version header: `X-GitHub-Api-Version: 2022-11-28`
- Conditional GETs: `GitHubService` caches ETag + payload per URL and sends `If-None-Match`; 304 responses reuse the cache and don't count against the rate limit
- `RunRowView` holds the view model as plain `let` (not `@ObservedObject`) — rows get per-run state via value props so unrelated `@Published` changes don't re-render them
- Menu bar icon shows failure count badge when there are failed runs
- Runs are sorted by `updatedAt` descending, both globally and within each repo group
