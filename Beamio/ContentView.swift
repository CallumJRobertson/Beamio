import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            LogView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ADBManager.shared)
}
