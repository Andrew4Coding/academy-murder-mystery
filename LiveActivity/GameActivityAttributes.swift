import ActivityKit
import Foundation

struct GameActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Kind: String, Codable, Hashable {
            case lobby
            case playing
            case discussion
            case voting
            case sabotage
            case killed
            case over
        }

        var kind: Kind
        var title: String
        var detail: String
        var endsAt: Date?
    }

    var familyName: String
}
