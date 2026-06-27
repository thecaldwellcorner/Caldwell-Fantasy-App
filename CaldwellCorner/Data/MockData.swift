import Foundation

/// Aggregated mock content for the entire app.
enum MockData {

    // MARK: - Leagues
    static func buildLeagues() -> [League] {
        let players = MockPlayers.all
        func id(_ name: String) -> UUID {
            players.first(where: { $0.name == name })?.id ?? UUID()
        }

        // User roster for the dynasty league
        let userRoster: [RosterSlot] = [
            .init(playerID: id("Josh Allen"), slot: "QB"),
            .init(playerID: id("Bijan Robinson"), slot: "RB"),
            .init(playerID: id("Jahmyr Gibbs"), slot: "RB"),
            .init(playerID: id("Ja'Marr Chase"), slot: "WR"),
            .init(playerID: id("Malik Nabers"), slot: "WR"),
            .init(playerID: id("Brock Bowers"), slot: "TE"),
            .init(playerID: id("De'Von Achane"), slot: "FLEX"),
            .init(playerID: id("Caleb Williams"), slot: "BENCH"),
            .init(playerID: id("Rome Odunze"), slot: "BENCH"),
            .init(playerID: id("Jonathon Brooks"), slot: "TAXI"),
            .init(playerID: id("Cooper Kupp"), slot: "IR"),
        ]

        let userTeam = FantasyTeam(
            name: "Corner Office", ownerName: "You", wins: 4, losses: 2,
            pointsFor: 812.4, pointsAgainst: 740.1, powerScore: 88, playoffOdds: 76,
            championshipOdds: 18, dynastyValue: 91, isUser: true, roster: userRoster,
            futurePicks: ["2026 1st", "2026 2nd", "2027 1st", "2027 3rd"])

        let opponents: [FantasyTeam] = [
            .init(name: "Gridiron Goblins", ownerName: "Marcus", wins: 5, losses: 1, pointsFor: 845.0, pointsAgainst: 720.0, powerScore: 92, playoffOdds: 88, championshipOdds: 24, dynastyValue: 94),
            .init(name: "Dynasty Destroyers", ownerName: "Priya", wins: 5, losses: 1, pointsFor: 820.5, pointsAgainst: 710.0, powerScore: 90, playoffOdds: 84, championshipOdds: 20, dynastyValue: 89),
            .init(name: "Waiver Wire Warriors", ownerName: "Tyler", wins: 3, losses: 3, pointsFor: 770.0, pointsAgainst: 765.0, powerScore: 74, playoffOdds: 52, championshipOdds: 9, dynastyValue: 76),
            .init(name: "The Tank Commanders", ownerName: "Sam", wins: 3, losses: 3, pointsFor: 760.2, pointsAgainst: 772.0, powerScore: 70, playoffOdds: 48, championshipOdds: 7, dynastyValue: 82),
            .init(name: "Couch Potatoes", ownerName: "Jordan", wins: 2, losses: 4, pointsFor: 712.0, pointsAgainst: 790.0, powerScore: 58, playoffOdds: 24, championshipOdds: 3, dynastyValue: 65),
            .init(name: "Hail Mary Inc.", ownerName: "Alex", wins: 2, losses: 4, pointsFor: 705.5, pointsAgainst: 800.0, powerScore: 55, playoffOdds: 20, championshipOdds: 2, dynastyValue: 70),
            .init(name: "Bye Week Bandits", ownerName: "Casey", wins: 1, losses: 5, pointsFor: 680.0, pointsAgainst: 815.0, powerScore: 44, playoffOdds: 8, championshipOdds: 1, dynastyValue: 60),
            .init(name: "Comeback Kids", ownerName: "Morgan", wins: 1, losses: 5, pointsFor: 675.0, pointsAgainst: 820.0, powerScore: 42, playoffOdds: 6, championshipOdds: 1, dynastyValue: 58),
        ]

        let dynasty = League(
            name: "Caldwell Corner Dynasty", platform: .sleeper, scoring: .ppr,
            type: .dynasty, teamCount: 12, isSuperflex: true,
            teams: [userTeam] + opponents, currentWeek: 7)

        let redraft = League(
            name: "Office League '25", platform: .espn, scoring: .halfPPR,
            type: .redraft, teamCount: 10, isSuperflex: false,
            teams: [
                FantasyTeam(name: "Corner Office", ownerName: "You", wins: 3, losses: 3, pointsFor: 690.0, pointsAgainst: 700.0, powerScore: 72, playoffOdds: 55, championshipOdds: 11, dynastyValue: 0, isUser: true, roster: Array(userRoster.prefix(9))),
                FantasyTeam(name: "Touchdown Tornados", ownerName: "Riley", wins: 5, losses: 1, pointsFor: 760.0, pointsAgainst: 660.0, powerScore: 86, playoffOdds: 80, championshipOdds: 22, dynastyValue: 0),
                FantasyTeam(name: "End Zone Elites", ownerName: "Drew", wins: 4, losses: 2, pointsFor: 730.0, pointsAgainst: 690.0, powerScore: 78, playoffOdds: 66, championshipOdds: 14, dynastyValue: 0),
                FantasyTeam(name: "Fumble Fits", ownerName: "Jamie", wins: 2, losses: 4, pointsFor: 670.0, pointsAgainst: 720.0, powerScore: 60, playoffOdds: 32, championshipOdds: 5, dynastyValue: 0),
            ], currentWeek: 7)

        return [dynasty, redraft]
    }

    // MARK: - News
    static func buildNews() -> [NewsItem] {
        let now = Date()
        return [
            NewsItem(headline: "Christian McCaffrey returns to full practice, on track for Sunday",
                     source: "Caldwell Corner", timestamp: now.addingTimeInterval(-1800),
                     playerName: "Christian McCaffrey", position: .rb,
                     aiSummary: "CMC was a full participant Wednesday and is trending toward a normal workload. Lock him in as an elite RB1 with no usage restrictions expected.",
                     fantasyImpact: "Stock Up", isBreaking: true),
            NewsItem(headline: "Nico Collins (hamstring) limited, status for Week 7 uncertain",
                     source: "Beat Writer", timestamp: now.addingTimeInterval(-5400),
                     playerName: "Nico Collins", position: .wr,
                     aiSummary: "Monitor practice reports closely. If he sits, Tank Dell and Stefon Diggs absorb a target spike — both become strong streamers.",
                     fantasyImpact: "Stock Down"),
            NewsItem(headline: "Jayden Daniels posts third straight 25+ point fantasy outing",
                     source: "Caldwell Corner", timestamp: now.addingTimeInterval(-9000),
                     playerName: "Jayden Daniels", position: .qb,
                     aiSummary: "The rookie's rushing floor has him as a weekly top-5 QB. Buy-window in dynasty is closing fast as the market catches up.",
                     fantasyImpact: "Stock Up"),
            NewsItem(headline: "Bijan Robinson sees season-high 26 touches in Atlanta win",
                     source: "Team Site", timestamp: now.addingTimeInterval(-14400),
                     playerName: "Bijan Robinson", position: .rb,
                     aiSummary: "The committee concerns are officially over. Bijan is an every-down workhorse and a set-and-forget RB1 the rest of the way.",
                     fantasyImpact: "Stock Up"),
            NewsItem(headline: "Cooper Kupp (ankle) placed on IR, eligible to return Week 11",
                     source: "Insider", timestamp: now.addingTimeInterval(-21600),
                     playerName: "Cooper Kupp", position: .wr,
                     aiSummary: "Puka Nacua's target share climbs to elite levels with Kupp out. Stash Kupp if you have IR space; his dynasty value continues to slide.",
                     fantasyImpact: "Stock Down"),
            NewsItem(headline: "Brock Bowers breaks rookie TE target-share record",
                     source: "Caldwell Corner", timestamp: now.addingTimeInterval(-28800),
                     playerName: "Brock Bowers", position: .te,
                     aiSummary: "Bowers is a positional cheat code. Treat him as a top-3 dynasty TE and a weekly must-start regardless of matchup.",
                     fantasyImpact: "Stock Up"),
        ]
    }

    // MARK: - Injuries
    static func buildInjuries() -> [InjuryReport] {
        [
            InjuryReport(playerName: "Nico Collins", position: .wr, team: "HOU", status: .questionable, injury: "Hamstring", practiceReport: "Limited", expectedReturn: "Week 7 (GTD)", fantasyImpact: "Boom/bust if active; consider a pivot if you have depth.", replacementSuggestion: "Tank Dell, Jordan Addison"),
            InjuryReport(playerName: "Jonathon Brooks", position: .rb, team: "CAR", status: .questionable, injury: "Knee (recovery)", practiceReport: "DNP", expectedReturn: "Week 9", fantasyImpact: "Dynasty stash; not startable until role clarifies.", replacementSuggestion: "Chuba Hubbard"),
            InjuryReport(playerName: "Cooper Kupp", position: .wr, team: "LAR", status: .ir, injury: "High ankle sprain", practiceReport: "DNP", expectedReturn: "Week 11", fantasyImpact: "Out multiple weeks; Puka sees elite volume.", replacementSuggestion: "Puka Nacua, Demarcus Robinson"),
            InjuryReport(playerName: "Christian McCaffrey", position: .rb, team: "SF", status: .healthy, injury: "Achilles (managed)", practiceReport: "Full", expectedReturn: "Active", fantasyImpact: "Cleared for full workload; elite RB1.", replacementSuggestion: "—"),
        ]
    }

    // MARK: - Waivers
    static func buildWaivers() -> [WaiverTarget] {
        [
            WaiverTarget(playerName: "Tank Dell", position: .wr, team: "HOU", rosteredPct: 58, faabBidPct: 22, priority: 1, reason: "Elevated to clear WR1 role if Nico Collins sits. Big-play upside in a high-volume passing attack.", isPremium: false),
            WaiverTarget(playerName: "Tyjae Spears", position: .rb, team: "TEN", rosteredPct: 44, faabBidPct: 15, priority: 2, reason: "Pass-down work plus standalone value; one injury from a true RB1 workload.", isPremium: false),
            WaiverTarget(playerName: "Jaylen Wright", position: .rb, team: "MIA", rosteredPct: 31, faabBidPct: 12, priority: 3, reason: "Explosive handcuff with weekly flex appeal in Miami's scheme.", isPremium: true),
            WaiverTarget(playerName: "Cedric Tillman", position: .wr, team: "CLE", rosteredPct: 22, faabBidPct: 8, priority: 4, reason: "Trending target share spike; deeper-league dart throw.", isPremium: true),
            WaiverTarget(playerName: "Cade Otton", position: .te, team: "TB", rosteredPct: 40, faabBidPct: 6, priority: 5, reason: "Streamable TE with a plus matchup and reliable red-zone looks.", isPremium: true),
        ]
    }

    // MARK: - Start/Sit
    static func buildStartSit() -> [StartSitAdvice] {
        [
            StartSitAdvice(playerName: "De'Von Achane", position: .rb, team: "MIA", opponent: "vs ARI", recommendation: "Start", confidence: 88, projection: 17.4, matchupGrade: "A-", vegasTotal: 49.5, weather: "Dome", reasoning: "Elite implied team total and a soft run funnel. Achane's receiving role provides a safe PPR floor with massive ceiling."),
            StartSitAdvice(playerName: "Garrett Wilson", position: .wr, team: "NYJ", opponent: "@ PIT", recommendation: "Flex", confidence: 62, projection: 13.1, matchupGrade: "C", vegasTotal: 39.0, weather: "Wind 14mph", reasoning: "Tough corner matchup and a low game total cap the ceiling, but target volume keeps him in the flex conversation."),
            StartSitAdvice(playerName: "Travis Etienne", position: .rb, team: "JAX", opponent: "vs NE", recommendation: "Sit", confidence: 55, projection: 9.8, matchupGrade: "D+", vegasTotal: 41.0, weather: "Clear", reasoning: "Committee usage and a touchdown-dependent profile make him a risky play against a stout run front."),
            StartSitAdvice(playerName: "Trey McBride", position: .te, team: "ARI", opponent: "@ MIA", recommendation: "Start", confidence: 84, projection: 13.6, matchupGrade: "B+", vegasTotal: 49.5, weather: "Dome", reasoning: "Massive target share in a likely shootout. Locked-in TE1 with a high floor."),
        ]
    }

    // MARK: - Betting
    static func buildBetting() -> [BettingProp] {
        [
            BettingProp(playerName: "Ja'Marr Chase", position: .wr, market: "Receiving Yards", line: 88.5, overOdds: -110, underOdds: -110, aiPick: "Over", expectedValue: 7.2, confidence: 71, sportsbook: "DraftKings"),
            BettingProp(playerName: "Bijan Robinson", position: .rb, market: "Rush + Rec Yards", line: 112.5, overOdds: -115, underOdds: -105, aiPick: "Over", expectedValue: 5.8, confidence: 66, sportsbook: "FanDuel"),
            BettingProp(playerName: "Josh Allen", position: .qb, market: "Passing TDs", line: 1.5, overOdds: -130, underOdds: +105, aiPick: "Over", expectedValue: 9.1, confidence: 74, sportsbook: "BetMGM"),
            BettingProp(playerName: "Travis Etienne", position: .rb, market: "Anytime TD", line: 0.5, overOdds: +120, underOdds: -150, aiPick: "Under", expectedValue: 4.0, confidence: 58, sportsbook: "Caesars"),
            BettingProp(playerName: "Sam LaPorta", position: .te, market: "Receptions", line: 4.5, overOdds: -120, underOdds: -100, aiPick: "Over", expectedValue: 6.5, confidence: 64, sportsbook: "DraftKings"),
        ]
    }

    // MARK: - Draft Guide
    static func buildDraftGuide() -> [DraftGuideArticle] {
        [
            DraftGuideArticle(title: "10 League-Winning Sleepers for 2025", category: "Sleepers", author: "Carson Caldwell", readMinutes: 9, body: "Every championship roster has a late-round hit that returns 3x its draft cost. This year's board is loaded with ascending talent in undervalued situations. Our model flags target-share trends, snap counts and offensive line continuity to surface the names most likely to smash their ADP...\n\n1. A high-upside backfield reshuffle in the NFC.\n2. A second-year breakout WR with an elite route grade.\n3. A pass-catching back going outside the top 100.\n\nFade the recency bias and trust the process."),
            DraftGuideArticle(title: "Busts to Avoid at Their Current ADP", category: "Busts", author: "Carson Caldwell", readMinutes: 7, body: "Volume is the engine of fantasy production, and several popular picks are quietly losing it. We grade each player's projected opportunity against their cost and isolate the names with the widest gap between perception and reality."),
            DraftGuideArticle(title: "Positional Tiers: Where the Cliffs Are", category: "Strategy", author: "Caldwell Corner Staff", readMinutes: 12, body: "Tier-based drafting beats raw rankings every time. We break each position into clearly defined value tiers so you always know when to reach and when to wait."),
            DraftGuideArticle(title: "Auction Values & Nomination Strategy", category: "Strategy", author: "Caldwell Corner Staff", readMinutes: 8, body: "Master the auction format with our full price sheet plus nomination tactics to drain your opponents' budgets early."),
            DraftGuideArticle(title: "Breakout Age Model: 2025 WR Class", category: "Breakouts", author: "Data Team", readMinutes: 10, body: "Our breakout-age and college-dominator model has a strong hit rate for projecting third-year leaps. Here are the receivers primed to explode."),
        ]
    }

    // MARK: - Dynasty: rookies & pick values
    static func buildRookies() -> [RookieProspect] {
        [
            RookieProspect(name: "Travis Hunter", position: .wr, college: "Colorado", rookieRank: 1, projectedDraftCapital: "Top-5 lock", dynastyValue: 96, comp: "Two-way unicorn; elite ball skills"),
            RookieProspect(name: "Ashton Jeanty", position: .rb, college: "Boise State", rookieRank: 2, projectedDraftCapital: "Round 1", dynastyValue: 94, comp: "Bell-cow three-down profile"),
            RookieProspect(name: "Tetairoa McMillan", position: .wr, college: "Arizona", rookieRank: 3, projectedDraftCapital: "Round 1", dynastyValue: 90, comp: "Big-bodied X receiver"),
            RookieProspect(name: "Luther Burden III", position: .wr, college: "Missouri", rookieRank: 4, projectedDraftCapital: "Round 1-2", dynastyValue: 86, comp: "YAC slot weapon"),
            RookieProspect(name: "Omarion Hampton", position: .rb, college: "North Carolina", rookieRank: 5, projectedDraftCapital: "Round 2", dynastyValue: 82, comp: "Powerful early-down runner"),
        ]
    }

    static func buildPickValues() -> [DraftPickValue] {
        [
            .init(label: "2026 1st (Early)", value: 78),
            .init(label: "2026 1st (Mid)", value: 64),
            .init(label: "2026 1st (Late)", value: 52),
            .init(label: "2026 2nd (Early)", value: 38),
            .init(label: "2026 2nd (Late)", value: 26),
            .init(label: "2026 3rd", value: 14),
            .init(label: "2027 1st", value: 58),
            .init(label: "2027 2nd", value: 30),
        ]
    }

    // MARK: - Premium content
    static func buildPremiumContent() -> [PremiumContent] {
        let now = Date()
        return [
            PremiumContent(title: "Week 7 Start/Sit Livestream", type: "Livestream", author: "Carson Caldwell", publishedAt: now.addingTimeInterval(-3600), summary: "Live Q&A breaking down every tough lineup call before Sunday's slate."),
            PremiumContent(title: "Film Room: Why Bijan is RB1 ROS", type: "Film", author: "Caldwell Corner Film", publishedAt: now.addingTimeInterval(-86400), summary: "All-22 breakdown of Atlanta's expanded usage and what it means going forward."),
            PremiumContent(title: "Dynasty Buy-Low Targets After Week 6", type: "Article", author: "Carson Caldwell", publishedAt: now.addingTimeInterval(-172800), summary: "Five names whose value cratered for the wrong reasons — buy now."),
            PremiumContent(title: "The Caldwell Corner Podcast: Trade Deadline Prep", type: "Video", author: "The Caldwell Corner", publishedAt: now.addingTimeInterval(-259200), summary: "Contender vs. rebuild frameworks and the exact players to target."),
        ]
    }

    // MARK: - Profile & subscription
    static func buildProfile() -> UserProfile {
        UserProfile(displayName: "Corner GM", handle: "@cornergm", favoriteTeam: "Detroit Lions",
                    memberSince: "2024", lifetimeLeagues: 14, championships: 3, tier: .free)
    }

    static func buildPlans() -> [PlanOption] {
        [
            PlanOption(title: "Monthly", price: "$9.99", period: "/month",
                       perks: ["Unlimited AI Assistant", "Advanced projections", "Dynasty + betting tools", "No ads"],
                       badge: nil, isFeatured: false),
            PlanOption(title: "Annual", price: "$59.99", period: "/year",
                       perks: ["Everything in Monthly", "2025 Draft Guide included", "Premium Discord access", "Exclusive film & content"],
                       badge: "BEST VALUE · SAVE 50%", isFeatured: true),
        ]
    }

    static func buildAchievements() -> [Achievement] {
        [
            Achievement(title: "League Champion", detail: "Won a league title", systemImage: "trophy.fill", unlocked: true),
            Achievement(title: "Trade Shark", detail: "Completed 25 trades", systemImage: "arrow.left.arrow.right.circle.fill", unlocked: true),
            Achievement(title: "Waiver Wizard", detail: "Hit on 10 waiver claims", systemImage: "wand.and.stars", unlocked: true),
            Achievement(title: "Draft Day Hero", detail: "Drafted 3 league-winners", systemImage: "star.circle.fill", unlocked: false),
            Achievement(title: "Dynasty Architect", detail: "Build a top dynasty roster", systemImage: "building.columns.fill", unlocked: false),
            Achievement(title: "Perfect Lineup", detail: "Set an optimal lineup", systemImage: "checkmark.seal.fill", unlocked: false),
        ]
    }

    static func suggestedPrompts() -> [SuggestedPrompt] {
        [
            .init(text: "Should I trade Garrett Wilson for Drake London?", systemImage: "arrow.left.arrow.right"),
            .init(text: "What WR should I start this week?", systemImage: "person.fill.questionmark"),
            .init(text: "Who should I claim off waivers?", systemImage: "hand.raised.fill"),
            .init(text: "How should I approach my rebuild?", systemImage: "hammer.fill"),
        ]
    }
}
