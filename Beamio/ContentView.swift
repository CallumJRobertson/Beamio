import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        TabView {
            ConnectionGate {
                DashboardView()
            }
            .tabItem {
                Label("Apps", systemImage: "square.grid.2x2.fill")
            }

            ConnectionGate {
                InstallView()
            }
            .tabItem {
                Label("Install", systemImage: "square.and.arrow.down.fill")
            }

            ConnectionGate {
                RemoteView()
            }
            .tabItem {
                Label("Remote", systemImage: "appletvremote.gen1.fill")
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }

            LogView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text.fill")
                }
        }
        .tint(BeamioTheme.accent)
    }
}

#Preview {
    ContentView()
        .environmentObject(ADBManager.shared)
}
