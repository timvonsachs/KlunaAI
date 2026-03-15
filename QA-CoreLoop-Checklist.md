# Kluna AI Core-Loop QA Checklist

## Ziel
Sicherstellen, dass der Premium-Core-Loop konsistent funktioniert:
`Sprechen -> Score Reveal -> Feedback -> Nochmal`.

## Quick Smoke (3 Minuten)
- App starten ohne Onboarding-Reset.
- Pruefen, dass beim allerersten Start der Tab `Ueben` aktiv ist.
- Recording starten, 5+ Sekunden sprechen, Recording stoppen.
- Score Screen muss erscheinen (Ring-Animation + Feedback-Card + Nochmal-Button).
- `Nochmal` druecken: Score-Screen schliesst und neue Aufnahme startet.

## Recording Screen
- Pitch-Pills waehlen: Auswahl sollte visuell sauber wechseln.
- Timer pruefen:
  - mit Time-Limit: Countdown
  - ohne Time-Limit: Count-Up
- Live-Transkription zeigt maximal 2 Zeilen.
- Processing-State: Kreis wechselt auf Spinner mit `Analysiere...`.

## Score Reveal
- Ring animiert von 0 auf Zielscore.
- Score-Zahl zaehlt sichtbar hoch.
- Bei Verbesserung: Delta-Badge erscheint mit richtiger Farbe.
- Erste Sessions: Fokus-Hinweis fuer 3 Dimensionen sichtbar.
- Feedback-Card:
  - skeleton solange leer
  - finaler Text nach Antwort
- Heatmap erscheint nur bei Segmentdaten.

## Score-Sensitivitaet (Dual Scoring) - Pflichttest
- Ziel: Der Score muss auf bewusst unterschiedliche Sprechweisen sichtbar reagieren.
- Vorbereitung:
  - App im Debug auf echtem iPhone starten.
  - In Xcode-Konsole muessen die Blöcke `=== RAW FEATURES ===`, `=== Z-SCORES ===`, `=== SCORES ===` erscheinen.
  - Fuer alle 3 Runs denselben Pitch-Type verwenden.
- Run A (absichtlich schwach, 8-12s):
  - Leise, monoton, eher langsam sprechen.
  - Erwartung: Overall ca. `25-40`, Energy deutlich niedrig.
- Run B (normal, 8-12s):
  - Alltagsstimme, normale Dynamik.
  - Erwartung: Overall ca. `45-60`.
- Run C (absichtlich stark, 8-12s):
  - Lauter, klare Betonung, groessere F0-Range, saubere Pausen.
  - Erwartung: Overall ca. `65-85`, Energy/Confidence klar hoeher als Run A.
- Muss-Kriterium:
  - Differenz `Run C - Run A >= 25` Punkte (Overall).
  - Differenz `Energy(C) - Energy(A) >= 20` Punkte.
- Wenn nicht erfuellt:
  - Konsolenwerte von RAW FEATURES fuer `loudness`, `f0Range`, `speechRate`, `hnr`, `jitter`, `shimmer`, `pauseDuration` vergleichen.
  - Danach Mappings in `DimensionScorer` kalibrieren.

### Ergebnis-Tabelle (kopieren und ausfuellen)
| Run | Sprechstil | Overall | Energy | Confidence | Tempo | Clarity | Stability | Charisma |
|-----|------------|---------|--------|------------|-------|---------|-----------|----------|
| A   | leise/monoton/langsam |         |        |            |       |         |           |          |
| B   | normal     |         |        |            |       |         |           |          |
| C   | energisch/dynamisch/klar |      |        |            |       |         |           |          |

### Debug-Notizen pro Run (optional)
- `loudness=`
- `f0Range=`
- `speechRate=`
- `hnr=`
- `jitter=`
- `shimmer=`
- `pauseDuration=`

## Dashboard
- Hero-Score zeigt 7-Tage-Mittel.
- Trend basiert auf Vorwoche.
- Quick Stats: Sessions, Best, Streak korrekt.
- Free-Tier: Weekly-Report als Lock-Hinweis.
- Pro-Tier: Weekly-Report-Textkarte sichtbar (falls vorhanden).

## Verlauf
- Free-Tier: Inhalte geblurt + Pro-Hinweis.
- Pro-Tier: Chart, Radar, Sessionliste sichtbar.
- Zeitraum-Chips (`7T/30T/90T/Alles`) laden neue Daten.
- Dimension-Chips lassen sich toggeln ohne UI-Glitches.

## Settings
- Wochenziel-Picker persistiert nach App-Neustart.
- Profilwerte werden korrekt angezeigt.
- Upgrade-Button nur fuer Free sichtbar.

## Regression
- Build-Befehl:
  - `xcodebuild -project KlunaAI.xcodeproj -scheme KlunaAI -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData DEVELOPMENT_TEAM=7WJJZXWCKQ build`
- Erwartung: `BUILD SUCCEEDED`.

