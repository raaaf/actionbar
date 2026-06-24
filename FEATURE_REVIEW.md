# Feature Review — ActionBar

Holistic read of the stories in `FEATURE_AUDIT.md` as one product. No code or tests were
changed for this review. Each finding references the affected row ID(s).

## Inconsistencies

- **Two vocabularies for the same conclusions.** The completion notification
  (`notif-content`) says "succeeded / failed / was cancelled / timed out / completed",
  while the in-app label (`models-status-label`) says "Success / Failure / Cancelled /
  Timed Out / ...". The same run state reads differently depending on where the user looks.
- **Notification collapses states the UI distinguishes.** `notif-content` folds
  `skipped`, `action_required`, `neutral`, and `stale` into the single word "completed",
  whereas `models-status-label` gives each a distinct label and `models-sf-symbol` /
  `models-status-color` treat several of them specially. A skipped run notifies as merely
  "completed".
- **Icon vs label disagree for uncommon conclusions.** For `neutral`/`stale`,
  `models-sf-symbol` falls through to `questionmark.circle.fill` ("unknown") while
  `models-status-label` shows the precise label "Neutral"/"Stale" and `models-status-color`
  colors it orange. The icon implies the app does not understand a state the label clearly does.

## Gaps

- **PAT persistence is untested.** KeychainHelper save/load/delete (and `loadToken` /
  `authenticate` reliance on it) sits entirely in *Needs human review*; a silent Keychain
  failure has no safety net. Related rows: `vm-sign-out` (which calls delete) is tested, but
  the save/load round-trip is not.
- **End-to-end auth/poll/re-run flows untested.** The decision logic is covered
  (`vm-notify-transition`, `service-rerun`, `service-fetch-all`), but `refresh`,
  `authenticate`, and `rerunWorkflow`'s 2s-delay-then-refresh orchestration are integration
  paths with no automated check.
- **Re-run has no user-visible success confirmation.** `service-rerun` succeeds silently;
  on failure `vm` sets an error string, but a successful re-run gives no feedback beyond the
  list eventually changing.
- **`timeAgo` only checked for non-emptiness** (`models-time-ago`); its actual formatting and
  locale behaviour are unverified.
- **Open-issue badge counts PRs.** The badge (UI, *Needs human review*) is fed from
  `open_issues_count`, which GitHub inflates with open PRs, yet the label reads "N issue(s)".
  The number can mislead.

## Potentials

- **Single source for run wording.** Derive the notification body from `statusLabel`
  (`models-status-label`) so `notif-content` cannot drift from the in-app vocabulary. One-line
  win: delete the duplicate switch.
- **Distinct symbols for neutral/stale/skipped** (`models-sf-symbol`) so the icon matches the
  already-specific label and color.
- **Protocol-inject NotificationManager** so the click-to-open and foreground-presentation
  behaviors (currently *Needs human review*) become unit-testable, mirroring the URLSession
  seam used by `service-*`.
- **Add ViewInspector or snapshot tests** to cover MenuBarView's state selection and
  RepoHeaderView's singular/plural label, moving those out of *Needs human review*.
- **Relabel or recompute the issue badge** (e.g. "N open" or a real issues-only count) to stop
  conflating PRs with issues.

(No heading is empty.)
