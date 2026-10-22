import Foundation
import Testing

struct MurderMysteryiOSSmokeTests {
    @Test func hostAppHasExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.andrew4coding.MurderMystery")
    }
}
