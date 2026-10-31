import SwiftUI

struct BoothsTab: View {
    let client: GameClient

    var body: some View {
        BoothsView(
            booths: client.booths.booths,
            actions: BoothActions(
                save: { client.send(.admin(.saveBooth($0))) },
                delete: { client.send(.admin(.deleteBooth($0))) },
                reorder: { client.send(.admin(.reorderBooths($0))) },
                setImage: { client.send(.admin(.setBoothImage($0, $1))) },
                removeImage: { client.send(.admin(.removeBoothImage($0))) },
                restoreDefaults: { client.send(.admin(.restoreBoothDefaults)) }
            )
        )
    }
}
