# Full Audit -- 2026-03-14

## Scope
- Swift-Dateien: 8
- Config-Dateien: 3 (Info.plist, ActionBar.entitlements, project.yml)
- Runden: 2/3

## Ergebnis
- Critical gefunden/gefixt: 8/8
- Important gefunden/gefixt: 16/16
- Minor: 5/5

## Gefixte Issues

### Critical
- [Architecture] ActionBar.entitlements -- war leer, App Sandbox nicht aktiv. Wiederhergestellt mit sandbox, network.client, keychain-access-groups
- [Performance] GitHubModels.swift:166 -- RelativeDateTimeFormatter bei jedem Zugriff neu erzeugt. Statischer Formatter eingefuehrt
- [Performance] AppViewModel.swift:43 -- runsByRepo bei jedem Render neu berechnet. Zu @Published mit updateRunsByRepo() geaendert
- [A11y] RunRowView.swift:9 -- Button ohne accessibilityLabel. Label mit Run-Name, Status und Zeit hinzugefuegt
- [A11y] RunRowView.swift:14 -- Status nur durch Farbe vermittelt. Icon accessibilityHidden, Status in Button-Label
- [A11y] SettingsView.swift:60 -- Token-Toggle ohne Label. accessibilityLabel hinzugefuegt
- [A11y] MenuBarView.swift:138 -- Refresh-Button ohne Label. accessibilityLabel hinzugefuegt
- [A11y] MenuBarView.swift:147 -- SettingsLink ohne Label. accessibilityLabel hinzugefuegt

### Important
- [Security] NotificationManager.swift:75 -- URL aus API ohne Validierung geoeffnet. Scheme+Host-Check hinzugefuegt
- [Security] RunRowView.swift:74 -- URL ohne Host-Validierung. github.com-Check hinzugefuegt
- [Security] KeychainHelper.swift:25 -- kSecAttrAccessibleWhenUnlocked. Zu ThisDeviceOnly geaendert
- [Security] AppViewModel.swift:18 -- Polling-Intervall ohne Runtime-Minimum. max(15.0, ...) eingefuehrt
- [Performance] GitHubService.swift:89 -- URLSession.shared ohne Timeouts. Dedizierte Session mit 10s/30s Timeout
- [Performance] GitHubModels.swift:54 -- Equatable verglich nur id. Status+Conclusion hinzugefuegt
- [Quality] AppViewModel.swift:3 -- import Combine unused. Entfernt
- [Quality] GitHubModels.swift:136 -- statusColor gab String zurueck. Gibt jetzt Color zurueck
- [Quality] AppViewModel.swift:146 -- restartPolling() trivial. Entfernt
- [Quality] SettingsView.swift:115 -- Deprecated onChange. Neue Form verwendet
- [Quality] SettingsView.swift:163 -- Hardcoded Version. Liest jetzt aus Bundle
- [Quality] GitHubModels.swift:153 -- statusLabel zeigte "Timed_out". Explizite Cases
- [Quality] NotificationManager.swift:31 -- Emojis in Notification-Titeln. Entfernt
- [A11y] SettingsView.swift:107 -- Picker mit leerem Label. Label gesetzt + labelsHidden
- [A11y] SettingsView.swift:31 -- Checkmark-Icon nicht hidden. accessibilityHidden hinzugefuegt
- [A11y] MenuBarView.swift:98 -- Folder-Icon nicht hidden + Header-Trait fehlte. Beides gefixt
- [Architecture] AppViewModel.swift:72/179 -- authenticate/setupService dupliziert. activateService() extrahiert
- [Architecture] GitHubService.swift:17 -- updateToken() Dead Code + token war var. Entfernt, token zu let

### Minor
- [A11y] RunRowView.swift:36 -- Bullet-Separator von VoiceOver gelesen. accessibilityHidden
- [Architecture] MenuBarView.swift:166 -- openSettings() mit stringly-typed Selector. Durch SettingsLink ersetzt
- [Quality] RunRowView.swift:71 -- statusColor String-zu-Color Indirektion. Eliminiert (Color direkt aus Model)
- [Performance] AppViewModel.swift:31 -- menuBarIcon doppelter Linear-Scan. Single-Pass Loop
- [Quality] project.yml -- entitlements-Block erzeugte leere Datei. Zu CODE_SIGN_ENTITLEMENTS Setting geaendert

## Offene Punkte
Keine.

## Sauber nach Runde 2
Alle Dimensionen.
