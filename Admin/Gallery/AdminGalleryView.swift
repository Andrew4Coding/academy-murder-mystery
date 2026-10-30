#if DEBUG
import SwiftUI

struct AdminGalleryView: View {
    private let entries = AdminScreens.all

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(entry.title)
                            .font(.title3.bold())
                            .foregroundStyle(Theme.text)
                        entry.screen
                            .frame(width: 960, height: 640)
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

#Preview("Mac admin gallery, dark") {
    AdminGalleryView()
        .frame(width: 1040, height: 800)
        .preferredColorScheme(.dark)
}

#Preview("Mac admin gallery, light") {
    AdminGalleryView()
        .frame(width: 1040, height: 800)
        .preferredColorScheme(.light)
}
#endif
