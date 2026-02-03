import SwiftUI

@main
struct BeamioApp: App {
    @StateObject private var pythonManager = PythonManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pythonManager)
        }
    }
}
