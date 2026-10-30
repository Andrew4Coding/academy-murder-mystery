import AudioToolbox
import SwiftUI

struct SabotageBanner: View {
    let sabotage: SabotageView
    let client: GameClient
    var playsAlert = true

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text("Sabotage! Go to \(sabotage.kind.title)")
                    .font(.headline)
                Text("Fix it before the time runs out.")
                    .font(.subheadline)
            }
            Spacer()
            CountdownView(until: sabotage.endsAt, now: serverNow)
                .font(.title2.bold())
        }
        .padding(Spacing.md)
        .foregroundStyle(Theme.onAccentFill)
        .background(Theme.accentFill, in: .rect(cornerRadius: Radius.lg))
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            if playsAlert {
                AudioServicesPlayAlertSound(SystemSoundID(1005))
            }
        }
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}
