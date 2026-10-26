import Foundation

/// Rehearsal-only switches (relaxed start rules, chosen roles, scenario buttons in Admin).
/// They exist only in Debug builds and only when the app is launched with `-TestingTools`, which the
/// `MurderMysteryAdmin-Testing` scheme does. Release builds and the normal schemes never see them.
enum TestingTools {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-TestingTools")
        #else
        false
        #endif
    }
}
