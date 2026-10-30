import Foundation
import Observation

@MainActor @Observable
final class SimulationController {
    enum Speed: Double, CaseIterable, Identifiable {
        case paused = 0
        case normal = 1
        case fast = 5
        case faster = 20
        case fastest = 60

        var id: Double {
            rawValue
        }

        var title: String {
            self == .paused ? "Paused" : "\(Int(rawValue))x"
        }
    }

    private(set) var simulation: Simulation?
    private(set) var errorMessage: String?
    var speed: Speed = .fast

    @ObservationIgnored private var runner: Task<Void, Never>?
    @ObservationIgnored private var carry: TimeInterval = 0

    var isActive: Bool {
        simulation != nil
    }

    func start(_ config: Simulation.Config) {
        stop()
        do {
            simulation = try Simulation(config: config)
            errorMessage = nil
            runner = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    self?.tick(real: 0.1)
                }
            }
        } catch let error as HostError {
            errorMessage = error.message
        } catch {
            errorMessage = "\(error)"
        }
    }

    func stop() {
        runner?.cancel()
        runner = nil
        carry = 0
    }

    func discard() {
        stop()
        simulation = nil
    }

    func runToEnd() {
        simulation?.runToCompletion()
    }

    func tick(real: TimeInterval) {
        guard let simulation, speed != .paused, !simulation.isFinished else { return }
        carry += Simulation.virtualSeconds(real: real, speed: speed.rawValue)
        while carry >= 1, !simulation.isFinished {
            simulation.step(by: 1)
            carry -= 1
        }
    }
}

enum SimulationLog {
    static func lines(for events: [GameEvent], names: [FamilyID: String], limit: Int = 60) -> [String] {
        events.suffix(limit).reversed().compactMap { describe($0, names: names) }
    }

    static func describe(_ event: GameEvent, names: [FamilyID: String]) -> String? {
        func name(_ id: FamilyID) -> String {
            names[id] ?? id.description
        }
        let minutes = Int(event.at.timeIntervalSince(Simulation.epoch)) / 60
        let seconds = Int(event.at.timeIntervalSince(Simulation.epoch)) % 60
        let stamp = String(format: "%02d:%02d", minutes, seconds)
        let text: String? = switch event.kind {
        case .gameStarted: "Game started"
        case let .familyKilled(victim, by: killer):
            killer.map { "\(name($0)) eliminated \(name(victim))" } ?? "\(name(victim)) was eliminated by the organiser"
        case let .sabotageStarted(kind, by, _): "\(name(by)) started a \(kind.title) sabotage"
        case .sabotageResolved: "Sabotage resolved"
        case .sabotageExpired: "Sabotage ran out of time"
        case let .meetingStarted(dead): dead.isEmpty ? "Meeting started" : "Meeting started, \(dead.count) eliminated"
        case let .votingOpened(isFinal): isFinal ? "Final vote opened" : "Voting opened"
        case .voteCast: nil
        case let .voteClosed(_, expelled, _):
            expelled.isEmpty ? "Vote closed, nobody voted out" : "Vote closed: \(expelled.map { name($0.family) }.joined(separator: ", ")) voted out"
        case .ocOverride: "Organiser override"
        case let .gameEnded(outcome): "\(outcome.winner == .villagers ? "Villagers" : "Werewolves") win: \(outcome.reason.explanation)"
        }
        return text.map { "\(stamp)  \($0)" }
    }
}
