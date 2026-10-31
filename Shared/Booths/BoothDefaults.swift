import Foundation

enum BoothDefaults {
    private static func art(_ name: String) -> BoothImage? {
        Bundle.main.url(forResource: name, withExtension: "jpg")
            .flatMap { try? Data(contentsOf: $0) }
            .map { BoothImage(jpeg: $0) }
    }

    static var booths: [Booth] {
        [decipherClue, towerDanger, recreatePainting, rightPlace, followPattern, messagePassenger, gateUnlock, scaryMemory, heistPlan]
    }

    private static let decipherClue = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000001")!,
        title: "Booth 1 – Decipher Clue",
        capacity: "3 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Decipher the Morse code the OC shows.",
        steps: [
            "The OC shows the Morse code to your family.",
            "Use the Morse cheat sheet available at the booth. The sheet must not leave the booth.",
            "Write your answer on an A4 sheet.",
            "Hand your answer to the OC to be checked.",
            "If it is correct, your family gets a stamp."
        ],
        stampRequirement: "Your answer is correct.",
        image: art("booth-1")
    )

    private static let towerDanger = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000002")!,
        title: "Booth 2 – Tower Danger",
        capacity: "3 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Build a plastic cup tower that matches the photo in the Keynote exactly.",
        steps: [
            "Each family gets 1 set of 20 cups. You don't have to use them all, what "
                + "matters is that the arrangement matches the photo exactly.",
            "You may look at the Keynote while you build.",
            "The whole family can help, and there is no time limit.",
            "When you are done, ask the OC to check your tower.",
            "Once it is approved, stack the cups back like they were. The "
                + "stamp is given after the cups are tidied."
        ],
        stampRequirement: "The OC approves your tower and the cups are tidied up.",
        image: art("booth-2")
    )

    private static let recreatePainting = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000003")!,
        title: "Booth 3 – Recreate Painting",
        capacity: "2 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Recreate the painting shown in the Keynote using sticky notes.",
        steps: [
            "The OC shows the painting in the Keynote to your family.",
            "After that the screen goes back to another slide. You can ask the OC "
                + "to show the Keynote again at any time while you work.",
            "Recreate the painting with the sticky notes provided.",
            "When you are done, ask the OC to check your result.",
            "If it matches, your family gets a stamp."
        ],
        stampRequirement: "Your painting matches.",
        image: art("booth-3")
    )

    private static let rightPlace = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000004")!,
        title: "Booth 4 – The Right Place",
        capacity: "2 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Move the items to the right place in the right order, helped "
            + "by a family member who can see the order.",
        steps: [
            "One member stands outside the box and stays the same person until the task is done. The "
                + "other members are inside, on the side that can see the correct order.",
            "The member outside moves the items one by one. There are 5 items to move in the right order.",
            "The members inside may discuss with each other.",
            "The members inside tell you whether a move is right or wrong only by tone of voice.",
            "The members inside must not give explicit instructions, say the "
                + "name of an item, or point to where an item must go.",
            "When all 5 items are in the right order, your family gets a stamp."
        ],
        stampRequirement: "All 5 items are in the right order.",
        image: art("booth-4")
    )

    private static let followPattern = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000005")!,
        title: "Booth 5 – Follow the Pattern",
        capacity: "2 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Follow the pattern the OC shows correctly up to round 8.",
        steps: [
            "There are 9 items arranged like squares that you have to touch.",
            "Pick one family representative. The same representative does the task until it is finished.",
            "The OC shows the pattern live. The pattern grows by one step each round: round "
                + "1 has 1 step, round 2 has 2 steps, and so on up to round 8.",
            "Repeat the pattern the OC shows by touching the same items in the same order.",
            "If you make a mistake, you have to start again from round 1.",
            "If you complete all 8 rounds, your family gets a stamp."
        ],
        stampRequirement: "You completed 8 rounds.",
        image: art("booth-5")
    )

    private static let messagePassenger = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000006")!,
        title: "Booth 6 – Message Passenger",
        capacity: "3 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Deliver a message to the person the OC names, then get their signature.",
        steps: [
            "Take a sticky note from the OC. The OC decides which people you have to meet.",
            "Write the message on the sticky note.",
            "Find the person the OC named and ask for their signature on the sticky note.",
            "Return to the booth with the signed sticky note.",
            "The OC checks the result. If it is correct, your family gets a stamp."
        ],
        stampRequirement: "The OC confirms your signed sticky note.",
        image: art("booth-6")
    )

    private static let gateUnlock = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000007")!,
        title: "Booth 7 – Gate Unlock",
        capacity: "3 families at a time",
        duration: "No time limit. Work until you are done, then ask the OC to check your result.",
        task: "Separate the metal locks that are linked together.",
        steps: [
            "Each family gets 1 metal lock that is already in the locked position.",
            "Separate the pieces without damaging them.",
            "If you get them apart, your family gets a stamp."
        ],
        stampRequirement: "The metal locks are separated.",
        image: art("booth-7")
    )

    private static let scaryMemory = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000008")!,
        title: "Sabotage Booth 6 – Scary Memory",
        capacity: "As many people as in the photo (set by the committee)",
        duration: "Time limit shown on the AirPlay screen or announced by the committee.",
        task: "Copy the pose in the photo the OC shows to stop the sabotage.",
        steps: [
            "Follow the sabotage information and time limit shown on the "
                + "AirPlay screen or announced by the committee.",
            "Come to the booth. The OC shows the pose photo on a monitor or laptop.",
            "The number of people needed follows the number of people in the photo. "
                + "Anyone can help, from any family, and may join the pose.",
            "Once the pose matches, the documentation team takes a photo. You may take a photo of the result too.",
            "Give a signal to the OC at Town Hall to stop the sabotage."
        ],
        stampRequirement: "You signalled the OC at Town Hall to stop the sabotage.",
        image: art("sabotage-6")
    )

    private static let heistPlan = Booth(
        id: UUID(uuidString: "5A3E0002-0000-4000-8000-000000000009")!,
        title: "Sabotage Booth 7A – Heist Plan",
        capacity: "1 family",
        duration: "Time limit shown on the AirPlay screen or announced by the committee.",
        task: "Get past the string barrier (laser) without touching it.",
        steps: [
            "Follow the sabotage information and time limit shown on the "
                + "AirPlay screen or announced by the committee.",
            "Pick one member to get past the string barrier. Try not to move the string.",
            "When you reach the end, write your family name on the whiteboard, then go back through the barrier.",
            "If you touch the string, swap in another member and start over. There is no limit on attempts.",
            "Once your family name is on the whiteboard and the participants are back, "
                + "give a signal to the OC at Town Hall to stop the sabotage."
        ],
        stampRequirement: "You signalled the OC at Town Hall to stop the sabotage.",
        image: art("sabotage-7a")
    )
}
