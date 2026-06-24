# Manual QA Checklist — ActionBar

Reproducible smoke checks for the few behaviours no automated test can decide (see the
"Needs human review" section of `FEATURE_AUDIT.md`). Run these after a release build:

```bash
xcodegen generate
xcodebuild -project ActionBar.xcodeproj -scheme ActionBar -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/ActionBar.app /Applications/
open /Applications/ActionBar.app
```

## 1. MenuBarExtra scene wiring (rows: app-menubar-badge, vm-menubar-icon, vm-loading-frames)
- [ ] Menu bar shows the gear icon when no token is configured.
- [ ] After authenticating, the icon reflects the latest run (e.g. green check / red x).
- [ ] With at least one failed run, a numeric failure-count badge appears next to the icon.
- [ ] During a refresh, the icon briefly cycles through the loading frames.

## 2. SettingsView interactive state (rows: ui-settings-authenticated, ui-settings-unauthenticated)
- [ ] Open Settings → General. With no token, the eye button toggles the token field between
      masked (SecureField) and visible (TextField).
- [ ] Enter a valid PAT, click Authenticate → the section switches to "Authenticated as <login>".
- [ ] Click Sign Out → a confirmation dialog appears; confirming clears the session and returns to
      the token form; cancelling leaves you signed in.

## 3. Browser launch / link trust (rows: url-github-gate, notif-open-url)
- [ ] Click a repo header → the repo opens on github.com in the default browser.
- [ ] Click the issue badge → the repo's issues page opens.
- [ ] Click a run row's open button → the run opens on github.com.
- [ ] When a run completes, a notification appears; clicking it opens the run URL.

## 4. End-to-end auth/refresh/re-run (constituents covered by service-*, vm-refresh-*, keychain-roundtrip)
- [ ] After authenticating, runs from your recent repos populate within one poll interval.
- [ ] Re-run a completed workflow → a spinner shows on the row, and the list refreshes to the new run.
- [ ] Quit and relaunch → you remain signed in (token loaded from Keychain).
