import AudioToolbox
import SwiftUI

struct SabotageBanner: View {
    let sabotage: SabotageView
    let client: GameClient

    private static let alertTint = Color(red: 0.66, green: 0.1, blue: 0.1)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
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
        .padding()
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(Self.alertTint), in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .onAppear { AudioServicesPlayAlertSound(SystemSoundID(1005)) }
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}
