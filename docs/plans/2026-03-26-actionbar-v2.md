# ActionBar v2 — Fokussierter Umbau

## Problem

ActionBar funktioniert, hat aber spuerbare Schwaechen im Alltag: Fehler werden still verschluckt (leere Runs-Liste ohne Erklaerung), die UI ist visuell flach (alles `caption`-Size), die Fensterhoehe ist starr, und es gibt keine Moeglichkeit fehlgeschlagene Workflows direkt neu zu starten.

## Ziel

- Auf einen Blick sehen ob etwas kaputt ist (Failure-Badge im Menubar)
- Fehler sichtbar statt stille leere Liste
- Visuell angenehmer und lesbarer
- Failed Workflows direkt re-triggern ohne Browser
- Repo-Header klickbar

## Nicht-Ziele

- ViewModel-Aufteilung (232 Zeilen sind ueberschaubar)
- Statusfilter (bei <20 Runs nicht noetig)
- Exponential Backoff / Rate-Limit-Header (bei ~120 Req/h von 5.000 irrelevant)
- Tests mit Mock-URLSession (persoenliche App, Aufwand-Nutzen stimmt nicht)
- Global Hotkey

---

## Loesung

### Schritt 1: Failure-Badge im Menubar

Hoechster Tageswert — man sieht sofort ohne die App zu oeffnen ob etwas kaputt ist.

**`AppViewModel.swift`** — Aenderungen:
- Neues Computed Property `failureCount: Int` — zaehlt Runs mit `status == .completed && conclusion == .failure`

**`ActionBarApp.swift`** — Aenderungen:
```swift
Label {
    Text(viewModel.failureCount > 0 ? "\(viewModel.failureCount)" : "")
} icon: {
    Image(systemName: viewModel.menuBarIcon)
        .symbolRenderingMode(.palette)
}
```

Das Icon faerbt sich bereits rot bei Failures (bestehende Logik). Die Zahl daneben macht es explizit.

### Schritt 2: Fehler sichtbar machen

Statt stille leere Liste — dem User zeigen was schiefgeht.

**`GitHubService.swift`** — Aenderungen:
- `fetchAllRuns()` gibt Tupel zurueck: `(runs: [WorkflowRun], failedRepos: [String])`
- Einzelne Repo-Fehler werden gesammelt statt verschluckt
- Neue Methode `rerunWorkflow(owner:repo:runId:)` (POST, fuer Schritt 4)

**`AppViewModel.swift`** — Aenderungen:
- Neues `@Published var failedRepos: [String] = []`
- `refresh()` zeigt Fehler-State wenn Token ungueltig oder Netzwerk weg
- Error wird im `error` Property gesetzt statt verschluckt

**`MenuBarView.swift`** — Aenderungen:
- Error-Banner oben in der Runs-Liste wenn `failedRepos` nicht leer oder `error` gesetzt
- Zeigt z.B. "3 repos could not be fetched" als dezente Warnung

### Schritt 3: Visuelle Hierarchie verbessern

Taeglich mehrfach im Blick — soll angenehm lesbar sein.

**`RunRowView.swift`** — Ueberarbeitung:
- Workflow-Name: `font(.callout)` statt `caption` (12pt — Kompromiss zwischen Lesbarkeit und Dichte)
- Branch/Event: `font(.caption)` statt `caption2`
- Status-Label: `font(.caption)` statt `caption2`, `fontWeight(.semibold)` bei Failure
- Padding: 8pt vertikal statt 6pt
- Tooltip fuer abgeschnittene Namen: `.help(run.resolvedName)`

**`MenuBarView.swift`** — Ueberarbeitung:
- Repo-Header: `font(.subheadline)` mit `fontWeight(.semibold)` statt `caption`
- Repo-Header wird klickbar (oeffnet Repo auf GitHub) mit Hover-Effekt
- Breite: 380 statt 360 (mehr Platz fuer Workflow-Namen)

### Schritt 4: Re-Trigger Feature

Fehlgeschlagene Workflows direkt aus der App neu starten.

**`GitHubService.swift`** — Neue Methode:
```swift
func rerunWorkflow(owner: String, repo: String, runId: Int) async throws {
    // POST /repos/{owner}/{repo}/actions/runs/{runId}/rerun
}
```

**`RunRowView.swift`** — Aenderungen:
- Hover-Buttons statt Kontextmenu (Kontextmenu funktioniert in MenuBarExtra unzuverlaessig)
- Bei Hover erscheinen inline Icons rechts in der Row:
  - Refresh-Icon (Re-run) — nur bei `status == .completed`
  - Link-Icon (Open in GitHub) — immer
- Bestehender Click-to-Open bleibt als Fallback

**`AppViewModel.swift`** — Neue Methode:
```swift
func rerunWorkflow(_ run: WorkflowRun) async {
    // Ruft GitHubService auf, dann refresh()
}
```

### Schritt 5: Fensterhoehe

**`MenuBarView.swift`** — Aenderungen:
- Feste Hoehe beibehalten (`frame(width: 380, height: 500)`), da dynamische Hoehe in `MenuBarExtra(.window)` unzuverlaessig ist
- ScrollView bekommt `maxHeight: .infinity` damit sie den verfuegbaren Platz fuellt
- Empty/Loading/Error States zentriert im verfuegbaren Raum

---

## Betroffene Dateien

| Datei | Aenderung |
|-------|-----------|
| `ActionBarApp.swift` | Failure-Badge im Menubar-Label |
| `AppViewModel.swift` | failureCount, failedRepos, rerunWorkflow, Error-Handling |
| `GitHubService.swift` | Partielle Fehler zurueckgeben, rerun-Endpoint |
| `MenuBarView.swift` | Error-Banner, groessere Repo-Header, klickbar, 380px, Hoehe |
| `RunRowView.swift` | Groessere Fonts, Hover-Buttons (Re-run, Open), Tooltip |

## Edge Cases

- **Token expired**: Fehler im Error-Banner anzeigen, nicht stille leere Liste
- **Re-run bei laufendem Run**: Button nicht anzeigen wenn Status != `completed`
- **Repo ohne Actions**: Weiterhin ueberspringen, nicht als Fehler zaehlen
- **Re-run braucht `actions:write` Scope**: Bei 403 Fehler anzeigen "Token needs Actions (write) permission"
- **Hover-Buttons vs. Click-to-Open**: Hover-Buttons erscheinen nur bei Hover, Click auf die Row oeffnet weiterhin GitHub

## Akzeptierte Concerns

- Dynamische Fensterhoehe waere schoener, ist aber in MenuBarExtra(.window) unzuverlaessig — feste Hoehe beibehalten
- ViewModel-Aufteilung waere sauberer, lohnt sich bei 232 Zeilen nicht
- Tests waeren gut, Aufwand-Nutzen stimmt bei persoenlicher App nicht

## Verifizierung

1. Build: `xcodegen generate && xcodebuild -scheme ActionBar -configuration Release -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`
2. App starten, pruefen:
   - Menubar zeigt Failure-Count neben Icon
   - Runs werden mit groesserer Schrift angezeigt
   - Hover ueber Run zeigt Re-run und Open-in-GitHub Buttons
   - Repo-Header klickbar, oeffnet GitHub
   - Error-Banner bei fehlerhaften Repos
3. Kuenstlich Token invalidieren → Fehlermeldung statt leere Liste
4. Re-run auf failed Workflow testen → Workflow startet neu
5. Copy App nach /Applications, Neustart, alles funktioniert
