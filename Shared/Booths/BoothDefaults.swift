import Foundation

enum BoothDefaults {
    static let stampNote = "Everyone who finishes the round gets a stamp on their hand."

    static var booths: [Booth] {
        [tarot, pumpkin, copyTheArtist, movie]
    }

    private static let tarot = Booth(
        id: UUID(uuidString: "5A3E0001-0000-4000-8000-000000000001")!,
        title: "Tarot Reading",
        location: "Cave area, Lab 1",
        capacity: "About 3 learners at a time, depending on the number of readers",
        duration: "Up to 10 minutes per person, aim for about 5",
        task: "Join a tarot reading session with a reader.",
        steps: [
            "Write your name on the waiting list paper at the booth.",
            "Wait for your turn. The committee will message you on Zoom chat when it is your turn, so keep an eye on Zoom.",
            "When you are called, come to the booth right away. If you don't, the committee moves on to the next learner.",
            "A session lasts 10 minutes at most per person. We aim for about 5 minutes so everyone gets a turn.",
            "After the session you get a stamp on your hand."
        ],
        stampRequirement: "You finished a tarot reading.",
        staffNotes: ["Remind learners on the waiting list to watch the Zoom chat."]
    )

    private static let pumpkin = Booth(
        id: UUID(uuidString: "5A3E0001-0000-4000-8000-000000000002")!,
        title: "Pumpkin Pipe Cleaner Challenge",
        location: "Lab 1",
        capacity: "10 learners per session",
        duration: "About 15 minutes per session",
        task: "Make a mini pumpkin or Halloween creation from pipe cleaners, in the theme the committee announces.",
        steps: [
            "Come to the booth and join the next session. The committee gathers about 10 learners per session.",
            "The committee explains the rules and announces the theme for the session.",
            "You have 5 minutes to build your pumpkin from the pipe cleaners provided.",
            "When time is up, present your work. A mentor judges uniqueness, creativity and how well it fits the theme.",
            "Every learner who finishes the round gets a stamp on their hand. The winner gets a prize.",
            "You can take your pumpkin home."
        ],
        stampRequirement: "You finished the pumpkin making round."
    )

    private static let copyTheArtist = Booth(
        id: UUID(uuidString: "5A3E0001-0000-4000-8000-000000000003")!,
        title: "Copy the Artist",
        location: "Lab 1",
        capacity: "7 learners per session",
        duration: "About 10 minutes per session, one round per session",
        task: "Look at the example drawing, then redraw it from memory as closely as you can.",
        steps: [
            "Come to the booth and join the next session.",
            "A spin wheel sets the round level. Time to look at the example: Easy 30 seconds, Medium 20 seconds, Hard 10 seconds.",
            "Study the example drawing while it is shown.",
            "Once the drawing is hidden, you have 2 minutes to draw what you saw on an A4 sheet.",
            "A mentor judges how closely your drawing matches the example. The winner gets a prize.",
            "Every learner who finishes the round gets a stamp on their hand."
        ],
        stampRequirement: "You finished 1 drawing round.",
        staffNotes: ["The spin wheel must be made by the committee before the event starts."]
    )

    private static let movie = Booth(
        id: UUID(uuidString: "5A3E0001-0000-4000-8000-000000000004")!,
        title: "Movie",
        location: "Lab 1, on the AirPlay TV screen near the pantry (Booth 4 on the map)",
        capacity: "About 30 learners who have not yet been stamped for Movie at a time",
        duration: "At least 10 minutes of watching, no sessions or rounds",
        task: "Watch the film Coco for at least 10 minutes.",
        steps: [
            "Take a note sheet from the committee.",
            "Write down the time you start watching.",
            "Write down the time you stop watching. You can leave and come back at any time.",
            "Once you have watched at least 10 minutes, show your sheet to the committee to get a stamp on your hand.",
            "If the booth is full, join another booth first."
        ],
        stampRequirement: "You watched at least 10 minutes.",
        staffNotes: [
            "Remind learners that booth order is free and they must join at least 1 booth. "
                + "Stamped learners may return to the same booth without being stamped again.",
            "Movie booth: remind learners to fill in their start and end times honestly. "
                + "Times already written must not be erased and rewritten.",
            "Tarot Reading booth: remind learners on the waiting list to watch the Zoom chat."
        ]
    )
}
