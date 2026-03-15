# KlunaAI

KlunaAI ist eine iOS-App (SwiftUI), die Sprachaufnahmen analysiert, emotionale Muster sichtbar macht und personalisierte Reflexionen erzeugt.

## Voraussetzungen

- macOS mit Xcode (aktuelles Stable Release)
- iOS Simulator oder iPhone
- API-Zugaenge fuer:
  - Claude (`CLAUDE_API_KEY`)
  - OpenAI (`OPENAI_API_KEY`) optional/fallback je nach Flow
  - Supabase (`SUPABASE_PROJECT_URL`, `SUPABASE_ANON_KEY`)

## Sicherheit / Secrets

Im Repo sind **keine Live-Secrets** hinterlegt.  
Konfiguration erfolgt zur Laufzeit ueber:

1. Environment Variablen
2. `Info.plist` Build-Settings
3. `UserDefaults` (nur fuer lokale Entwicklung)

Die Reihenfolge ist in `Config/Config.swift` implementiert.

## Schnellstart

### 1) Projekt oeffnen

- `KlunaAI.xcodeproj` in Xcode oeffnen

### 2) Environment Variablen setzen (Schema)

In Xcode:

- Product -> Scheme -> Edit Scheme...
- Run -> Arguments -> Environment Variables

Folgende Keys setzen:

- `CLAUDE_API_KEY`
- `OPENAI_API_KEY`
- `SUPABASE_PROJECT_URL`
- `SUPABASE_ANON_KEY`

Hinweis: `App/Info.plist` erwartet fuer Claude/OpenAI bereits Build-Variablen:

- `$(CLAUDE_API_KEY)`
- `$(OPENAI_API_KEY)`

### 3) Build & Run

- Zielgeraet (Simulator oder iPhone) waehlen
- App starten (`Cmd+R`)

## Lokaler Build per CLI

```bash
xcodebuild -project "KlunaAI.xcodeproj" -scheme "KlunaAI" -sdk iphonesimulator -configuration Debug -derivedDataPath "./DerivedDataLocal" build
```

## Projektstruktur (kurz)

- `App/` App Entry, Root View, App-Config
- `Views/` UI-Flows (Home, Me, Profile, Insights, Onboarding, etc.)
- `ViewModels/` App-Logik und UI-State
- `Core/` Analyse, Scoring, Memory, Audio, Claude, Services
- `Config/` Feature-Flags und Laufzeit-Konfiguration
- `supabase/` SQL-Skripte fuer Tabellen/Views

## Hinweise fuer Contributor

- Keine API-Keys oder Tokens committen.
- Groessere Build-Artefakte und Logs sind via `.gitignore` ausgeschlossen.
- Bei neuen Features mit externen Calls bitte:
  - Failover ohne Key sauber behandeln
  - sensible Daten nicht loggen
  - deutsche und englische Texte beruecksichtigen
