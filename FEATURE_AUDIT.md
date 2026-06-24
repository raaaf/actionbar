# Feature Audit — ActionBar

Canonical feature table for the testable logic surface of ActionBar (macOS menu-bar
GitHub Actions monitor). UI/system-integration features that XCTest cannot drive in this
harness are listed under **Needs human review**, not as table rows.

test-command: xcodegen generate >/dev/null 2>&1 && xcodebuild -project ActionBar.xcodeproj -scheme ActionBar -destination 'platform=macOS' -derivedDataPath build test 2>&1 | tail -80

- **Stack:** Swift 5 / SwiftUI macOS app (target macOS 26.0), XcodeGen + xcodebuild, XCTest.
- **Source layout:** flat at repo root (`*.swift`); tests in `Tests/` (target `ActionBarTests`).
- **Runner:** existing — `xcodebuild ... test` against `platform=macOS`. New test files under
  `Tests/` are auto-included via the XcodeGen `Tests` source glob (the test-command regenerates
  the project first).

Each row's `Test` column names the XCTest method(s) covering it; every such test carries a
`// row: <ID>` tag comment for traceability back to the table.

| ID | Feature | User story | Expected behaviour | Status | Test | Notes |
|----|---------|-----------|--------------------|--------|------|-------|
| models-run-decode | Decode workflow runs response | As the app, I parse the GitHub Actions runs JSON | `WorkflowRunsResponse`/`WorkflowRun` decode snake_case keys, ISO8601 dates, and optional fields without error | passing | GitHubModelsTests.testDecodesWorkflowRunsResponse | |
| models-repo-decode | Decode repository list | As the app, I parse `/user/repos` including the open-issue count | `Repository` decodes `open_issues_count` when present and as nil when absent (no crash) | passing | GitHubModelsTests.testDecodesRepositoryWithOpenIssuesCount | |
| models-resolved-name | Run display name fallback | As a user, I see a sensible run title | `resolvedName` = displayTitle, else name, else `Workflow #<runNumber>` | passing | ModelDisplayTests.testResolvedNameFallbackChain | |
| models-repo-parsing | Owner/name parsing | As the app, I split `owner/repo` for API calls | `repoFullName`/`repoOwner`/`repoName` parse correctly; missing repository falls back to `unknown/repo` | passing | GitHubModelsTests.testRepoOwnerAndNameParsing | |
| models-equatable | Run equality + hashing | As SwiftUI, I diff rows by identity and status | Equatable compares id+status+conclusion; Hashable uses id only | passing | GitHubModelsTests.testEquatableComparesStatusAndConclusion, ModelDisplayTests.testHashUsesIdOnly | |
| models-sf-symbol | Status SF Symbol mapping | As a user, I see an icon matching run state | `sfSymbol` maps every status/conclusion combination to the documented symbol | passing | ModelDisplayTests.testSFSymbolMappingAllStates | |
| models-status-color | Status color mapping | As a user, I see a color matching run state | `statusColor` maps success→green, failure→red, cancelled→secondary, other completed→orange, in_progress→orange, else secondary | passing | ModelDisplayTests.testStatusColorMappingAllStates | |
| models-status-label | Status label mapping | As a user, I read a human label for run state | `statusLabel` maps every status/conclusion to the documented text | passing | ModelDisplayTests.testStatusLabelMappingAllStates | |
| models-time-ago | Relative time string | As a user, I see how long ago a run updated | `timeAgo` returns a non-empty abbreviated relative string | passing | ModelDisplayTests.testTimeAgoIsNonEmpty | |
| error-descriptions | Error messages | As a user, I see a readable error | `GitHubError.errorDescription` returns the documented message for each case | passing | GitHubErrorTests.testErrorDescriptions | |
| service-error-mapping | HTTP status mapping | As the app, I translate HTTP failures to typed errors | 401→unauthorized, 403→rateLimited, 404→notFound, other non-2xx→httpError(code) | passing | GitHubServiceTests.testHTTPStatusMapsToErrors | |
| service-etag-cache | Conditional GET caching | As the app, I avoid burning rate limit on unchanged data | A 200 stores the ETag+payload; the next GET sends If-None-Match and a 304 reuses the cached payload | passing | GitHubServiceTests.testETagConditionalGETReusesCache | |
| service-fetch-repos | Fetch recent repos | As the app, I list recently pushed repos | `fetchRecentRepos` decodes the repository array | passing | GitHubServiceTests.testFetchRecentReposDecodes | |
| service-fetch-runs | Fetch runs for a repo | As the app, I list runs for one repo | `fetchRuns` decodes the workflow runs for a repo | passing | GitHubServiceTests.testFetchRunsDecodes | |
| service-fetch-all | Aggregate runs across repos | As a user, I see runs from all my repos | `fetchAllRuns` aggregates runs, silently skips 404 repos, records other failures in failedRepos, builds openIssuesByRepo, sorts runs by updatedAt desc | passing | GitHubServiceTests.testFetchAllRunsAggregatesSkipsAndSorts | |
| service-rerun | Re-run a workflow | As a user, I re-run a completed workflow | `rerunWorkflow` POSTs to `/repos/{owner}/{repo}/actions/runs/{id}/rerun` with URL-encoded owner/repo | passing | GitHubServiceTests.testRerunWorkflowPostsToCorrectURL | |
| service-validate-token | Validate token | As a user, I confirm my token works | `validateToken` returns the authenticated login | passing | GitHubServiceTests.testValidateTokenReturnsLogin | |
| vm-failure-count | Failure count | As a user, I see a badge count of failed runs | `failureCount` counts runs that are completed with conclusion failure | passing | AppViewModelTests.testFailureCountCountsCompletedFailures | |
| vm-menubar-icon | Menu bar icon state | As a user, the menu bar icon reflects app state | `menuBarIcon` = gearshape when unauthenticated, a loading frame when loading, latest run symbol when runs exist, checkmark when authenticated+empty | passing | AppViewModelTests.testMenuBarIconReflectsState | |
| vm-runs-grouping | Group runs by repo | As a user, runs are grouped per repo, newest first | `updateRunsByRepo` groups by repoFullName, sorts runs within a group by updatedAt desc, and orders groups by their newest run | passing | AppViewModelTests.testRunsByRepoGroupsAndSorts | |
| vm-notify-transition | Notify on completion transition | As a user, I am notified only when a run newly completes | `checkForCompletedRuns` notifies for runs transitioning to completed, never on first load (empty prior runs), and never twice for the same run | passing | AppViewModelTests.testNotifyOnlyOnTransitionNotFirstLoad | |
| vm-notify-bounded | Bounded notified-set | As the app, my notified-run set does not grow unbounded | When `completedRunIDs` exceeds 500 it is trimmed to the 300 most recent (highest) IDs | passing | AppViewModelTests.testCompletedRunIDsTrimWhenLarge | |
| vm-polling-clamp | Polling interval floor | As the app, I never poll faster than 15s | The effective polling interval is `max(15, configured)` | passing | AppViewModelTests.testEffectivePollingIntervalClamped | |
| vm-sign-out | Sign out | As a user, signing out clears my session | `signOut` clears runs, username, openIssues, auth flag and stops polling | passing | AppViewModelTests.testSignOutClearsState | |
| url-github-gate | GitHub URL gate | As a user, the app only opens trusted GitHub links | `isGitHubURL` is true only for https on github.com or a `.github.com` subdomain; false otherwise | passing | URLGitHubTests.testIsGitHubURLGate | |
| notif-content | Notification content | As a user, the completion notification reads clearly | Notification content has repo as title, `<run> <conclusion text>` as body, default sound, time-sensitive level only on failure, and the run URL in userInfo | passing | NotificationContentTests.testCompletionContent | |
| notif-open-url | Notification click target | As a user, clicking a notification opens the run | The stored URL is parsed from userInfo; missing or non-string url yields nil (host trust is the url-github-gate) | passing | NotificationContentTests.testNotificationURLResolution | Delegate wiring + actual open is manual |
| notif-foreground | Foreground presentation | As a user, I still see notifications while the app is active | Foreground presentation options are banner+sound | passing | NotificationContentTests.testForegroundPresentationOptions | |
| keychain-roundtrip | PAT persistence | As a user, my token is stored securely between launches | KeychainHelper save/load round-trips, a second save overwrites, delete removes the item | passing | KeychainHelperTests.testSaveLoadOverwriteDelete | Tested against an isolated account, never the real PAT item |
| app-menubar-badge | Menu bar badge | As a user, the menu bar shows how many runs failed | Badge text is the failure count or empty; accessibility label names the count | passing | AppViewModelTests.testMenuBarBadgeAndAccessibilityLabel | |
| vm-menu-content | Popup content state | As a user, the popup shows the right section | `menuContent` precedence: unauthenticated, then loading-while-empty, then empty, then runs | passing | AppViewModelTests.testMenuContentPrecedence | |
| ui-issue-badge-label | Issue badge copy | As a user, the issue badge reads naturally | `RepoHeaderView.issueBadgeLabel` pluralizes issue/issues | passing | ViewCopyTests.testIssueBadgeLabelPluralizes | |
| ui-failed-repos-label | Failed-repos banner copy | As a user, the fetch-failure banner reads naturally | `MenuBarView.failedReposLabel` pluralizes repo/repos | passing | ViewCopyTests.testFailedReposLabelPluralizes | |

## Needs human review

These are the residual features whose behaviour is pure SwiftUI/AppKit rendering or an external
side effect that XCTest cannot decide in this harness. Their underlying logic was extracted and
is now covered by table rows (noted below); only the visual/side-effect shell remains manual.
They do not block audit completion.

- SwiftUI rendering of MenuBarView / RepoHeaderView / RunRowView: hover highlights, dim-at-rest
  action opacity, arrow affordances, banner layout. The content-state selection (vm-menu-content)
  and the banner/badge copy (ui-failed-repos-label, ui-issue-badge-label) are now tested; the
  rendering is not.
- RunRowView accessibility actions wiring (re-run only when completed and not re-running; open in
  GitHub). The simple gate is visible in code; the SwiftUI `accessibilityActions` wiring is manual.
- SettingsView: token entry with show/hide toggle, Authenticate button, sign-out confirmation
  dialog, polling/notification controls. SwiftUI form + flows.
- SettingsWindowController: opens a single reusable AppKit settings window. AppKit side effect.
- ActionBarApp: the MenuBarExtra scene itself. Its badge text / icon / accessibility label are
  tested (app-menubar-badge, vm-menubar-icon); the Scene wiring is manual.
- AppViewModel.loadToken / authenticate / refresh / rerunWorkflow: end-to-end auth, polling, and
  re-run orchestration (real network + a real Keychain write to the shared `github-pat` item, plus
  rerunWorkflow's 2s settle delay). Deliberately not auto-tested to avoid clobbering the user's real
  stored PAT; the constituent pieces are covered (service-*, vm-notify-*, keychain-roundtrip).
- AppViewModel loading-frame animation timer (0.6s tick cycling through frames). Time-based UI.
- URL.openIfGitHub / NotificationManager delegate side effect: NSWorkspace.open actually launching
  the browser. The URL gate (url-github-gate) and the click-target parsing (notif-open-url) are
  tested; the launch is not.
