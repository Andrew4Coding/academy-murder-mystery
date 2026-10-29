import Foundation
import Testing

struct MurderMysteryAdminSmokeTests {
    @Test func hostAppHasExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.andrew4coding.MurderMystery.admin")
    }
}

