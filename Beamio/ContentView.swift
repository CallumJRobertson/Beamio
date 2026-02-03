import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            InstallView()
                .tabItem {
                    Label("Install", systemImage: "square.and.arrow.down")
                }

            RemoteView()
                .tabItem {
                    Label("Remote", systemImage: "appletvremote.gen1")
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
