# PRD – Voice Performance Coach

## Vision

The first AI that doesn't just hear your voice but understands how you come across. Voice biomarkers measure in real-time how confident, energetic, and compelling you sound – not compared to a generic norm, but to your personal best. After 3 months the app knows your patterns better than any coach. After 6 months your baseline IS your former peak.

**Tagline:** *"Your voice. Your score. Your level."*

---

## Problem

People who make money with their voice – salespeople, founders, speakers, coaches, creators – train everything except their most important tool: their voice. Existing tools (Yoodli, Speeko, Orai) count filler words and measure pace. That's a step counter for the voice – useful, but generic.

Nobody compares you to yourself. Nobody tells you "last Tuesday during your pitch to Company X you were in flow – today you sound like 3 weeks ago when you lost that deal." Nobody detects *where* in your pitch you lose energy, *when* you get nervous, and *how* your confidence develops over weeks.

We change that.

---

## Target Audience

### Consumer (Feature Flag: Consumer Mode)

- Salespeople looking to improve their close rate
- Founders pitching investors
- Content creators and podcasters
- Keynote speakers and trainers
- Coaches and consultants
- Freelancers in client conversations

### B2B Teams (Feature Flag: Team Mode)

- Sales teams (10–200 people)
- Leadership development programs
- New hire onboarding for sales roles
- Training companies and academies

### Market Size

- Global corporate training market: $380+ billion
- Sales training: $5+ billion
- Public speaking training: $2+ billion
- Leadership communication: $3+ billion

---

## Core USP

**1. Individualized Baseline** – EWMA compares you to your best self. No generic benchmark. Your deviation from your own norm.

**2. 6 Performance Dimensions** – Confidence, Energy, Tempo, Clarity, Stability, Persuasiveness. Mapped to clinically validated voice biomarkers via OpenSMILE (6,373 acoustic features).

**3. Progress that shifts upward** – The baseline grows with you. After 3 months your new average IS your former peak. Measurable progress, visible in graphs.

**4. AI Coach with memory** – Claude knows your weaknesses, sees your progress, and gives feedback based on your personal patterns. Not generic – personalized.

**5. Addictive gamification** – Streaks, leaderboards, challenges. The Peloton loop for your voice.

---

## Architecture

### Pipeline

```
┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────┐
│ Voice Input  │ →  │ Feature Extract. │ →  │ Baseline Comp.  │ →  │ Score + AI   │
│              │    │                  │    │                 │    │              │
│ AVFoundation │    │ OpenSMILE C++    │    │ Z-Score / EWMA  │    │ 6 Dimensions │
│ Apple Speech │    │ 6,373 Features   │    │ 21-Day Baseline │    │ Claude Coach  │
└──────────────┘    └──────────────────┘    └─────────────────┘    └──────────────┘
```

### On-Device vs. Cloud

| Stays on device | Sent to Claude API |
|---|---|
| Raw audio data | Dimension scores (6 numbers) |
| OpenSMILE raw features | Transcription (text) |
| EWMA baseline data | Session history (summary) |
| CoreData database | Pitch type and context |

---

## Technology Stack

| Component | Technology |
|---|---|
| Platform | Swift, iOS native |
| Audio recording | AVFoundation (chunk-based) |
| Speech-to-text | Apple Speech (on-device, en-US + de-DE) |
| Feature extraction | OpenSMILE C++ via Bridging Header |
| Baseline | Z-Score / EWMA (custom Swift, ported from NOVA) |
| AI Coach | Claude API (Sonnet) |
| Local storage | CoreData (encrypted) |
| Team backend | TBD (Firebase / Supabase for B2B sync) |

---

## Core Loop

### Session Flow

1. **Dashboard** (home screen): User sees their progress – score trend, streak, current challenge. Motivation before practice.

2. **Choose pitch type**: Pre-defined templates or custom types. Optional time limit (e.g., 60s for elevator pitch).

3. **Record**: User presses and speaks. Pulsating circle responds to voice. Apple Speech transcribes in parallel. Optional: timer display if time limit is set.

4. **Instant Score**: Overall score (0–100) appears with animation. Expandable 6 detail dimensions below. Each dimension shows arrow (better/worse than personal average).

5. **Quick Feedback**: Claude gives 2–4 sentences with one concrete, actionable tip. Immediately visible.

6. **Deep Coaching** (on demand): Button for detailed analysis. Claude addresses all 6 dimensions, compares with past sessions, gives 2–3 concrete exercises.

7. **Again**: Record again immediately. Score comparison with previous attempt. The addiction loop: Speak → Score → Tip → Again → Score rises → Dopamine.

### Pre-defined Pitch Types

| Pitch Type | Description | Rec. Time Limit |
|---|---|---|
| Elevator Pitch | 30-60 seconds, core message | 60s |
| Cold Call Opening | First 30 seconds of a cold call | 30s |
| Discovery Call | Needs analysis, asking questions | 3min |
| Closing | Closing conversation, call-to-action | 2min |
| Keynote Intro | Opening of a presentation | 2min |
| Investor Pitch | Startup pitch for investors | 3min |
| Self-Introduction | "Tell me what you do" | 60s |
| Free Practice | No template, open format | No limit |

Custom types: User creates their own with name, description, and optional time limit. Example: "My pitch for Company X", "Quarterly review presentation."

---

## 6 Performance Dimensions

### Score Format

Each dimension: 0–100. Overall score is the weighted average of all 6 dimensions. Z-Score values from EWMA baseline are normalized to 0–100 scale: 50 = exactly on baseline, 100 = significantly above personal best, 0 = far below baseline.

### Dimension Mapping to Voice Biomarkers

#### 1. Confidence (Weight: 1.5)

| Voice Feature | Mapping |
|---|---|
| F0 variability | Stable but not monotone = high |
| HNR | High harmonics-to-noise = clear, confident voice |
| Jitter | Low = stable voice, no trembling |
| Shimmer | Low = consistent amplitude |

*What the user sees:* "Confidence shows how secure and stable your voice sounds."

#### 2. Energy (Weight: 1.3)

| Voice Feature | Mapping |
|---|---|
| RMS Energy | Volume and intensity |
| F0 range | Dynamic pitch = more energy |
| Speech Rate | In optimal range = energetic |

*What the user sees:* "Energy measures how present and alive you sound."

#### 3. Tempo (Weight: 1.0)

| Voice Feature | Mapping |
|---|---|
| Speech Rate | Syllables per second vs. personal baseline |
| Pause duration | Strategic pauses vs. uncertainty pauses |
| Pause distribution | Even vs. chaotic |

*What the user sees:* "Tempo shows whether your speaking pace is in the sweet spot – not too fast, not too slow."

#### 4. Clarity (Weight: 1.0)

| Voice Feature | Mapping |
|---|---|
| HNR | Signal-to-noise ratio of the voice |
| Formants F1–F4 | Stability = clear articulation |
| Shimmer | Low = clean sound |

*What the user sees:* "Clarity measures how understandable and well-articulated you are."

#### 5. Stability (Weight: 1.0)

| Voice Feature | Mapping |
|---|---|
| F0 variance within session | Even = stable |
| Energy trajectory over time | No drop-off at the end |
| Jitter/Shimmer trend | Not increasing over the session |

*What the user sees:* "Stability shows whether you maintain your level throughout the pitch or fade at the end."

#### 6. Persuasiveness (Weight: 1.5)

| Voice Feature | Mapping |
|---|---|
| Meta-score | Weighted combination of all 5 other dimensions |
| F0 dynamics | Deliberate emphasis, not monotone |
| Strategic pauses | Brief silence before key points |
| Energy in final third | Strong finish |

*What the user sees:* "Persuasiveness is the overall impression – would someone buy what you're selling?"

---

## Z-Score / EWMA Baseline

### Mechanism

Identical to NOVA/Sesame. Each feature is compared against the personal EWMA baseline.

- **EWMA Decay:** α = 0.1
- **Baseline establishment:** 21 sessions (not days)
- **Z-Score:** `(value - ewmaMean) / √ewmaVariance`

### Normalization to 0–100

```
score = 50 + (zScore × 15)
score = max(0, min(100, score))
```

Z-Score of 0 (exactly on baseline) = Score 50. Z-Score +2 (well above baseline) = Score 80. Z-Score -2 (well below) = Score 20.

### Upward Trend

Unlike mental health (where stability is the goal), the baseline shifts upward as the user improves. A score of 50 after 3 months of training represents a higher absolute level than 50 on day 1. The progress is visible in the score history graph even when the score "looks the same."

### Before Baseline Establishment (< 21 Sessions)

Scores are displayed but marked as "preliminary." No leaderboard entry. Streaks still count. Claude gives feedback based on content and absolute values rather than baseline comparison.

---

## Gamification

### Streaks

- User chooses weekly goal: 3, 5, or 7 sessions per week
- Streak counts consecutive weeks where goal was met
- Visual: fire icon with week counter
- Streak freeze: 1x per month on Free tier, unlimited on Pro
- Streak milestones: 4 weeks, 12 weeks, 26 weeks, 52 weeks

### Leaderboards

**Global:**
- Tab 1: "Top Score" – Overall score average of last 7 days
- Tab 2: "Top Improvement" – Largest score change over 30 days
- Anonymous or with username (user chooses)
- Filterable by pitch type

**Team (B2B):**
- Same tabs, visible only within own team
- Team average as benchmark
- Admin sees only aggregated data, no individual scores

### Challenges

**Weekly Challenges (auto-rotating):**
- "Improve your Confidence score by 5 points"
- "Record 3 different pitch types"
- "Reach an Energy score above 80"
- "Maintain a 5-session streak this week"
- "Improve your weakest score by 10 points"

**Monthly Challenges:**
- "30 sessions this month"
- "Improve your overall score by 15 points"
- "Create and practice 3 custom pitch types"

**Team Challenges (B2B):**
- "Which team has the highest average improvement?"
- "Team streak: every member at least 3 sessions this week"

---

## Analytics Dashboard (Home Screen)

### 1. Score History (Line Graph)

Overall score and individual dimensions over weeks/months. Filterable by pitch type and dimension. Shows trend line and personal all-time high.

### 2. Dimensions Radar (Spider Web)

6 axes for 6 dimensions. Shows current average (last 7 days) vs. average 30 days ago. Instantly visible where the user is strong and where they need work.

### 3. Session Comparison

Two sessions side by side: all 6 scores, overall score, Claude feedback. User chooses which sessions to compare. Ideal for "before/after" comparisons.

### 4. Heatmap

Shows *within* a session where performance drops. X-axis = time (pitch segments), Y-axis = dimensions. Green = strong, yellow = medium, red = weak. Makes visible: "In the middle third of your pitch you lose Confidence and Energy."

---

## Claude AI Coach

### Quick Feedback (after every session)

- 2–4 sentences, one concrete tip
- References the strongest deviation
- Actionable: "Next time hold your pace in the closing – you jumped from 3.5 to 4.8 syllables per second"
- Compares with previous sessions when baseline is established

### Deep Coaching (on demand)

- Detailed analysis of all 6 dimensions
- Comparison with last 5 sessions
- 2–3 concrete exercises / techniques
- Pattern recognition: "Every time you talk about pricing your tempo accelerates – practice that section separately"
- Personalized based on session history and known weaknesses

### Prompt Architecture

Defined in CLAUDE.md. Two-layer system:
- **Static:** Persona, user name, known strengths/weaknesses, long-term profile
- **Dynamic:** Current scores, transcription, recent sessions, pitch type

### Language

Claude responds in the user's app language (German or English). Tone: direct, motivating, concrete. Not therapeutic – coach style. Like a personal trainer who pushes but respects.

---

## B2B Team Layer (Feature Flag)

### Roles

| Role | Permissions |
|---|---|
| Admin | Create team, generate team code, view aggregated stats, create team challenges |
| Member | Own sessions, own stats, view team leaderboard, participate in team challenges |

### Admin Dashboard

- Team average over time (overall + per dimension)
- Number of active members this week
- Team streak status
- Challenge progress
- No individual scores or sessions visible

### Team Onboarding

1. Admin creates team, receives team code
2. Members download app, enter team code
3. Member appears in team, keeps all consumer features
4. Admin sees aggregated data immediately

### Pricing

- Team license: €100–150/user/month
- Minimum: 5 users
- Includes: All Pro features + team features
- Billing: Monthly or annually (15% discount)

---

## Monetization

### Free Tier

| Feature | Available |
|---|---|
| Sessions per week | 3 |
| Overall score | ✅ |
| 6 detail dimensions | ❌ |
| Quick Feedback (Claude) | ✅ |
| Deep Coaching | ❌ |
| Pitch types | "Elevator Pitch" only |
| Custom pitch types | ❌ |
| Streaks | ❌ |
| Leaderboards | ❌ |
| Analytics dashboard | ❌ |
| Session history | Last 3 sessions |
| Heatmap | ❌ |
| Session comparison | ❌ |

### Pro (€20/month or €15/month annually)

| Feature | Available |
|---|---|
| Sessions | Unlimited |
| Overall score | ✅ |
| 6 detail dimensions | ✅ |
| Quick Feedback | ✅ |
| Deep Coaching | ✅ |
| All pitch types | ✅ |
| Custom pitch types | ✅ |
| Streaks | ✅ |
| Global leaderboard | ✅ |
| Analytics dashboard | ✅ |
| Full session history | ✅ |
| Heatmap | ✅ |
| Session comparison | ✅ |
| Streak freeze | Unlimited |

### Team (€100–150/user/month, min. 5 users)

| Feature | Available |
|---|---|
| All Pro features | ✅ |
| Team code & onboarding | ✅ |
| Team leaderboard | ✅ |
| Admin dashboard (aggregated) | ✅ |
| Team challenges | ✅ |
| Priority support | ✅ |

---

## Data Model (CoreData)

### Session

| Field | Type | Description |
|---|---|---|
| id | UUID | Unique session ID |
| date | Date | Timestamp |
| pitchType | String | Pitch type (pre-defined or custom) |
| duration | TimeInterval | Recording duration |
| overallScore | Double | Overall score 0–100 |
| confidenceScore | Double | 0–100 |
| energyScore | Double | 0–100 |
| tempoScore | Double | 0–100 |
| clarityScore | Double | 0–100 |
| stabilityScore | Double | 0–100 |
| persuasivenessScore | Double | 0–100 |
| featureZScores | [String: Double] | Raw Z-scores per OpenSMILE feature |
| transcription | String | On-device transcribed text |
| quickFeedback | String | Claude quick feedback |
| deepCoaching | String? | Claude deep coaching (optional) |
| heatmapData | Data | Scores per time segment (JSON) |

### Baseline

| Field | Type | Description |
|---|---|---|
| feature | String | Feature name |
| ewmaMean | Double | Running EWMA average |
| ewmaVariance | Double | Running EWMA variance |
| sampleCount | Int | Number of measurements |
| lastUpdated | Date | Last update |

### UserProfile

| Field | Type | Description |
|---|---|---|
| name | String | User name |
| language | String | de / en |
| weeklyGoal | Int | 3, 5, or 7 sessions |
| currentStreak | Int | Consecutive weeks |
| firstSessionDate | Date | First session |
| longTermProfile | String? | After 30 sessions |
| teamCode | String? | Team membership (B2B) |
| role | String | consumer / member / admin |

### PitchType

| Field | Type | Description |
|---|---|---|
| id | UUID | Unique ID |
| name | String | Pitch type name |
| description | String | Description |
| timeLimit | Int? | Optional time limit in seconds |
| isCustom | Bool | Pre-defined or custom |
| isDefault | Bool | Pre-installed |

---

## MVP Timeline (4 Weeks)

| Week | Deliverables |
|---|---|
| **Week 1** | Xcode project, AVFoundation pipeline, Apple Speech (en+de), OpenSMILE bridging, feature extraction verified |
| **Week 2** | EWMA engine, 6-dimension mapping, score normalization 0–100, CoreData schema, Claude API + prompt builder |
| **Week 3** | Dashboard UI, recording screen, score display with dimensions, quick feedback, deep coaching, pitch type selection, heatmap calculation |
| **Week 4** | Streaks, leaderboards (global), challenges, analytics graphs (history + radar + comparison + heatmap), onboarding, paywall, TestFlight |

B2B team layer: Week 5–6 (after consumer MVP validated).

---

## Success Metrics

**Technical:** Feature extraction < 500ms. Score calculation < 100ms. Claude quick feedback < 3s. Total latency < 5s.

**Product:** 70% use the app 3x in the first week. 50% retention after 30 days. 8% free-to-pro conversion.

**Qualitative:** Users report measurable improvement after 2 weeks. At least 5 out of 10 test users say: "Nobody has ever given me feedback like this."

**Revenue (12 months):** 500 Consumer Pro + 3 B2B teams = €15k+ MRR.

---

## Explicitly Out of Scope for MVP

- Android version
- Video analysis (gesture, facial expression)
- Live coaching during Zoom/Teams calls
- Gong/Salesforce integration
- Coach role in B2B
- TTS feedback (voice output)
- Offline mode
- Apple Watch companion

---

## Long-term Roadmap

**Phase 1 – Consumer MVP (now):** Core loop, 6 dimensions, gamification, analytics. Start generating revenue.

**Phase 2 – B2B (month 2–3):** Team layer, admin dashboard, team challenges. First enterprise deals.

**Phase 3 – Depth (month 4–8):** Video analysis, Zoom integration, coach role, advanced heatmaps, API for third parties.

**Phase 4 – Platform (year 1–2):** SDK licensing of the voice engine. Training platforms, HR tech, EdTech. The engine becomes infrastructure.

---

*"Your voice. Your score. Your level."*
