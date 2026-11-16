// Legacy entry points route to the single interactive World Map tab.
import SwiftUI

struct ExploredMapView: View {
    var focus: String?
    @Environment(AppRouter.self) private var router
    var body: some View {
        Color.clear.onAppear { router.present(.exploredMap(focus: focus)) }
    }
}
