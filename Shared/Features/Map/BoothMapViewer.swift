import SwiftUI

struct BoothMapViewer: View {
    let map: BoothMap
    let onClose: () -> Void

    static let maxZoom: CGFloat = 6
    static let step: CGFloat = 1.5

    @State private var image: CGImage?
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size
            let fit = fitSize(in: container)
            let scale = Self.clamp(zoom * pinch)
            let position = limit(
                CGSize(width: offset.width + drag.width, height: offset.height + drag.height),
                scale: scale, container: container, fit: fit
            )
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: container.width, height: container.height)
                        .scaleEffect(scale)
                        .offset(position)
                        .gesture(panGesture.simultaneously(with: zoomGesture(container: container, fit: fit)))
                        .onTapGesture(count: 2) { toggleZoom(container: container, fit: fit) }
                        .accessibilityLabel("Booth map")
                        .accessibilityHint("Pinch to zoom, double tap to reset")
                        .accessibilityAddTraits(.isImage)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .overlay(alignment: .topTrailing) { closeButton }
            .overlay(alignment: .bottom) { controls(container: container, fit: fit) }
        }
        .task(id: map.hash) { image = BoothMapImporter.decode(map.jpeg, maxPixelSize: 4096) }
    }

    private var closeButton: some View {
        Button("Close", systemImage: "xmark", action: onClose)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(Spacing.md)
    }

    private func controls(container: CGSize, fit: CGSize) -> some View {
        GlassEffectContainer {
            HStack(spacing: Spacing.sm) {
                Button("Zoom out", systemImage: "minus") { setZoom(zoom / Self.step, container: container, fit: fit) }
                    .disabled(zoom <= 1)
                Button("Reset", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                    setZoom(1, container: container, fit: fit)
                }
                .disabled(zoom <= 1)
                Button("Zoom in", systemImage: "plus") { setZoom(zoom * Self.step, container: container, fit: fit) }
                    .disabled(zoom >= Self.maxZoom)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(Spacing.md)
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onEnded { value in
                offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
            }
    }

    private func zoomGesture(container: CGSize, fit: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                setZoom(zoom * value.magnification, container: container, fit: fit, animated: false)
            }
    }

    private func toggleZoom(container: CGSize, fit: CGSize) {
        setZoom(zoom > 1 ? 1 : 3, container: container, fit: fit)
    }

    private func setZoom(_ value: CGFloat, container: CGSize, fit: CGSize, animated: Bool = true) {
        let apply = {
            zoom = Self.clamp(value)
            offset = limit(offset, scale: zoom, container: container, fit: fit)
        }
        if animated, !reduceMotion {
            withAnimation(.snappy, apply)
        } else {
            apply()
        }
    }

    private func fitSize(in container: CGSize) -> CGSize {
        guard let image, image.height > 0 else { return container }
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        let width = min(container.width, container.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    private func limit(_ value: CGSize, scale: CGFloat, container: CGSize, fit: CGSize) -> CGSize {
        let maxX = max(0, (fit.width * scale - container.width) / 2)
        let maxY = max(0, (fit.height * scale - container.height) / 2)
        return CGSize(width: min(max(value.width, -maxX), maxX), height: min(max(value.height, -maxY), maxY))
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), maxZoom)
    }
}
