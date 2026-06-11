# Full Audit — 2026-06-11

## Scope
- Dimensionen: 10/11 — architecture, security, performance, code_quality, a11y, typography, ui_design, ux, animation, docs_sync (SEO ausgelassen: keine Web-App)
- Swift-Dateien: 10 (+ neue URL+GitHub.swift) + Config (project.yml, Info.plist, ActionBar.entitlements) + Docs (README.md, CLAUDE.md)
- Modus: SINGLE (13 Dateien)
- Effort: xhigh
- Runden: 2 (R1 Fixes, R2 adversariale Verifikation) + Cross-Reference
- Build: Release BUILD SUCCEEDED nach jeder Runde

## Ergebnis
- Critical gefunden/gefixt: 1/1
- Important gefunden/gefixt: 12/12
- Minor gefunden/gefixt: 13/13
- Verworfen (kein realer Defekt): 4
- Akzeptiert (Open Points): 6

## Gefixte Issues

### Critical
- [A11y] RunRowView — Hover-only Re-run/Open per VoiceOver/Keyboard unerreichbar. `.accessibilityActions` (Re-run gated auf completed + !isRerunning, Open) hinzugefuegt; Hover-Design visuell unveraendert.

### Important
- [Performance] AppViewModel checkForCompletedRuns — O(n·m) Doppel-Scans pro Run. ID-Lookup-Dictionary einmal gebaut → O(n+m).
- [Performance] RunRowView — observierte das ganze AppViewModel, 0.6s-Loading-Tick renderte alle Rows. Auf plain `let viewModel` + `isRerunning: Bool`-Prop umgestellt (SwiftUI struct-equality skip).
- [Code Quality] SettingsView:89 — `URL(string:)!` force-unwrap → `if let`.
- [Code Quality] NotificationManager:49 — redundanter else-Zweig (beide `sound=.default`) zusammengefasst.
- [Code Quality] NotificationManager:19 — `print()` in Produktion entfernt.
- [A11y] ActionBarApp — MenuBarExtra-Label ohne accessibilityLabel → "ActionBar, N failed workflow runs".
- [A11y] MenuBarView — Error- + Failed-Repos-Banner-Warnicons accessibilityHidden.
- [UI Design] MenuBarView:95 — gelbes Warnicon auf rotem Banner-BG (Severity-Konflikt) → rot.
- [UX] RunRowView — Re-run-Spinner nur bei Hover sichtbar; jetzt auch ohne Hover (in-flight) sichtbar.
- [Docs] README + SettingsView — PAT-Scope-Beschreibung 3x widerspruechlich; auf "classic repo+workflow, oder fine-grained Actions read&write + Metadata" vereinheitlicht (Write fuer Re-run noetig).
- [Architecture/Security] URL-Open-Validierung in 3 Call-Sites dupliziert, RepoHeaderView ganz ungeprueft → `URL.openIfGitHub()` Helper (neue Datei), ueberall genutzt.
- [Animation] RunRowView + RepoHeaderView — abrupter Hover-Wechsel → dezente `.animation(.easeInOut(duration: 0.15), value: isHovering)`.

### Minor
- [A11y] MenuBarView person.circle (Footer) accessibilityHidden.
- [A11y] SettingsView About-Icon gearshape.2.fill accessibilityHidden.
- [Code Quality] AppViewModel — Prune-Kommentar ("most recent 300") an >500-Trigger angepasst + ID-Monotonie dokumentiert.
- [Typography] RunRowView:13 — Status-Icon `.font(.body)` → `.callout` (Ausrichtung mit Text).
- [Architecture] SettingsView/SettingsWindowController — Fenstergroesse 420x320 doppelt hardcoded → `SettingsView.windowSize` Konstante.
- [UX] MenuBarView — notAuthenticatedView zeigt jetzt viewModel.error (Token expired/revoked statt "kein Token").
- [Docs] README:67 — Rate-Limit-Mathe korrigiert (~2400 → ~2500, 1 + maxRepos calls/poll).
- [A11y] (R2) RunRowView — accessibility Re-run-Action ohne isRerunning-Guard (Doppel-Trigger via VoiceOver) → `&& !isRerunning`.
- [Security] (R2) URL.openIfGitHub — `hasSuffix("github.com")` erlaubte Lookalikes (evilgithub.com) → `host == "github.com" || hasSuffix(".github.com")`.
- [Code Quality] (R2) AppViewModel — redundantes `|| isNew` (Teilmenge von wasInProgress) entfernt.
- [Code Quality] (R2) ActionBarApp — `.contentTransition(.symbolEffect(.replace))` auf MenuBarExtra-Label (no-op im Status-Item) entfernt.
- [Docs/UX] (Cross-Ref) SettingsView — "Create Token"-Link auf classic `tokens/new` (passt zur Primaer-Empfehlung).

## Verworfen (kein realer Defekt)
- Prune-by-ID (A4/P4): GitHub Run-IDs sind global monoton steigend → `suffix(300)` behaelt tatsaechlich die neuesten; Sort nur bei >500, vernachlaessigbar.
- `try?` auf Task.sleep (Q6): bewusst, Abbruch des 2s-Delays ist egal.
- Notification-userInfo / Re-run-Error-localizedDescription (S1/S3): Open-Handler validiert bereits, kein Secret-Leak (Token nur im Header).

## Offene Punkte (akzeptiert, nicht gefixt)
1. **Kein Test-Target.** GitHubService, checkForCompletedRuns (Notification-Transition), completedRunIDs-Pruning ungetestet. Empfehlung: Test-Target in project.yml + Unit-Tests.
2. **Kein HTTP-Caching (ETag/conditional GET).** `requestCachePolicy=.reloadIgnoringLocalCacheData` + kein If-None-Match. 304-Responses wuerden Rate-Limit-Nutzung deutlich senken. Feature, kein Bugfix.
3. **Hover-Action-Discoverability (UX).** Re-run/Open erst bei Hover sichtbar. Bewusstes v2-Design; a11y ueber accessibilityActions geloest.
4. **Sign-Out ohne Bestaetigung.** Fuer Personal-App akzeptabel (Re-Auth = Token erneut einfuegen).
5. **Kein In-List-Loading-Indikator bei Refresh mit vorhandenen Daten.** Menu-Bar-Icon animiert + Refresh-Button disabled; akzeptabler Trade-off.
6. **KeychainHelper nutzt Default-Access-Group.** Funktioniert im Sandbox; relevant falls je Helper-App/Extension dazukommt.

## Manueller Testplan
Siehe Chat-Ausgabe (15 Schritte).
