#if DEBUG
    import SwiftUI

    struct IOSGalleryView: View {
        @State private var context = GalleryContext()

        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    ForEach(GalleryState.Section.allCases, id: \.self) { section in
                        Section {
                            ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: Spacing.lg) {
                                    ForEach(GalleryState.allCases.filter { $0.section == section }) { state in
                                        GalleryFrame(title: state.title) { state.view(context) }
                                    }
                                }
                                .padding(.horizontal, Spacing.md)
                            }
                        } header: {
                            Text(section.rawValue)
                                .font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                                .padding(Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                        }
                    }
                }
            }
            .background(Theme.background)
            .foregroundStyle(Theme.text)
        }
    }

    struct GalleryFrame<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title).font(.subheadline.weight(.semibold))
                content
                    .frame(width: 390, height: 780)
                    .background(Theme.background)
                    .clipShape(.rect(cornerRadius: 36))
            }
        }
    }

    #Preview("Gallery, dark") {
        IOSGalleryView().preferredColorScheme(.dark)
    }

    #Preview("Gallery, light") {
        IOSGalleryView().preferredColorScheme(.light)
    }

    #Preview("Gallery, large text") {
        IOSGalleryView().dynamicTypeSize(.accessibility3)
    }
#endif
