import SwiftUI

struct ConnectionPanel: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("fireTVIP") private var fireTVIP: String = ""

    var body: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Connection")
                            .font(BeamioTheme.subtitleFont(16))
                        Text(adbManager.connectionStatus)
                            .font(BeamioTheme.bodyFont(12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(adbManager.isConnected ? BeamioTheme.success : BeamioTheme.warning)
                        .frame(width: 10, height: 10)
                }

                TextField("192.168.0.21:5555", text: $fireTVIP)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .beamioTextField()

                HStack {
                    Text(BeamioValidator.isValidIP(fireTVIP) ? "Ready to connect" : "Enter a valid IPv4 address")
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(adbManager.isConnected ? "Reconnect" : "Connect") {
                        let keyPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                        let storagePath = keyPath?.path ?? NSTemporaryDirectory()
                        adbManager.connect(ipAddress: fireTVIP, keyStoragePath: storagePath)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!BeamioValidator.isValidIP(fireTVIP))
                }
            }
        }
    }
}

struct ConnectRequiredView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Connect Your Fire TV")
                        .font(BeamioTheme.titleFont(24))
                    Text("Add your device IP to unlock apps, installs, and remote control.")
                        .font(BeamioTheme.bodyFont(14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                ConnectionPanel()
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 40)
        }
    }
}

struct ConnectionGate<Content: View>: View {
    @EnvironmentObject private var adbManager: ADBManager
    let content: () -> Content

    var body: some View {
        if adbManager.isConnected {
            content()
        } else {
            ConnectRequiredView()
        }
    }
}
