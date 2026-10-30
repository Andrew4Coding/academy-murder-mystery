#if DEBUG
    import Foundation

    enum DisplayFixtures {
        static let now = Date(timeIntervalSince1970: 1_800_000_000)

        static let names = [
            "Moreau", "Hartley", "Okafor", "Lindqvist", "Tanaka", "Delgado", "Novak", "Brennan",
            "Castellan", "Ivanova", "Whitlock", "Duarte", "Sorensen", "Achterberg", "Kowalski", "Mbeki",
            "Fairweather", "Nakamura", "Oyelaran", "Petrov", "Quillfeather", "Rosenthal", "Santiago", "Thackeray",
            "Underhill", "Vasquez", "Wolfenden", "Xanthos"
        ]
        static let players = [
            "Ada", "Ben", "Chika", "Dmitri", "Emi", "Felipe", "Greta", "Hamza",
            "Ines", "Jonas", "Keiko", "Luca", "Mira", "Noor", "Omar", "Priya",
            "Quinn", "Rosa", "Sven", "Tariq", "Uma", "Viktor", "Wen", "Xavier",
            "Yara", "Zane", "Alma", "Bruno"
        ]

        static func lobbyFamilies(_ count: Int) -> [LobbyFamily] {
            (0 ..< count).map { index in
                LobbyFamily(
                    id: FamilyID(index + 1),
                    name: names[index % names.count],
                    player: index % 7 == 6 ? nil : players[index % players.count]
                )
            }
        }

        static func revealed(_ count: Int, werewolves: Set<Int>) -> [RevealedFamily] {
            (0 ..< count).map { index in
                RevealedFamily(
                    id: FamilyID(index + 1),
                    name: names[index % names.count],
                    player: players[index % players.count],
                    selfie: nil,
                    isWerewolf: werewolves.contains(index)
                )
            }
        }

        static let alarm = PublicDisplayState.Alarm(kind: .reactor, endsAt: now.addingTimeInterval(74))

        static func state(
            _ screen: PublicDisplayState.Screen,
            remaining: Int? = 8,
            deaths: [String] = [],
            code: String? = nil,
            lobby: [LobbyFamily] = [],
            reveal: [RevealedFamily] = [],
            alarm: Bool = false
        ) -> PublicDisplayState {
            PublicDisplayState(
                screen: screen,
                familiesRemaining: remaining,
                alarm: alarm ? Self.alarm : nil,
                announcedDeaths: deaths,
                joinCode: code,
                lobbyFamilies: lobby,
                reveal: reveal
            )
        }

        static let hostOffline = state(.hostOffline, remaining: nil)
        static let waitingEmpty = state(.waiting, remaining: nil, code: "K7M2QX")
        static let waitingMany = state(.waiting, remaining: nil, code: "K7M2QX", lobby: lobbyFamilies(24))
        static let waitingOverflow = state(.waiting, remaining: nil, code: "K7M2QX", lobby: lobbyFamilies(28))
        static let starting = state(.starting(at: now.addingTimeInterval(8)), remaining: nil)
        static func playing(alarm: Bool = false, seconds: TimeInterval = 1420) -> PublicDisplayState {
            state(.playing(gameEndsAt: now.addingTimeInterval(seconds)), alarm: alarm)
        }

        static func discussion(deaths: [String], alarm: Bool = false, seconds: TimeInterval = 94) -> PublicDisplayState {
            state(.discussion(until: now.addingTimeInterval(seconds)), deaths: deaths, alarm: alarm)
        }

        static func voting(isFinal: Bool = false, alarm: Bool = false) -> PublicDisplayState {
            state(.voting(until: now.addingTimeInterval(47), isFinal: isFinal, cast: 5, total: 8), alarm: alarm)
        }

        static let rows = [
            ResultRow(name: "Hartley", count: 4, isSkip: false),
            ResultRow(name: "Okafor", count: 2, isSkip: false),
            ResultRow(name: "Lindqvist", count: 1, isSkip: false),
            ResultRow(name: "Skip", count: 1, isSkip: true)
        ]

        static func resultExpelled(alarm: Bool = false) -> PublicDisplayState {
            state(.result(VoteResultView(rows: rows, expelled: [ExpelledView(name: "Hartley")], isFinal: false)), alarm: alarm)
        }

        static func resultNobody(alarm: Bool = false) -> PublicDisplayState {
            state(
                .result(VoteResultView(
                    rows: [ResultRow(name: "Skip", count: 5, isSkip: true), ResultRow(name: "Moreau", count: 2, isSkip: false)],
                    expelled: [],
                    isFinal: true
                )),
                alarm: alarm
            )
        }

        static func villagersWin(alarm: Bool = false) -> PublicDisplayState {
            state(.ended(Outcome(winner: .villagers, reason: .allWerewolvesRemoved)), remaining: 6, alarm: alarm)
        }

        static func werewolvesReveal(alarm: Bool = false, families: Int = 12) -> PublicDisplayState {
            state(
                .ended(Outcome(winner: .werewolves, reason: .parity)),
                remaining: 4,
                reveal: revealed(families, werewolves: [1, 5, 8]),
                alarm: alarm
            )
        }
    }
#endif
