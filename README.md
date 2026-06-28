# Caldwell Corner Fantasy Football — iOS App

A native **SwiftUI** iOS application generated from the *Caldwell Corner Fantasy Football* Product Requirements Document (PRD v1.0) and the accompanying execution plan. It is the "ultimate fantasy football operating system" — combining AI insights, advanced analytics, league management, dynasty tools, draft prep, and betting edges into one app.

> The PRD targets a Flutter cross-platform build for production. This deliverable is a **native iOS (SwiftUI) implementation** of the product, with a fully navigable UI and realistic in-memory mock data standing in for the backend / sports-data / OpenAI pipelines described in the PRD.

## Requirements

- **Xcode 16** or later (the project uses file-system-synchronized groups)
- **iOS 17.0+** deployment target
- iPhone or iPad simulator / device

## Getting Started

```bash
open CaldwellCorner.xcodeproj
```

Select the **CaldwellCorner** scheme and an iOS 17+ simulator, then press **Run** (⌘R). No third-party dependencies or package resolution are required — it builds out of the box.

## Implemented Features

Mapped to the PRD's 19 core features:

| Area | Screen | PRD Ref |
|---|---|---|
| Home dashboard | `DashboardView` | Team/League Dashboards (§15/16) |
| Player Database | `PlayerDatabaseView` + `PlayerDetailView` | §4 (advanced metrics: snap %, target share, YPRR, EPA, RAS, breakout age, college dominator…) |
| Rankings | `RankingsView` | §5 (PPR / Half / Standard / Dynasty / Superflex, by position) |
| AI Fantasy Assistant | `AIAssistantView` + `AIAssistant` | §2 (RAG-style, grounded in the player DB, free-tier usage gating) |
| Trade Analyzer | `TradeAnalyzerView` + `TradeEngine` | §3 (Trade Grade, Fairness, Win-Now, Future, Risk + AI explanation) |
| AI Projections | shown in `PlayerDetailView` | §6 (weekly/season/ROS, ceiling/floor, breakout/regression/bust %) |
| Draft Center | `DraftCenterView` | §7 (mock draft, live timer, AI draft coach, tier board) |
| Draft Guide | `DraftGuideView` | §8 (articles, sleepers/busts/tiers, PDF CTA) |
| Dynasty Hub | `DynastyHubView` | §9 (rookie rankings, pick values, age curves) |
| Waiver Assistant | `WaiverView` | §10 (FAAB recommendations, priority) |
| Start/Sit | `StartSitView` | §11 (confidence %, matchup, Vegas, weather) |
| Injury Center | `InjuryCenterView` | §12 (status, practice report, replacements) |
| News Center | `NewsCenterView` + `NewsDetailView` | §13 (AI impact summaries, stock up/down) |
| Betting Center | `BettingCenterView` | §14 (props, EV, AI picks, geofencing note) |
| League Sync | `LeagueSyncView` | §1 (Sleeper, ESPN, Yahoo, NFL, CBS, Fleaflicker, MFL) |
| League Dashboard | `LeagueDashboardView` | §15/16 (roster, standings, power, playoff/title odds) |
| Premium Content | `PremiumContentView` | §17 (film, video, livestreams, Discord) |
| Notifications | `NotificationsView` | §18 |
| User Profile | `ProfileView` | §19 (achievements, lifetime stats, watchlist) |
| Subscription / Paywall | `PaywallView` | Subscription Model (Free vs Premium, IAP framing) |

Free vs. Premium gating is implemented throughout (AI message limits, locked advanced metrics, dynasty/betting/draft-guide gating) and can be toggled live via the paywall.

## Backend data system

A Node.js + TypeScript backend lives in [`backend/`](backend/). It ingests **trusted** data only — the **Sleeper public API** and **nflverse / nflfastR-style datasets** (no arbitrary web scraping) — normalizes it into a `PlayerMetrics` model (target share, air yards, routes run, snap share, red-zone usage, EPA team context, matchup difficulty, injury status, projected points, regression/breakout/confidence scores), stores it in **PostgreSQL** (with an in-memory fallback for dev/CI), and serves an AI `RecommendationEngine` for **start/sit, trade, waiver, and draft** decisions — each with a score, confidence rating, and plain-English reasoning.

```bash
cd backend && npm install && npm run dev   # http://localhost:8080
npm test                                   # engine + normalizer unit tests
```

The iOS app talks to it through `CaldwellCorner/Services/BackendClient.swift` (+ the mirrored `PlayerMetrics` model). See [`backend/README.md`](backend/README.md) for full details.

## Project Structure

```
CaldwellCorner/
├── CaldwellCornerApp.swift      # @main entry point
├── RootView.swift               # TabView navigation + paywall sheet
├── Theme/                       # Design system (colors, spacing, reusable components)
├── Models/                      # Player, League, Team, Trade, Content, Subscription
├── Data/                        # MockPlayers, MockData, AppState (observable store)
├── Services/                    # AIAssistant (rule-based RAG), TradeEngine
└── Features/                    # One folder per feature area (see table above)
```

## Architecture Notes

- **State**: a single `@MainActor` `AppState: ObservableObject` acts as the in-memory repository, standing in for the PostgreSQL/Redis backend, Firebase Auth, and billing layers from the PRD tech stack.
- **AI**: `AIAssistant` is a deterministic, rule-based responder grounded exclusively in the local player database — mirroring the PRD's "ground the AI via RAG, no hallucinated stats" mitigation. Swap it for an OpenAI-backed service to go live.
- **Trade engine**: `TradeEngine` produces explainable grades from player value, age, win-now vs. future weighting, and league context (scoring, dynasty, Superflex).
- **Design**: dark, broadcast-inspired theme with an electric-green accent and position-coded color system.

## Replacing Mock Data with a Live Backend

Each `MockData.build*()` source and the `AIAssistant`/`TradeEngine` services are intentionally isolated so they can be replaced with API-backed implementations (sports data provider, OpenAI, league-sync integrations) without touching the SwiftUI views.
