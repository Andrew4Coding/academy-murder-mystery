import SwiftUI

struct StatusLabel: View {
    let text: String
    let systemImage: String
    let tint: Color

    init(_ text: String, systemImage: String, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
    }
}

extension StatusLabel {
    static func error(_ message: String) -> StatusLabel {
        StatusLabel(message, systemImage: "exclamationmark.triangle.fill", tint: .red)
    }
}
