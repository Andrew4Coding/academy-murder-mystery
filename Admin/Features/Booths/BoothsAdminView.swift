import SwiftUI

struct BoothsAdminView: View {
    let controller: HostController

    @State private var errorMessage: String?

    private var host: GameHost {
        controller.host
    }

    var body: some View {
        BoothsView(booths: host.boothCatalog.booths, actions: actions)
            .alert("Can't do that", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var actions: BoothActions {
        BoothActions(
            save: { booth in attempt { try host.saveBooth(booth) } },
            delete: { id in attempt { try host.deleteBooth(id) } },
            reorder: { ids in attempt { try host.reorderBooths(ids) } },
            setImage: { id, data in attempt { try host.setBoothImage(id, imageData: data) } },
            removeImage: { id in attempt { try host.removeBoothImage(id) } },
            restoreDefaults: { attempt { try host.restoreBoothDefaults() } }
        )
    }

    private func attempt(_ action: () throws -> Void) {
        do { try action() } catch let error as HostError { errorMessage = error.message } catch { errorMessage = "\(error)" }
    }
}
