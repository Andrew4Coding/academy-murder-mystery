import SwiftUI

struct TimerAdjustMenu: View {
    let title: String
    let systemImage: String
    let onAdjust: (TimeInterval) -> Void

    @State private var isCustomizing = false

    private static let presets: [TimeInterval] = [30, 60, 300]

    var body: some View {
        Menu(title, systemImage: systemImage) {
            Section("Add time") {
                ForEach(Self.presets, id: \.self) { seconds in
                    Button("+\(Self.label(seconds))") { onAdjust(seconds) }
                        .accessibilityLabel("Add \(Self.spoken(seconds)) to \(title)")
                }
            }
            Section("Remove time") {
                ForEach(Self.presets, id: \.self) { seconds in
                    Button("\u{2212}\(Self.label(seconds))") { onAdjust(-seconds) }
                        .accessibilityLabel("Remove \(Self.spoken(seconds)) from \(title)")
                }
            }
            Button("Custom\u{2026}") { isCustomizing = true }
        }
        .sheet(isPresented: $isCustomizing) {
            CustomTimerSheet(title: title) { onAdjust($0) }
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
