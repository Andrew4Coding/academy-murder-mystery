import Foundation
import Testing

struct MoonfalliOSSmokeTests {
    @Test func hostAppHasExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.andrew4coding.Moonfall")
    }
}
