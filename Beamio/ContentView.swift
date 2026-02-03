import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ConnectionGate {
                DashboardView()
            }
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }

            ConnectionGate {
                InstallView()
            }
                .tabItem {
                    Label("Install", systemImage: "square.and.arrow.down")
                }

            ConnectionGate {
                RemoteView()
            }
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
