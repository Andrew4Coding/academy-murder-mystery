import AudioToolbox
import SwiftUI

struct SabotageBanner: View {
    let sabotage: SabotageView
    let client: GameClient

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
        .background(.red, in: .rect(cornerRadius: 16))
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
