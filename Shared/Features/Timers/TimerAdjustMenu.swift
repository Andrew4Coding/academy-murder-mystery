import SwiftUI

struct TimerAdjustMenu: View {
    struct Entry: Identifiable {
        let target: TimerTarget
        let title: String
        let isEnabled: Bool

        var id: TimerTarget {
            target
        }
    }

    let entries: [Entry]
    let onAdjust: (TimerTarget, TimeInterval) -> Void

    @State private var customizing: Entry?

    private static let presets: [TimeInterval] = [30, 60, 300]

    init(meeting: Bool, gameClock: Bool, sabotage: Bool, onAdjust: @escaping (TimerTarget, TimeInterval) -> Void) {
        entries = [
            Entry(target: .meeting, title: "Meeting Timer", isEnabled: meeting),
            Entry(target: .finalVote, title: "Game Clock", isEnabled: gameClock),
            Entry(target: .sabotage, title: "Sabotage Timer", isEnabled: sabotage)
        ]
        self.onAdjust = onAdjust
    }

    var body: some View {
        Menu {
            ForEach(entries) { entry in
                Menu(entry.title) {
                    Section("Add time") {
                        ForEach(Self.presets, id: \.self) { seconds in
                            Button("+\(Self.label(seconds))") { onAdjust(entry.target, seconds) }
                                .accessibilityLabel("Add \(Self.spoken(seconds)) to \(entry.title)")
                        }
                    }
                    Section("Remove time") {
                        ForEach(Self.presets, id: \.self) { seconds in
                            Button("\u{2212}\(Self.label(seconds))") { onAdjust(entry.target, -seconds) }
                                .accessibilityLabel("Remove \(Self.spoken(seconds)) from \(entry.title)")
                        }
                    }
                    Button("Custom\u{2026}") { customizing = entry }
                }
                .disabled(!entry.isEnabled)
            }
        } label: {
            BentoTile(title: "Timers", subtitle: "Add or remove time", systemImage: "clock", tint: .indigo)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(!entries.contains { $0.isEnabled })
        .sheet(item: $customizing) { entry in
            CustomTimerSheet(title: entry.title) { onAdjust(entry.target, $0) }
        }
    }

    static func label(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        seconds >= 60 ? "\(Int(seconds / 60)) minutes" : "\(Int(seconds)) seconds"
    }
}

private struct CustomTimerSheet: View {
    let title: String
    let onApply: (TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 1
    @State private var seconds = 0

    private var delta: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0 ... 60)
                Stepper("Seconds: \(seconds)", value: $seconds, in: 0 ... 55, step: 5)
                Section {
                    Button("Add \(TimerAdjustMenu.label(delta))", systemImage: "plus.circle") { apply(delta) }
                    Button("Remove \(TimerAdjustMenu.label(delta))", systemImage: "minus.circle", role: .destructive) { apply(-delta) }
                }
                .disabled(delta == 0)
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 280)
        .presentationDetents([.medium])
    }

    private func apply(_ value: TimeInterval) {
        onApply(value)
        dismiss()
    }
}
