import SwiftUI

@main
struct ArgusApp: App {
    var body: some Scene {
        WindowGroup("Argus") {
            DashboardView()
        }
        .defaultSize(width: 1180, height: 760)
    }
}
