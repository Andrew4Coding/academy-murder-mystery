import SwiftUI

struct SetupBento<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            BentoGrid { content }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            Text(title).font(.headline).foregroundStyle(Theme.text)
            Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
    }
}

struct DurationTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var seconds: TimeInterval
    var range: ClosedRange<TimeInterval> = 15 ... 600
    var secondsStep = 15

    @State private var isEditing = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isEditing = true } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Spacer(minLength: Spacing.sm)
                Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text(title).font(.headline).foregroundStyle(Theme.text)
                Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(Spacing.md)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
            .opacity(isEnabled ? 1 : 0.7)
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(CountdownView.spoken(seconds))
        .accessibilityHint("Opens a time picker")
        .popover(isPresented: $isEditing) {
            DurationPicker(title: title, seconds: $seconds, range: range, secondsStep: secondsStep)
        }
    }
}

struct DurationPicker: View {
    let title: String
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>
    let secondsStep: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title).font(.headline)
            Stepper("Minutes: \(minutes)", value: minutesBinding, in: Int(range.lowerBound / 60) ... Int(range.upperBound / 60))
            Stepper("Seconds: \(remainder)", value: secondsBinding, in: 0 ... 60 - secondsStep, step: secondsStep)
            Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .frame(maxWidth: .infinity)
        }
        .padding(Spacing.lg)
        .frame(minWidth: 280)
        .presentationCompactAdaptation(.popover)
    }

    private var minutes: Int {
        Int(seconds) / 60
    }

    private var remainder: Int {
        Int(seconds) % 60
    }

    private var minutesBinding: Binding<Int> {
        Binding(get: { minutes }, set: { set(minutes: $0, seconds: remainder) })
    }

    private var secondsBinding: Binding<Int> {
        Binding(get: { remainder }, set: { set(minutes: minutes, seconds: $0) })
    }

    private func set(minutes: Int, seconds newSeconds: Int) {
        let value = TimeInterval(minutes * 60 + newSeconds)
        seconds = min(max(value, range.lowerBound), range.upperBound)
    }
}

struct StepperTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let valueText: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.sm)
            HStack(alignment: .firstTextBaseline) {
                Text(valueText)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                Spacer()
                Stepper(title, value: $value, in: range).labelsHidden()
            }
            Text(title).font(.headline).foregroundStyle(Theme.text)
            Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

struct ToggleTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isOn ? Theme.onAccentFill : Theme.accent)
                    .accessibilityHidden(true)
                Spacer(minLength: Spacing.sm)
                Text(isOn ? "On" : "Off")
                    .font(.largeTitle.bold())
                    .foregroundStyle(isOn ? Theme.onAccentFill : Theme.text)
                Text(title).font(.headline).foregroundStyle(isOn ? Theme.onAccentFill : Theme.text)
                Text(subtitle).font(.footnote).foregroundStyle(isOn ? Theme.onAccentFill : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(Spacing.md)
            .background(isOn ? Theme.accentFill : Theme.surface, in: .rect(cornerRadius: Radius.lg))
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
