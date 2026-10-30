#if DEBUG
    import SwiftUI

    struct PadGalleryView: View {
        private let entries = PadScreens.all

        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(entry.title)
                                .font(.title3.bold())
                                .foregroundStyle(Theme.text)
                            entry.screen
                                .frame(height: 720)
                                .background(Theme.background)
                                .clipShape(.rect(cornerRadius: Radius.lg))
                                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Theme.separator, lineWidth: 1))
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Theme.background)
        }
    }

    #Preview("iPad admin gallery, dark", traits: .landscapeLeft) {
        PadGalleryView().preferredColorScheme(.dark)
    }

    #Preview("iPad admin gallery, light", traits: .landscapeLeft) {
        PadGalleryView().preferredColorScheme(.light)
    }
#endif
