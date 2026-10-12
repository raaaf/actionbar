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
- **Test-only dependency:** ViewInspector (SPM, declared in `project.yml`, test target only) drives
  the SwiftUI view rows (`ui-*`). The runtime app still ships zero external dependencies.

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
| service-fetch-all | Aggregate runs across repos | As a user, I see runs from all my repos | `fetchAllRuns` aggregates runs, silently skips 404 repos, records other failures in failedRepos, builds openIssuesByRepo (PRs excluded via the issues API), sorts runs by updatedAt desc | passing | GitHubServiceTests.testFetchAllRunsAggregatesSkipsAndSorts | |
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
| ui-menu-states | Popup section rendering | As a user, the popup renders the right section | MenuBarView renders the token prompt / loading / empty / repo-section view for each `menuContent` state | passing | MenuBarViewInspectionTests.testMenuRendersSectionForEachState | ViewInspector |
| ui-menu-error-banner | Popup banners | As a user, I see error and fetch-failure banners | MenuBarView renders the error text and the failed-repos banner when set | passing | MenuBarViewInspectionTests.testMenuRendersErrorAndFailedReposBanners | ViewInspector |
| ui-repo-header | Repo header rendering | As a user, each repo shows its name and issue badge | RepoHeaderView renders the repo name and shows the issue badge only when count > 0 | passing | MenuBarViewInspectionTests.testRepoHeaderShowsNameAndConditionalIssueBadge | ViewInspector |
| ui-run-row | Run row rendering | As a user, a run shows title, branch, event, status | RunRowView renders resolvedName, branch, event, and status label | passing | MenuBarViewInspectionTests.testRunRowShowsRunDetails | ViewInspector |
| ui-run-row-actions | Run row actions | As a user, re-run is offered only for completed runs | RunRowView exposes the re-run action (toolbar + accessibility) only when completed; open is always present | passing | MenuBarViewInspectionTests.testRunRowShowsRerunOnlyWhenCompleted | ViewInspector |
| ui-settings-authenticated | Settings authed state | As a signed-in user, I can sign out | SettingsView shows Sign Out (and no Authenticate) when authenticated | passing | SettingsViewInspectionTests.testAuthenticatedShowsSignOut | ViewInspector |
| ui-settings-unauthenticated | Settings token form | As a signed-out user, I can enter a token and set options | SettingsView shows the token form, Authenticate button, and polling/notification controls | passing | SettingsViewInspectionTests.testUnauthenticatedShowsTokenFormAndControls | ViewInspector |
| ui-settings-window | Settings window reuse | As a user, opening Settings twice reuses one window | SettingsWindowController.show creates one settings window and reuses it on a second call | passing | SettingsWindowControllerTests.testShowCreatesWindowAndReusesIt | App-hosted (real NSWindow) |
| vm-refresh-pipeline | Refresh pipeline | As a user, refreshing loads runs and notifies | `refresh` populates runs/openIssues/grouping/lastRefresh, clears error, and fires notifications on completion transitions | passing | AppViewModelRefreshTests.testRefreshPopulatesStateAndNotifies | |
| vm-refresh-error | Refresh failure | As a user, a failed refresh surfaces an error | `refresh` sets the error message and clears loading when the fetch throws | passing | AppViewModelRefreshTests.testRefreshSetsErrorOnFailure | |
| vm-loading-frames | Loading animation frames | As a user, the loading icon cycles through frames | The frame index cycles 0→1→2→0 and `menuBarIcon` maps each frame to its symbol | passing | AppViewModelTests.testLoadingFrameCyclesAndMapsToSymbols | |

## Needs human review

Only three residual items remain that no automated check can decide in this harness. Each has its
logic and rendering covered by table rows (noted); only the listed shell is manual. They are
captured as a reproducible checklist in `MANUAL_QA.md` and do not block audit completion.

- ActionBarApp MenuBarExtra **scene wiring**: that the menu-bar item is built from the tested
  badge/icon/label values. The values are tested (app-menubar-badge, vm-menubar-icon,
  vm-loading-frames); ViewInspector cannot inspect an `App`/`Scene`, so the wiring is manual.
- SettingsView **interactive @State**: the show/hide token toggle and the sign-out confirmation
  dialog. Both rendered states are tested (ui-settings-authenticated, ui-settings-unauthenticated);
  the in-view `@State` toggle/dialog transitions are verified manually.
- **NSWorkspace.open browser launch** (URL.openIfGitHub / notification click): actually opening the
  browser. The trust gate (url-github-gate) and click-target parsing (notif-open-url) are tested;
  the launch side effect is verified manually.

Also intentionally not auto-tested: AppViewModel.authenticate / loadToken / rerunWorkflow end-to-end,
because they write the real shared `github-pat` Keychain item (authenticate/loadToken) or depend on
a 2s settle delay (rerunWorkflow). Their constituents are covered (validateToken via service-*,
refresh via vm-refresh-*, keychain-roundtrip, service-rerun); only the destructive/timing glue is in
the manual checklist.
