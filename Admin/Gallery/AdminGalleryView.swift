#if DEBUG
    import SwiftUI

    struct AdminGalleryLaunch: View {
        var body: some View {
            let entries = AdminScreens.all
            let index = UserDefaults.standard.string(forKey: "AdminGallery").flatMap(Int.init) ?? -1
            Group {
                if entries.indices.contains(index) {
                    entries[index].screen
                        .frame(width: 1100, height: 760)
                        .background(Theme.background)
                } else {
                    AdminGalleryView()
                }
            }
            .task { await PublicDisplayWindowCapture.captureIfRequested() }
        }
    }

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
