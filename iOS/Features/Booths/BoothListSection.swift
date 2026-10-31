import SwiftUI

struct BoothListSection: View {
    let booths: [Booth]
    var title: LocalizedStringKey = "Booths"
    var footer: LocalizedStringKey?

    @State private var selected: Selection?

    private struct Selection: Identifiable {
        let booth: Booth
        let number: Int
        var id: UUID {
            booth.id
        }
    }

    var body: some View {
        if !booths.isEmpty {
            ScreenSection(title: title, footer: footer) {
                ForEach(Array(booths.enumerated()), id: \.element.id) { index, booth in
                    if index > 0 {
                        Divider().overlay(Theme.separator)
                    }
                    Button {
                        selected = Selection(booth: booth, number: index + 1)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Booth \(index + 1): \(booth.title)")
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
            .sheet(item: $selected) { selection in
                BoothDetailView(booth: selection.booth, number: selection.number) { selected = nil }
                    .presentationDetents([.large])
            }
            .onChange(of: booths) { _, updated in
                guard let current = selected else { return }
                if let index = updated.firstIndex(where: { $0.id == current.booth.id }) {
                    selected = Selection(booth: updated[index], number: index + 1)
                } else {
                    selected = nil
                }
            }
        }
    }
}
