import SwiftUI

@main
struct PassengerApp: App {
    init() {
        // TRD §7's cold-open budget starts here — as early in process launch
        // as this type can run code.
        ColdOpenSignpost.begin()
    }

    var body: some Scene {
        WindowGroup {
            MapScreen()
        }
    }
}
