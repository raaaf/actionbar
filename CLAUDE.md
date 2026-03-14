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
open ActionBar.xcodeproj
```

Then build with Cmd+R. The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `ActionBar.xcodeproj` from `project.yml`. There is no SPM, CocoaPods, or other dependency manager — zero external runtime dependencies.

## Architecture

The app follows a simple MVVM pattern — all in a flat file structure at the repo root:

- **ActionBarApp.swift** — `@main` entry point. Creates `MenuBarExtra` scene.
- **AppViewModel.swift** — `@MainActor ObservableObject`. Owns all app state: auth, polling timer, runs list, notification tracking. Uses `@AppStorage` for user preferences (polling interval, max repos, runs per repo, notifications toggle).
- **GitHubService.swift** — Swift `actor` wrapping GitHub REST API. Fetches repos (`/user/repos`), workflow runs (`/repos/{owner}/{repo}/actions/runs`), validates tokens (`/user`). Uses `TaskGroup` for concurrent per-repo fetching.
- **GitHubModels.swift** — Codable structs (`WorkflowRun`, `Repository`, `RunRepository`) and enums (`RunStatus`, `RunConclusion`). Includes display helpers (SF Symbols, colors, time formatting) as extensions on `WorkflowRun`.
- **KeychainHelper.swift** — Thin wrapper around Security framework for PAT storage (`kSecClassGenericPassword`).
- **NotificationManager.swift** — Singleton managing `UNUserNotificationCenter`. Sends notifications on run completion, opens GitHub URL on click.
- **MenuBarView.swift** — Main popup view: shows auth prompt, loading state, empty state, or grouped run list.
- **RunRowView.swift** — Single workflow run row with status icon, branch, event, and time ago.
- **SettingsView.swift** — Tabbed settings window (General + About). Token input, polling config, notification toggle.
- **SettingsWindowController.swift** — AppKit-based window controller for opening Settings from `MenuBarExtra` context.

## Key Patterns

- `GitHubService` is a Swift actor — all API calls are async and thread-safe
- Notifications only fire for runs that **transition** to completed (not on first load) — tracked via `completedRunIDs` set in `AppViewModel`
- PAT is stored in macOS Keychain, never in UserDefaults or on disk
- App Sandbox is enabled with outgoing network + keychain entitlements (`ActionBar.entitlements`)
- GitHub API version header: `X-GitHub-Api-Version: 2022-11-28`
