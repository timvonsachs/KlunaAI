# PRD – Voice Performance Coach

## Vision

Die erste KI die deine Stimme nicht nur hört sondern versteht wie du wirkst. Voice Biomarker messen in Echtzeit wie überzeugend, energisch und souverän du klingst – nicht verglichen mit einer Norm, sondern mit deiner besten Version. Nach 3 Monaten kennt die App deine Muster besser als jeder Coach. Nach 6 Monaten ist deine Baseline dein altes Bestlevel.

**Tagline:** *„Deine Stimme. Dein Score. Dein Level."*

---

## Problem

Menschen die mit ihrer Stimme Geld verdienen – Vertriebler, Founder, Speaker, Coaches, Creator – trainieren alles außer das wichtigste Werkzeug: ihre Stimme. Bestehende Tools (Yoodli, Speeko, Orai) zählen Füllwörter und messen Tempo. Das ist wie ein Schrittzähler für die Stimme – nützlich, aber generisch.

Niemand vergleicht dich mit dir selbst. Niemand sagt dir „letzten Dienstag bei deinem Pitch an Firma X warst du im Flow – heute klingst du wie vor 3 Wochen als du den Deal verloren hast." Niemand erkennt *wo* in deinem Pitch du Energie verlierst, *wann* du nervös wirst, und *wie* sich deine Confidence über Wochen entwickelt.

Das ändern wir.

---

## Zielgruppe

### Consumer (Feature Flag: Consumer Mode)

- Vertriebler die ihre Close-Rate steigern wollen
- Founder die Investoren pitchen
- Content Creator und Podcaster
- Keynote Speaker und Trainer
- Coaches und Consultants
- Freelancer in Kundengesprächen

### B2B Teams (Feature Flag: Team Mode)

- Sales-Teams (10–200 Personen)
- Leadership Development Programme
- Onboarding neuer Vertriebler
- Trainingsunternehmen und Akademien

### Marktgröße

- Globaler Corporate Training Markt: $380+ Milliarden
- Sales Training: $5+ Milliarden
- Public Speaking Training: $2+ Milliarden
- Leadership Communication: $3+ Milliarden

---

## Core USP

**1. Individualisierte Baseline** – EWMA vergleicht dich mit deiner besten Version. Kein generischer Benchmark. Deine Abweichung von deiner Norm.

**2. 6 Performance-Dimensionen** – Confidence, Energie, Tempo, Klarheit, Stabilität, Überzeugungskraft. Gemappt auf klinisch validierte Voice Biomarker via OpenSMILE (6373 akustische Features).

**3. Fortschritt der sich verschiebt** – Die Baseline wächst mit dir. Nach 3 Monaten ist dein neuer Durchschnitt dein altes Bestlevel. Messbarer Fortschritt, sichtbar in Graphen.

**4. KI-Coach mit Gedächtnis** – Claude kennt deine Schwächen, sieht deine Fortschritte, und gibt Feedback das auf deinen Mustern basiert. Nicht generisch – personalisiert.

**5. Gamification die süchtig macht** – Streaks, Bestenlisten, Challenges. Die Peloton-Loop für die Stimme.

---

## Architektur

### Pipeline

```
┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────┐
│ Sprach-Input │ →  │ Feature-Extrakt. │ →  │ Baseline-Vergl. │ →  │  Score + KI  │
│              │    │                  │    │                 │    │              │
│ AVFoundation │    │ OpenSMILE C++    │    │ Z-Score / EWMA  │    │ 6 Dimensions │
│ Apple Speech │    │ 6373 Features    │    │ 21-Tage Baseline│    │ Claude Coach  │
└──────────────┘    └──────────────────┘    └─────────────────┘    └──────────────┘
```

### On-Device vs. Cloud

| Bleibt auf dem Gerät | Geht an Claude API |
|---|---|
| Rohaudio-Daten | Dimension-Scores (6 Zahlen) |
| OpenSMILE Raw Features | Transkription (Text) |
| EWMA Baseline-Daten | Session-History (Kurzfassung) |
| CoreData Datenbank | Pitch-Typ und Kontext |

---

## Technologie-Stack

| Komponente | Technologie |
|---|---|
| Platform | Swift, iOS nativ |
| Audio-Aufnahme | AVFoundation (Chunk-basiert) |
| Speech-to-Text | Apple Speech (on-device, de-DE + en-US) |
| Feature-Extraktion | OpenSMILE C++ via Bridging Header |
| Baseline | Z-Score / EWMA (custom Swift, portiert aus NOVA) |
| KI-Coach | Claude API (Sonnet) |
| Lokaler Speicher | CoreData (verschlüsselt) |
| Team-Backend | TBD (Firebase / Supabase für B2B Sync) |

---

## Core Loop

### Session-Ablauf

1. **Dashboard** (Startscreen): User sieht seinen Fortschritt – Score-Verlauf, Streak, aktuelle Challenge. Motivation vor der Übung.

2. **Pitch-Typ wählen**: Vordefinierte Templates oder eigene Custom-Typen. Optionales Zeitlimit (z.B. 60s für Elevator Pitch).

3. **Record**: User drückt und spricht. Pulsierender Kreis reagiert auf die Stimme. Apple Speech transkribiert parallel. Optional: Timer-Anzeige wenn Zeitlimit gesetzt.

4. **Sofort-Score**: Gesamt-Score (0–100) erscheint mit Animation. Aufklappbare 6 Detail-Dimensionen darunter. Jede Dimension zeigt Pfeil (besser/schlechter als persönlicher Durchschnitt).

5. **Quick Feedback**: Claude gibt 2–4 Sätze mit einem konkreten, actionable Tipp. Sofort sichtbar.

6. **Deep Coaching** (on demand): Button für ausführliche Analyse. Claude geht auf alle 6 Dimensionen ein, vergleicht mit vergangenen Sessions, gibt 2–3 konkrete Übungen.

7. **Nochmal**: Sofort neu einsprechen. Score-Vergleich mit vorheriger Session. Die Sucht-Loop: Sprechen → Score → Tipp → Nochmal → Score steigt → Dopamin.

### Vordefinierte Pitch-Typen

| Pitch-Typ | Beschreibung | Empf. Zeitlimit |
|---|---|---|
| Elevator Pitch | 30-60 Sekunden, Kernbotschaft | 60s |
| Cold Call Opening | Erste 30 Sekunden eines Kaltanrufs | 30s |
| Discovery Call | Bedarfsanalyse, Fragen stellen | 3min |
| Closing | Abschlussgespräch, Call-to-Action | 2min |
| Keynote Intro | Eröffnung einer Präsentation | 2min |
| Investor Pitch | Startup-Pitch für Investoren | 3min |
| Selbstvorstellung | „Erzähl mal was du machst" | 60s |
| Freie Übung | Kein Template, offenes Format | Kein Limit |

Custom-Typen: User erstellt eigene mit Name, Beschreibung und optionalem Zeitlimit. Beispiel: „Mein Pitch für Firma X", „Quarterly Review Präsentation."

---

## 6 Performance-Dimensionen

### Score-Format

Jede Dimension: 0–100. Der Gesamt-Score ist der gewichtete Durchschnitt aller 6 Dimensionen. Z-Score Werte aus der EWMA-Baseline werden auf die 0–100 Skala normalisiert: 50 = exakt auf Baseline, 100 = deutlich über bester bisheriger Performance, 0 = stark unter Baseline.

### Dimension-Mapping auf Voice Biomarker

#### 1. Confidence (Gewicht: 1.5)

| Voice Feature | Mapping |
|---|---|
| F0-Variabilität | Stabil aber nicht monoton = hoch |
| HNR | Hoher Harmonics-to-Noise = klare, sichere Stimme |
| Jitter | Niedrig = stabile Stimme, kein Zittern |
| Shimmer | Niedrig = konsistente Amplitude |

*Was der User hört:* „Dein Confidence-Score zeigt wie sicher und stabil deine Stimme klingt."

#### 2. Energie (Gewicht: 1.3)

| Voice Feature | Mapping |
|---|---|
| RMS Energy | Lautstärke und Intensität |
| F0-Range | Dynamischer Pitch = mehr Energie |
| Speech Rate | Im optimalen Bereich = energisch |

*Was der User hört:* „Energie misst wie präsent und lebendig du klingst."

#### 3. Tempo (Gewicht: 1.0)

| Voice Feature | Mapping |
|---|---|
| Speech Rate | Silben pro Sekunde vs. persönliche Baseline |
| Pausen-Dauer | Strategische Pausen vs. Unsicherheits-Pausen |
| Pausen-Verteilung | Gleichmäßig vs. chaotisch |

*Was der User hört:* „Tempo zeigt ob dein Sprechtempo im Sweet Spot liegt – nicht zu schnell, nicht zu langsam."

#### 4. Klarheit (Gewicht: 1.0)

| Voice Feature | Mapping |
|---|---|
| HNR | Signal-zu-Rausch der Stimme |
| Formanten F1–F4 | Stabilität = klare Artikulation |
| Shimmer | Niedrig = sauberer Klang |

*Was der User hört:* „Klarheit misst wie verständlich und artikuliert du sprichst."

#### 5. Stabilität (Gewicht: 1.0)

| Voice Feature | Mapping |
|---|---|
| F0-Varianz innerhalb der Session | Gleichmäßig = stabil |
| Energy-Verlauf über Zeit | Kein Einbruch am Ende |
| Jitter/Shimmer-Trend | Nicht ansteigend über die Session |

*Was der User hört:* „Stabilität zeigt ob du dein Level über den ganzen Pitch hältst oder am Ende einbrichst."

#### 6. Überzeugungskraft (Gewicht: 1.5)

| Voice Feature | Mapping |
|---|---|
| Meta-Score | Gewichtete Kombination aller 5 anderen Dimensionen |
| F0-Dynamik | Bewusste Betonung, nicht monoton |
| Strategische Pausen | Kurze Stille vor wichtigen Punkten |
| Energie im letzten Drittel | Starkes Finish |

*Was der User hört:* „Überzeugungskraft ist der Gesamteindruck – würde man dir das abkaufen?"

---

## Z-Score / EWMA Baseline

### Mechanismus

Identisch mit NOVA/Sesame. Jedes Feature wird gegen die persönliche EWMA-Baseline verglichen.

- **EWMA Decay:** α = 0.1
- **Baseline-Etablierung:** 21 Sessions (nicht Tage – bei täglicher Nutzung 3 Wochen)
- **Z-Score:** `(value - ewmaMean) / √ewmaVariance`

### Normalisierung auf 0–100

```
score = 50 + (zScore × 15)
score = max(0, min(100, score))
```

Ein Z-Score von 0 (exakt auf Baseline) = Score 50. Z-Score +2 (deutlich über Baseline) = Score 80. Z-Score -2 (deutlich unter) = Score 20.

### Aufwärtstrend

Im Gegensatz zu Mental Health (wo Stabilität das Ziel ist) verschiebt sich die Baseline hier nach oben wenn der User besser wird. Das bedeutet: ein Score von 50 nach 3 Monaten Training repräsentiert ein höheres absolutes Level als 50 am Tag 1. Der Fortschritt ist im Score-Verlauf-Graph sichtbar auch wenn der Score „gleich" aussieht.

### Vor Baseline-Etablierung (< 21 Sessions)

Scores werden angezeigt aber als „vorläufig" markiert. Kein Bestenlisten-Eintrag. Streaks zählen trotzdem. Claude gibt Feedback basierend auf Inhalt und absolute Werte statt Baseline-Vergleich.

---

## Gamification

### Streaks

- User wählt Wochen-Ziel: 3, 5 oder 7 Sessions pro Woche
- Streak zählt Wochen in Folge in denen das Ziel erreicht wurde
- Visuell: Feuer-Icon mit Wochenzähler
- Streak-Freeze: 1x pro Monat im Free-Tier, unbegrenzt in Pro
- Streak-Meilensteine: 4 Wochen, 12 Wochen, 26 Wochen, 52 Wochen

### Bestenlisten

**Global:**
- Tab 1: „Top Score" – Gesamt-Score Durchschnitt der letzten 7 Tage
- Tab 2: „Top Improvement" – Größte Score-Veränderung über 30 Tage
- Anonymisiert oder mit Username (User wählt)
- Filterbar nach Pitch-Typ

**Team (B2B):**
- Gleiche Tabs, nur innerhalb des eigenen Teams sichtbar
- Team-Durchschnitt als Benchmark
- Admin sieht nur aggregierte Daten, keine individuellen Scores

### Challenges

**Weekly Challenges (automatisch rotierend):**
- „Verbessere deinen Confidence-Score um 5 Punkte"
- „Sprich 3 verschiedene Pitch-Typen ein"
- „Erreiche einen Energie-Score über 80"
- „Halte eine 5-Session Streak diese Woche"
- „Verbessere deinen schwächsten Score um 10 Punkte"

**Monthly Challenges:**
- „30 Sessions diesen Monat"
- „Verbessere deinen Gesamt-Score um 15 Punkte"
- „Erstelle und übe 3 eigene Pitch-Typen"

**Team Challenges (B2B):**
- „Welches Team hat die höchste durchschnittliche Verbesserung?"
- „Team-Streak: Jedes Teammitglied mindestens 3 Sessions diese Woche"

---

## Analytics Dashboard (Startscreen)

### 1. Score-Verlauf über Zeit (Linien-Graph)

Gesamt-Score und einzelne Dimensionen über Wochen/Monate. Filterbar nach Pitch-Typ und Dimension. Zeigt Trend-Linie und persönliches Allzeit-Hoch.

### 2. Dimensions-Radar (Spinnen-Netz)

6 Achsen für die 6 Dimensionen. Zeigt aktuellen Durchschnitt (letzte 7 Tage) vs. Durchschnitt vor 30 Tagen. Sofort sichtbar wo der User stark ist und wo er arbeiten muss.

### 3. Session-Vergleich

Zwei Sessions nebeneinander: alle 6 Scores, Gesamt-Score, Claude-Feedback. User wählt welche Sessions er vergleichen will. Ideal für „vorher/nachher" nach einer Übungsrunde.

### 4. Heatmap

Zeigt *innerhalb* einer Session wo die Performance einbricht. X-Achse = Zeit (Abschnitte des Pitches), Y-Achse = Dimensionen. Grün = stark, Gelb = mittel, Rot = schwach. Macht sichtbar: „Im zweiten Drittel deines Pitches verlierst du Confidence und Energie."

---

## Claude KI-Coach

### Quick Feedback (nach jeder Session)

- 2–4 Sätze, ein konkreter Tipp
- Bezieht sich auf die stärkste Abweichung
- Actionable: „Beim nächsten Mal halt dein Tempo im Schlussteil – du bist von 3.5 auf 4.8 Silben pro Sekunde gesprungen"
- Vergleicht mit vorherigen Sessions wenn Baseline etabliert

### Deep Coaching (on demand)

- Ausführliche Analyse aller 6 Dimensionen
- Vergleich mit den letzten 5 Sessions
- 2–3 konkrete Übungen / Techniken
- Muster-Erkennung: „Jedes Mal wenn du über Pricing sprichst beschleunigt dein Tempo – übe diesen Abschnitt separat"
- Personalisiert basierend auf Session-History und bekannten Schwächen

### Prompt-Architektur

Definiert in CLAUDE.md. Zwei-Schicht-System:
- **Statisch:** Persona, User-Name, bekannte Stärken/Schwächen, Langzeit-Profil
- **Dynamisch:** Aktuelle Scores, Transkription, letzte Sessions, Pitch-Typ

### Sprache

Claude antwortet in der App-Sprache des Users (Deutsch oder Englisch). Ton: direkt, motivierend, konkret. Nicht therapeutisch – Coach-Stil. Wie ein Personal Trainer der pusht aber respektiert.

---

## B2B Team-Layer (Feature Flag)

### Rollen

| Rolle | Rechte |
|---|---|
| Admin | Team erstellen, Team-Code generieren, aggregierte Stats sehen, Team-Challenges erstellen |
| Member | Eigene Sessions, eigene Stats, Team-Bestenliste sehen, an Team-Challenges teilnehmen |

### Admin-Dashboard

- Team-Durchschnitt über Zeit (Gesamt + pro Dimension)
- Anzahl aktive Members diese Woche
- Team-Streak-Status
- Challenge-Fortschritt
- Keine individuellen Scores oder Sessions sichtbar

### Team-Onboarding

1. Admin erstellt Team, erhält Team-Code
2. Member laden App herunter, geben Team-Code ein
3. Member erscheint im Team, behält eigene Consumer-Features
4. Admin sieht aggregierte Daten ab sofort

### Pricing

- Team-Lizenz: €100–150/User/Monat
- Minimum: 5 User
- Inkludiert: Alle Pro-Features + Team-Features
- Abrechnung: Monatlich oder jährlich (15% Rabatt)

---

## Monetarisierung

### Free Tier

| Feature | Verfügbar |
|---|---|
| Sessions pro Woche | 3 |
| Gesamt-Score | ✅ |
| 6 Detail-Dimensionen | ❌ |
| Quick Feedback (Claude) | ✅ |
| Deep Coaching | ❌ |
| Pitch-Typen | Nur „Elevator Pitch" |
| Custom Pitch-Typen | ❌ |
| Streaks | ❌ |
| Bestenlisten | ❌ |
| Analytics Dashboard | ❌ |
| Session-History | Letzte 3 Sessions |
| Heatmap | ❌ |
| Session-Vergleich | ❌ |

### Pro (€20/Monat oder €15/Monat jährlich)

| Feature | Verfügbar |
|---|---|
| Sessions | Unbegrenzt |
| Gesamt-Score | ✅ |
| 6 Detail-Dimensionen | ✅ |
| Quick Feedback | ✅ |
| Deep Coaching | ✅ |
| Alle Pitch-Typen | ✅ |
| Custom Pitch-Typen | ✅ |
| Streaks | ✅ |
| Globale Bestenliste | ✅ |
| Analytics Dashboard | ✅ |
| Vollständige Session-History | ✅ |
| Heatmap | ✅ |
| Session-Vergleich | ✅ |
| Streak-Freeze | Unbegrenzt |

### Team (€100–150/User/Monat, min. 5 User)

| Feature | Verfügbar |
|---|---|
| Alle Pro-Features | ✅ |
| Team-Code & Onboarding | ✅ |
| Team-Bestenliste | ✅ |
| Admin-Dashboard (aggregiert) | ✅ |
| Team-Challenges | ✅ |
| Prioritäts-Support | ✅ |

---

## Datenmodell (CoreData)

### Session

| Feld | Typ | Beschreibung |
|---|---|---|
| id | UUID | Eindeutige Session-ID |
| date | Date | Zeitstempel |
| pitchType | String | Pitch-Typ (vordefiniert oder custom) |
| duration | TimeInterval | Aufnahmedauer |
| overallScore | Double | Gesamt-Score 0–100 |
| confidenceScore | Double | 0–100 |
| energyScore | Double | 0–100 |
| tempoScore | Double | 0–100 |
| clarityScore | Double | 0–100 |
| stabilityScore | Double | 0–100 |
| persuasivenessScore | Double | 0–100 |
| featureZScores | [String: Double] | Raw Z-Scores pro OpenSMILE Feature |
| transcription | String | On-device transkribierter Text |
| quickFeedback | String | Claude Quick Feedback |
| deepCoaching | String? | Claude Deep Coaching (optional) |
| heatmapData | Data | Scores pro Zeitabschnitt (JSON) |

### Baseline

| Feld | Typ | Beschreibung |
|---|---|---|
| feature | String | Feature-Name |
| ewmaMean | Double | Laufender EWMA-Durchschnitt |
| ewmaVariance | Double | Laufende EWMA-Varianz |
| sampleCount | Int | Anzahl Messungen |
| lastUpdated | Date | Letzte Aktualisierung |

### UserProfile

| Feld | Typ | Beschreibung |
|---|---|---|
| name | String | User-Name |
| language | String | de / en |
| weeklyGoal | Int | 3, 5 oder 7 Sessions |
| currentStreak | Int | Wochen in Folge |
| firstSessionDate | Date | Erste Session |
| longTermProfile | String? | Nach 30 Sessions |
| teamCode | String? | Team-Zugehörigkeit (B2B) |
| role | String | consumer / member / admin |

### PitchType

| Feld | Typ | Beschreibung |
|---|---|---|
| id | UUID | Eindeutige ID |
| name | String | Name des Pitch-Typs |
| description | String | Beschreibung |
| timeLimit | Int? | Optionales Zeitlimit in Sekunden |
| isCustom | Bool | Vordefiniert oder custom |
| isDefault | Bool | Vorinstalliert |

---

## MVP Timeline (4 Wochen)

| Woche | Deliverables |
|---|---|
| **Woche 1** | Xcode-Projekt, AVFoundation Pipeline, Apple Speech (de+en), OpenSMILE Bridging, Feature-Extraktion verifiziert |
| **Woche 2** | EWMA Engine, 6-Dimensionen-Mapping, Score-Normalisierung 0–100, CoreData Schema, Claude API + Prompt Builder |
| **Woche 3** | Dashboard UI, Recording-Screen, Score-Anzeige mit Dimensionen, Quick Feedback, Deep Coaching, Pitch-Typ Auswahl, Heatmap-Berechnung |
| **Woche 4** | Streaks, Bestenlisten (Global), Challenges, Analytics-Graphen (Verlauf + Radar + Vergleich + Heatmap), Onboarding, Paywall, TestFlight |

B2B Team-Layer: Woche 5–6 (nach Consumer-MVP validiert).

---

## Erfolgsmetriken

**Technisch:** Feature-Extraktion < 500ms. Score-Berechnung < 100ms. Claude Quick Feedback < 3s. Gesamtlatenz < 5s.

**Produkt:** 70% nutzen die App 3x in der ersten Woche. 50% Retention nach 30 Tagen. 8% Free-to-Pro Conversion.

**Qualitativ:** User berichten messbaren Fortschritt nach 2 Wochen. Mindestens 5 von 10 Testuser sagen: „So hat mir noch nie jemand Feedback gegeben."

**Revenue (12 Monate):** 500 Consumer Pro + 3 B2B Teams = €15k+ MRR.

---

## Explizit außerhalb MVP

- Android-Version
- Video-Analyse (Gestik, Mimik)
- Live-Coaching während Zoom/Teams Calls
- Gong/Salesforce Integration
- Coach-Rolle im B2B
- TTS-Feedback (Sprach-Output)
- Offline-Modus
- Apple Watch Companion

---

## Langfristige Roadmap

**Phase 1 – Consumer MVP (jetzt):** Core Loop, 6 Dimensionen, Gamification, Analytics. Cashflow starten.

**Phase 2 – B2B (Monat 2–3):** Team-Layer, Admin-Dashboard, Team-Challenges. Erste Enterprise-Deals.

**Phase 3 – Tiefe (Monat 4–8):** Video-Analyse, Zoom-Integration, Coach-Rolle, erweiterte Heatmaps, API für Drittanbieter.

**Phase 4 – Platform (Jahr 1–2):** SDK-Lizenzierung der Voice-Engine. Trainingsplattformen, HR-Tech, EdTech. Die Engine wird zur Infrastruktur.

---

*„Deine Stimme. Dein Score. Dein Level."*
