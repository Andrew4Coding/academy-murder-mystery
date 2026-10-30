import SwiftUI

enum DisplayPalette {
    static let base = Color(red: 14 / 255, green: 8 / 255, blue: 16 / 255)
    static let card = Color(red: 28 / 255, green: 18 / 255, blue: 32 / 255)
    static let primary = Color.white
    static let secondary = Color(red: 214 / 255, green: 206 / 255, blue: 218 / 255)
    static let redText = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)
    static let redFill = Color(red: 179 / 255, green: 16 / 255, blue: 28 / 255)
    static let redBright = Color(red: 229 / 255, green: 56 / 255, blue: 59 / 255)
    static let grey = Color(red: 158 / 255, green: 150 / 255, blue: 164 / 255)

    static func cardFill(reduceTransparency: Bool) -> Color {
        reduceTransparency ? card : Color.white.opacity(0.07)
    }
}

extension PublicDisplayLayout {
    static let canvas = CGSize(width: 1920, height: 1080)
    static let safeInsetX: CGFloat = 96
    static let safeInsetY: CGFloat = 54
    static let urgentSeconds: TimeInterval = 10
    static let ringSeconds: TimeInterval = 60
    static let maxRosterTiles = 24
}

extension Font {
    static func stage(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        Font.system(size: size, weight: weight, design: .default).width(.condensed)
    }

    static func stageRounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func stageDigits(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}
