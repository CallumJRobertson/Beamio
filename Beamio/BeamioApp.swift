import SwiftUI

@main
struct BeamioApp: App {
    @StateObject private var pythonManager = PythonManager.shared

    init() {
        pythonManager.initializeIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pythonManager)
        }
    }
}
