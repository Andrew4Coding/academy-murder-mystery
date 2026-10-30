import Foundation
import Testing

struct ThemeContrastTests {
    private struct Pair {
        let name: String
        let foreground: UInt32
        let background: UInt32
        let minimum: Double
    }

    private static let dark: [Pair] = [
        Pair(name: "text on background", foreground: 0xF7F0F2, background: 0x0E0810, minimum: 4.5),
        Pair(name: "text on raised surface", foreground: 0xF7F0F2, background: 0x2A1D27, minimum: 4.5),
        Pair(name: "secondary text on surface", foreground: 0xCDBFC6, background: 0x1A1118, minimum: 4.5),
        Pair(name: "accent on background", foreground: 0xFF4D5A, background: 0x0E0810, minimum: 4.5),
        Pair(name: "accent on raised surface", foreground: 0xFF4D5A, background: 0x2A1D27, minimum: 4.5),
        Pair(name: "white on accent fill", foreground: 0xFFFFFF, background: 0xC8102E, minimum: 4.5),
        Pair(name: "success on surface", foreground: 0x4ADE80, background: 0x1A1118, minimum: 4.5),
        Pair(name: "warning on surface", foreground: 0xFFB84D, background: 0x1A1118, minimum: 4.5),
    ]

    private static let light: [Pair] = [
        Pair(name: "text on background", foreground: 0x1A0E12, background: 0xFAF5F5, minimum: 4.5),
        Pair(name: "secondary text on surface", foreground: 0x5A4A51, background: 0xFFFFFF, minimum: 4.5),
        Pair(name: "accent on background", foreground: 0xB3121F, background: 0xFAF5F5, minimum: 4.5),
        Pair(name: "white on accent fill", foreground: 0xFFFFFF, background: 0xB3121F, minimum: 4.5),
        Pair(name: "success on surface", foreground: 0x15803D, background: 0xFFFFFF, minimum: 4.5),
        Pair(name: "warning on surface", foreground: 0x92400E, background: 0xFFFFFF, minimum: 4.5),
    ]

    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private static func ratio(_ pair: Pair) -> Double {
        let first = luminance(pair.foreground)
        let second = luminance(pair.background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    @Test(arguments: dark)
    private func darkPaletteMeetsContrast(pair: Pair) {
        #expect(Self.ratio(pair) >= pair.minimum, "\(pair.name)")
    }

    @Test(arguments: light)
    private func lightPaletteMeetsContrast(pair: Pair) {
        #expect(Self.ratio(pair) >= pair.minimum, "\(pair.name)")
    }
}
