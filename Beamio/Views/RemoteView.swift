import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Remote Control")
                    .font(.title2)
                    .fontWeight(.semibold)

                dpadSection
                actionSection
            }
            .padding()
            .navigationTitle("Remote")
        }
    }

    private var dpadSection: some View {
        VStack(spacing: 12) {
            Button {
                adbManager.sendKeyEvent(19)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.title2)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 24) {
                Button {
                    adbManager.sendKeyEvent(21)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .buttonStyle(.bordered)

                Button {
                    adbManager.sendKeyEvent(23)
                } label: {
                    Text("OK")
                        .fontWeight(.semibold)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    adbManager.sendKeyEvent(22)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
            }

            Button {
                adbManager.sendKeyEvent(20)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Back") { adbManager.sendKeyEvent(4) }
                    .buttonStyle(.bordered)
                Button("Home") { adbManager.sendKeyEvent(3) }
                    .buttonStyle(.bordered)
                Button("Menu") { adbManager.sendKeyEvent(82) }
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 16) {
                Button("Play/Pause") { adbManager.sendKeyEvent(85) }
                    .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    RemoteView()
        .environmentObject(ADBManager.shared)
}
