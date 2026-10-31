import SwiftUI

enum TimerAction {
    case pause
    case resume
    case adjust(TimeInterval)
}

extension GameCommand {
    init(_ action: TimerAction, on target: TimerTarget) {
        switch action {
        case .pause: self = .pauseTimer(target)
        case .resume: self = .resumeTimer(target)
        case let .adjust(seconds): self = .adjustTimer(target, seconds: seconds)
        }
    }
}

extension AdminCommand {
    init(_ action: TimerAction, on target: TimerTarget) {
        switch action {
        case .pause: self = .pauseTimer(target)
        case .resume: self = .resumeTimer(target)
        case let .adjust(seconds): self = .adjustTimer(target, seconds: seconds)
        }
    }
}

struct TimerControls: View {
    let title: String
    let isPaused: Bool
    let onAction: (TimerAction) -> Void

    @State private var customizing = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                onAction(isPaused ? .resume : .pause)
            }
            .accessibilityLabel("\(isPaused ? "Resume" : "Pause") \(title)")
            Button("1:00", systemImage: "minus") { onAction(.adjust(-60)) }
                .accessibilityLabel("Shorten \(title) by 1 minute")
            Button("1:00", systemImage: "plus") { onAction(.adjust(60)) }
                .accessibilityLabel("Add 1 minute to \(title)")
            Menu("More", systemImage: "ellipsis") {
                Button("+0:30") { onAction(.adjust(30)) }
                Button("\u{2212}0:30") { onAction(.adjust(-30)) }
                Button("+5:00") { onAction(.adjust(300)) }
                Button("\u{2212}5:00") { onAction(.adjust(-300)) }
                Button("Custom\u{2026}") { customizing = true }
            }
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .sheet(isPresented: $customizing) {
            CustomTimerSheet(title: title) { onAction(.adjust($0)) }
        }
    }

    static func label(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
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
                    Button("Add \(TimerControls.label(delta))", systemImage: "plus.circle") { apply(delta) }
                    Button("Remove \(TimerControls.label(delta))", systemImage: "minus.circle", role: .destructive) { apply(-delta) }
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
