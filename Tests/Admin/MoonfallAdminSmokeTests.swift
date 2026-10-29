import Foundation
import Testing

struct MoonfallAdminSmokeTests {
    @Test func hostAppHasExpectedBundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "com.andrew4coding.Moonfall.admin")
    }
}
