# Audit Learning Log

Dieses Log wird automatisch nach jedem Audit aktualisiert.

## Trends (Stand 2026-06-11)

| Metrik | Wert |
|---|---|
| Audits total | 3 |
| Critical-Trend (letzte 3) | 8 -> 0 -> 1 (sinkend) |
| Important-Trend (letzte 3) | 16 -> 6 -> 12 |
| Top-Kategorie (letzte 5) | A11y (~14x) |
| Avg Findings/Audit | ~22 |

**Wiederkehrer (>=3 Audits):**
- A11y accessibilityLabel/accessibilityHidden fehlt bei neuen SwiftUI-Views — Kandidat fuer Guideline-Update
- Host-Validierung via hasSuffix ohne fuehrenden Punkt (Lookalike-Risiko) — Kandidat fuer Guideline-Update

---

## Retro — 2026-06-11 — main (full-audit)

### Statistik
- Audits insgesamt im Projekt: 3 (2026-03-14 full, 2026-03-26 main, 2026-06-11 full)
- Haeufigste Finding-Kategorie: A11y (ca. 14x ueber alle Audits, Code Quality dicht dahinter ~16x)
- Durchschnittliche Findings pro Audit: ~22 (51 gesamt / 3, ohne Verworfene)

### Was lief gut
- Adversariale R2-Verifikation hat 2 selbst eingefuehrte Bugs gefangen (accessibilityAction ohne isRerunning-Guard, Lookalike-Host im neuen Helper). Verifikationsrunde zahlt sich messbar aus.
- False Positive vermieden: globale Monotonie der GitHub Run-IDs extern verifiziert statt blind als Bug zu melden (suffix(n) nach sorted() ist korrekt).
- Critical-Trend sinkend (8 → 0 → 1), Codebase stabilisiert sich.

### Was lief schlecht
- Ein in 3-14 eingefuehrter Security-Fix (`hasSuffix("github.com")`) war selbst angreifbar (evilgithub.com) und musste 6-11 nachgebessert werden. Host-Suffix-Checks ohne fuehrenden Punkt sind ein wiederkehrender Fehlertyp.
- Hover-gatete Aktionen (RunRowView) blieben nach dem 3-14-A11y-Pass unerkannt a11y-defekt — erst 6-11 als Critical gefunden.

### Was hat gefehlt
- Kein Test-Target im Projekt (in 6-11 als Open Point, auch davor implizit). GitHubService und Notification-Transition-Logik bleiben dauerhaft ungetestet.
- Audit hatte kein gezieltes SwiftUI-Muster fuer onHover-gatete Controls — wurde zufaellig erst spaet gefunden.

### Erkannte Patterns
- SwiftUI Hover-only Controls (onHover-revealed Buttons) sind per VoiceOver/Keyboard unerreichbar. Standard-Fix: `.accessibilityActions` statt Redesign.
- Host-Validierung via `hasSuffix("domain.tld")` ohne fuehrenden Punkt erlaubt Lookalike-Domains. Korrekt: `host == "domain.tld" || host.hasSuffix(".domain.tld")`.
- `@ObservedObject` auf einem ViewModel in einer List-Row → Re-Render aller Rows bei jedem @Published-Change. Idiomatisch: plain `let viewModel` + value-Props fuer struct-equality skip.
- A11y `accessibilityLabel`/`accessibilityHidden` auf Icons/Buttons fehlt wiederholt bei neuen SwiftUI-Views.
- Eigene Audit-Fixes koennen neue Minor-Bugs einfuehren — Verifikationsrunde noetig.

### Vorgeschlagene Verbesserungen
- [x] guidelines/a11y.md (oder a11y-agent): SwiftUI-spezifische Regel — bei `onHover`-gateten Aktionen (Button erst bei Hover sichtbar) immer `.accessibilityActions` als aequivalenten Pfad fordern; nicht Redesign. Standard-Critical fuer SwiftUI-Menubar/List-UIs. (applied 2026-09-03: guidelines/native-mobile.md section XVI)
- [x] guidelines/security.md (oder security-agent): Host-Allowlist-Regel — `hasSuffix("github.com")` o.ae. ohne fuehrenden Punkt als Finding flaggen; verlangter Fix `host == X || host.hasSuffix("." + X)`. (applied 2026-09-03: guidelines/security.md section XIX)
- [x] guidelines/performance.md (oder performance-agent): SwiftUI List-Row-Regel — `@ObservedObject`/`@StateObject` eines parent-ViewModels in einer Row ist ein Re-Render-Smell; value-Props + plain `let` als Standard-Fix. (applied 2026-09-03: guidelines/native-mobile.md section XVII)
- [x] full-audit-agent (false-positive-Hinweis): Bei "monoton/ID-basiertem Pruning" externe Fakten pruefen (z.B. GitHub Run-IDs sind GLOBAL monoton, nicht per-repo), bevor als semantischer Bug gemeldet. (applied 2026-09-03: agents/finding-verifier.md, external-system facts rule)
- [x] eval-fixture: a11y/swiftui-hover-only-control — Button nur via `.opacity(isHovering ? 1 : 0)`/onHover sichtbar, ohne `.accessibilityActions`: muss als Critical erkannt werden. (applied 2026-09-03: evals/fixtures/a11y/queue-row-delete-action.swift)
- [x] eval-fixture: security/host-suffix-lookalike — `url.host?.hasSuffix("github.com")` muss als unsicher (erlaubt evilgithub.com) erkannt werden; korrekter Fix verlangt fuehrenden Punkt bzw. Gleichheit. (applied 2026-09-03: guidelines/security.md section XIX)
