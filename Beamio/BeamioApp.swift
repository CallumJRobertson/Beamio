import SwiftUI

@main
struct BeamioApp: App {
    @StateObject private var adbManager = ADBManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(adbManager)
        }
    }
}
