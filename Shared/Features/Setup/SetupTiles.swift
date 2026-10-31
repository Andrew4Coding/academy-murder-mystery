import SwiftUI

struct SetupBento<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            BentoGrid { content }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
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
            DurationPicker(title: title, seconds: $seconds, range: range, showsHours: range.upperBound >= 3600)
        }
    }
}

struct DurationPicker: View {
    let title: String
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>
    var showsHours = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(title).font(.headline)
            HStack(alignment: .center, spacing: Spacing.sm) {
                if showsHours {
                    column("hr", unit: .hours)
                    separator
                }
                column("min", unit: .minutes)
                separator
                column("sec", unit: .seconds)
            }
        }
        .padding(Spacing.lg)
        .presentationCompactAdaptation(.popover)
    }

    private var separator: some View {
        Text(":")
            .font(.system(size: 56, weight: .ultraLight))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, Spacing.lg)
            .accessibilityHidden(true)
    }

    private func column(_ label: String, unit: ClockUnit) -> some View {
        ClockColumn(label: label, unit: unit, seconds: $seconds, range: range)
    }
}

enum ClockUnit {
    case hours
    case minutes
    case seconds

    var modulus: Int {
        self == .hours ? 24 : 60
    }

    func value(of total: Int) -> Int {
        switch self {
        case .hours: total / 3600
        case .minutes: total / 60 % 60
        case .seconds: total % 60
        }
    }

    func offset(_ delta: Int) -> Int {
        switch self {
        case .hours: delta * 3600
        case .minutes: delta * 60
        case .seconds: delta
        }
    }
}

private struct ClockColumn: View {
    let label: String
    let unit: ClockUnit
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>

    @State private var dragSteps = 0
    @AccessibilityFocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize = 64

    private var total: Int {
        Int(seconds)
    }

    private var value: Int {
        unit.value(of: total)
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(label).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Button("Increase \(label)", systemImage: "chevron.up") { step(1) }
            Text(value, format: .number.precision(.integerLength(2...)))
                .font(.system(size: digitSize, weight: .ultraLight))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .frame(minWidth: digitSize * 1.3)
                .gesture(drag)
            Button("Decrease \(label)", systemImage: "chevron.down") { step(-1) }
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .focusable()
        .onKeyPress(.upArrow) { step(1); return .handled }
        .onKeyPress(.downArrow) { step(-1); return .handled }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label == "hr" ? "Hours" : label == "min" ? "Minutes" : "Seconds")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { gesture in
                let steps = Int(-gesture.translation.height / 24)
                if steps != dragSteps {
                    step(steps - dragSteps)
                    dragSteps = steps
                }
            }
            .onEnded { _ in dragSteps = 0 }
    }

    private func step(_ delta: Int) {
        let wrapped = ((value + delta) % unit.modulus + unit.modulus) % unit.modulus
        let next = total + unit.offset(wrapped - value)
        seconds = min(max(TimeInterval(next), range.lowerBound), range.upperBound)
    }
}

struct StepperTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var unit = ""
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
                TextField(title, value: clamped, format: .number)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.text)
                    .fixedSize()
                if !unit.isEmpty {
                    Text(unit).font(.title3).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Stepper(title, value: $value, in: range).labelsHidden()
            }
            Text(title).font(.headline).foregroundStyle(Theme.text)
            Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
    }

    private var clamped: Binding<Int> {
        Binding(get: { value }, set: { value = min(max($0, range.lowerBound), range.upperBound) })
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
