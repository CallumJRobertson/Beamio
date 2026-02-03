import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 24) {
                    headerSection
                    dpadSection
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Remote")
                .font(BeamioTheme.titleFont(28))
            Text("Control navigation, playback, and menus.")
                .font(BeamioTheme.bodyFont(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var dpadSection: some View {
        BeamioCard {
            VStack(spacing: 16) {
                remoteButton(icon: "chevron.up", action: { adbManager.sendKeyEvent(19) })

                HStack(spacing: 40) {
                    remoteButton(icon: "chevron.left", action: { adbManager.sendKeyEvent(21) })

                    Button {
                        adbManager.sendKeyEvent(23)
                    } label: {
                        Text("OK")
                            .font(BeamioTheme.subtitleFont(16))
                            .frame(width: 68, height: 68)
                    }
                    .buttonStyle(RemotePrimaryButtonStyle())

                    remoteButton(icon: "chevron.right", action: { adbManager.sendKeyEvent(22) })
                }

                remoteButton(icon: "chevron.down", action: { adbManager.sendKeyEvent(20) })
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actionSection: some View {
        BeamioCard {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Back") { adbManager.sendKeyEvent(4) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Home") { adbManager.sendKeyEvent(3) }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Menu") { adbManager.sendKeyEvent(82) }
                        .buttonStyle(SecondaryButtonStyle())
                }

                Button("Play / Pause") {
                    adbManager.sendKeyEvent(85)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func remoteButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(RemoteButtonStyle())
    }
}

struct RemoteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color(.secondarySystemBackground).opacity(configuration.isPressed ? 0.7 : 0.9))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(.primary)
    }
}

struct RemotePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(BeamioTheme.accent.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
    }
}

#Preview {
    RemoteView()
        .environmentObject(ADBManager.shared)
}
