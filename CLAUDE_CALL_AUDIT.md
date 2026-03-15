# Claude Call Audit

Stand: 2026-03-06

## Zielbild

Erlaubte Call-Typen:

1. `analyzeEntry()` (ein Call pro Journal-Aufnahme)
2. `generateVoiceType()` (max. 1x pro 7 Tage)
3. `generateWeeklySummary()` (max. 1x pro 7 Tage)
4. `generateMonthlyLetter()` (max. 1x pro 28 Tage)

## Gefundene Anthropic-Einstiegspunkte

### 1) Journal-Aufnahme (Voice Journal) - aktiv

- Datei: `ViewModels/JournalViewModel.swift`
- Call: `CoachAPIManager.requestCoaching(...)`
- Trigger: pro abgeschlossener Aufnahme
- Status: **OK**
- Details:
  - Prompt ist in demselben Response enthalten (`PROMPT:`), kein separater Prompt-Call
  - `CoachAPIManager` nutzt shared `URLSession`, 3s Throttle, Retry inkl. `retry-after` bei `429`

### 2) Insights Woche - aktiv

- Datei: `Views/Insights/JournalInsightsView.swift`
- Call: `CoachAPIManager.requestInsights(...)` (unified week JSON)
- Trigger: Insights-Refresh
- Gate: `PeriodicClaudeCalls.shouldGenerateWeeklySummary()` + Cache
- Status: **OK (periodisch)**

### 3) Insights Monat - aktiv

- Datei: `Views/Insights/JournalInsightsView.swift`
- Call: `CoachAPIManager.requestInsights(...)` (`WORD:` + `LETTER:` in einem Call)
- Trigger: Insights-Refresh
- Gate: `PeriodicClaudeCalls.shouldGenerateMonthlyLetter()` + Cache
- Status: **OK (periodisch)**

### 4) Weekly Report (Performance-Bereich) - aktiv

- Datei: `App/RootView.swift`
- Call: `ClaudeService.generateWeeklyReport(...)`
- Trigger: beim App-Start/Task
- Gate: nur sonntags oder bei Sprachwechsel + nicht mehrfach am selben Tag
- Status: **OK (periodisch, 7d-ähnlich)**

## Zusätzliche aktive Claude-Calls außerhalb Zielbild

### 5) Session-Coach-Feedback (Performance-Flow) - aktiv

- Datei: `ViewModels/SessionViewModel.swift`
- Call: `CoachAPIManager.requestCoaching(...)`
- Trigger: pro Performance-Session
- Status: **NICHT im Zielbild für reines Journal**
- Hinweis: Dieser Call gehört zum Voice-Coach-Modul, nicht zum Journal-Entry-Flow.

### 6) Deep Coaching (on demand) - aktiv

- Datei: `ViewModels/SessionViewModel.swift`
- Call: `ClaudeService.getDeepCoaching(...)`
- Trigger: nur explizit via `requestDeepCoaching(...)`
- Status: **on-demand, aber außerhalb Zielbild**

### 7) Profil-Generierung (Performance) - aktiv

- Datei: `ViewModels/SessionViewModel.swift`
- Call: `ClaudeService.generateProfile(...)`
- Trigger: wenn `memoryManager.shouldGenerateProfile(...)` true
- Status: **periodisch heuristisch, außerhalb Zielbild**

## Bereits entfernte/abgeschaltete Mehrfach-Calls

- Separater Prompt-Claude-Call in `PromptManager.generateNextPrompt(...)` wurde auf lokale Prompt-Erzeugung umgestellt (kein Anthropic-Request mehr).
- Pattern-Claude-Call in Insights wurde entfernt (Fallback lokal).
- Week-Insights von 3 Calls auf 1 Unified-Call reduziert.
- Month-Insights von 2 Calls auf 1 Unified-Call reduziert.

## Fazit

- **Journal-Flow ist sauber auf 1 Claude-Call pro Eintrag reduziert.**
- **Insights sind periodisch und stark reduziert.**
- **Es existieren weiterhin Performance-Coach-Calls (Session/Deep/Profile), die bewusst außerhalb des Journal-Zielbilds liegen.**

## Wenn strikt "nur 4 Call-Typen" gelten soll

Dann müssen im nächsten Schritt diese Performance-Calls deaktiviert oder ebenfalls auf periodische/pfadabhängige Gates umgestellt werden:

- `SessionViewModel` -> `CoachAPIManager.requestCoaching(...)`
- `SessionViewModel` -> `ClaudeService.getDeepCoaching(...)`
- `SessionViewModel` -> `ClaudeService.generateProfile(...)`
