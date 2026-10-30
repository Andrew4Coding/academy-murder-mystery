#if DEBUG
    import SwiftUI

    struct PublicDisplayGalleryEntry: Identifiable {
        let title: String
        let display: PublicDisplayState
        var id: String {
            title
        }
    }

    enum PublicDisplayGallery {
        static let entries: [PublicDisplayGalleryEntry] = {
            typealias Fixtures = DisplayFixtures
            let deaths = ["Moreau", "Okafor"]
            var list = [
                PublicDisplayGalleryEntry(title: "Host offline", display: F.hostOffline),
                PublicDisplayGalleryEntry(title: "Waiting, empty", display: F.waitingEmpty),
                PublicDisplayGalleryEntry(title: "Waiting, many families", display: F.waitingMany),
                PublicDisplayGalleryEntry(title: "Waiting, overflow", display: F.waitingOverflow),
                PublicDisplayGalleryEntry(title: "Starting", display: F.starting)
            ]
            for alarm in [false, true] {
                let suffix = alarm ? ", alarm" : ""
                list += [
                    PublicDisplayGalleryEntry(title: "Playing\(suffix)", display: F.playing(alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Playing, final seconds\(suffix)", display: F.playing(alarm: alarm, seconds: 6)),
                    PublicDisplayGalleryEntry(title: "Discussion, no deaths\(suffix)", display: F.discussion(deaths: [], alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Discussion, deaths\(suffix)", display: F.discussion(deaths: deaths, alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Voting\(suffix)", display: F.voting(alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Result, voted out\(suffix)", display: F.resultExpelled(alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Result, nobody out\(suffix)", display: F.resultNobody(alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Villagers win\(suffix)", display: F.villagersWin(alarm: alarm)),
                    PublicDisplayGalleryEntry(title: "Werewolves reveal\(suffix)", display: F.werewolvesReveal(alarm: alarm))
                ]
            }
            list.append(PublicDisplayGalleryEntry(title: "Werewolves reveal, 24 families", display: F.werewolvesReveal(families: 24)))
            return list
        }()
    }

    struct PublicDisplayGalleryView: View {
        var body: some View {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 480), spacing: 24)], spacing: 24) {
                    ForEach(PublicDisplayGallery.entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.title).font(.headline)
                            PublicDisplayScreen(display: entry.display, now: DisplayFixtures.now, playsSound: false)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private struct GalleryFrame: View {
        let display: PublicDisplayState
        var size = CGSize(width: 1920, height: 1080)

        var body: some View {
            PublicDisplayScreen(display: display, now: DisplayFixtures.now, playsSound: false)
                .frame(width: size.width, height: size.height)
        }
    }

    private let hd720 = CGSize(width: 1280, height: 720)

    #Preview("Gallery") { PublicDisplayGalleryView().frame(width: 1600, height: 900) }
    #Preview("Host offline") { GalleryFrame(display: DisplayFixtures.hostOffline) }
    #Preview("Waiting, empty") { GalleryFrame(display: DisplayFixtures.waitingEmpty) }
    #Preview("Waiting, many") { GalleryFrame(display: DisplayFixtures.waitingMany) }
    #Preview("Waiting, many 720p") { GalleryFrame(display: DisplayFixtures.waitingMany, size: hd720) }
    #Preview("Starting") { GalleryFrame(display: DisplayFixtures.starting) }
    #Preview("Playing") { GalleryFrame(display: DisplayFixtures.playing()) }
    #Preview("Playing, alarm") { GalleryFrame(display: DisplayFixtures.playing(alarm: true)) }
    #Preview("Playing, final seconds") { GalleryFrame(display: DisplayFixtures.playing(seconds: 6)) }
    #Preview("Discussion, no deaths") { GalleryFrame(display: DisplayFixtures.discussion(deaths: [])) }
    #Preview("Discussion, deaths") { GalleryFrame(display: DisplayFixtures.discussion(deaths: ["Moreau", "Okafor"])) }
    #Preview("Discussion, deaths, alarm") { GalleryFrame(display: DisplayFixtures.discussion(deaths: ["Moreau", "Okafor"], alarm: true)) }
    #Preview("Discussion 720p") { GalleryFrame(display: DisplayFixtures.discussion(deaths: ["Moreau"]), size: hd720) }
    #Preview("Voting") { GalleryFrame(display: DisplayFixtures.voting()) }
    #Preview("Voting, final, alarm") { GalleryFrame(display: DisplayFixtures.voting(isFinal: true, alarm: true)) }
    #Preview("Result, voted out") { GalleryFrame(display: DisplayFixtures.resultExpelled()) }
    #Preview("Result, voted out, alarm") { GalleryFrame(display: DisplayFixtures.resultExpelled(alarm: true)) }
    #Preview("Result, nobody out") { GalleryFrame(display: DisplayFixtures.resultNobody()) }
    #Preview("Villagers win") { GalleryFrame(display: DisplayFixtures.villagersWin()) }
    #Preview("Villagers win, alarm") { GalleryFrame(display: DisplayFixtures.villagersWin(alarm: true)) }
    #Preview("Werewolves reveal") { GalleryFrame(display: DisplayFixtures.werewolvesReveal()) }
    #Preview("Werewolves reveal, alarm") { GalleryFrame(display: DisplayFixtures.werewolvesReveal(alarm: true)) }
    #Preview("Werewolves reveal 720p") { GalleryFrame(display: DisplayFixtures.werewolvesReveal(families: 24), size: hd720) }
#endif
