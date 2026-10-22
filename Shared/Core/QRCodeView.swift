import CoreImage.CIFilterBuiltins
import SwiftUI

enum QRCodeGenerator {
    static func image(for text: String, scale: CGFloat = 10) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = QRCodeGenerator.image(for: text) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
                .background(.white)
                .accessibilityElement()
                .accessibilityLabel("QR code for family code \(text)")
        }
    }
}
