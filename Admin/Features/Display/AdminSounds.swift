import AVFoundation

@MainActor
final class AdminSound {
    private let player: AVAudioPlayer?

    init(_ name: String, fallback: String? = nil, loops: Bool = false) {
        let url = Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? fallback.flatMap { Bundle.main.url(forResource: $0, withExtension: "mp3") }
        player = url.flatMap { try? AVAudioPlayer(contentsOf: $0) }
        player?.numberOfLoops = loops ? -1 : 0
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        player?.stop()
    }
}
