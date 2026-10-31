import SwiftUI

struct BoothListSection: View {
    let booths: [Booth]
    var title: LocalizedStringKey = "Booths"
    var footer: LocalizedStringKey?

    @State private var selected: Booth?

    var body: some View {
        if !booths.isEmpty {
            ScreenSection(title: title, footer: footer) {
                ForEach(booths) { booth in
                    if booth.id != booths.first?.id {
                        Divider().overlay(Theme.separator)
                    }
                    Button {
                        selected = booth
                    } label: {
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(booth.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                                if !booth.task.isEmpty {
                                    Text(booth.task).secondaryText().multilineTextAlignment(.leading)
                                }
                            }
                            Spacer(minLength: Spacing.sm)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the booth details")
                }
            }
            .sheet(item: $selected) { booth in
                BoothDetailView(booth: booth) { selected = nil }
                    .presentationDetents([.large])
            }
            .onChange(of: booths) { _, updated in
                guard let current = selected else { return }
                selected = updated.first { $0.id == current.id }
            }
        }
    }
}
