import SwiftUI
import UIKit

struct RemoteView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        PageHeader(
                            title: "Remote",
                            subtitle: "Control your Fire TV device",
                            icon: "appletvremote.gen1.fill"
                        )

                        deviceStatusBanner

                        dpadSection
                        mediaControlsSection
                        navigationSection
                        powerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
        }
    }

    // MARK: - Device Status Banner

    @ViewBuilder
    private var deviceStatusBanner: some View {
        if adbManager.isConnected {
            HStack(spacing: 10) {
                Image(systemName: "tv.fill")
                    .foregroundColor(BeamioTheme.success)
                Text(adbManager.deviceInfo.displayName)
                    .font(BeamioTheme.captionFont(13))

                Spacer()

                StatusIndicator(isActive: true, size: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BeamioTheme.success.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - D-Pad Section

    private var dpadSection: some View {
        BeamioCard {
            VStack(spacing: 8) {
                Text("Navigation")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    remoteButton(icon: "chevron.up", keyCode: 19)

                    HStack(spacing: 32) {
                        remoteButton(icon: "chevron.left", keyCode: 21)

                        Button {
                            sendKey(23)
                        } label: {
                            Text("OK")
                                .font(BeamioTheme.subtitleFont(16))
                                .frame(width: 72, height: 72)
                        }
                        .buttonStyle(RemotePrimaryButtonStyle())

                        remoteButton(icon: "chevron.right", keyCode: 22)
                    }

                    remoteButton(icon: "chevron.down", keyCode: 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Media Controls Section

    private var mediaControlsSection: some View {
        BeamioCard {
            VStack(spacing: 12) {
                Text("Media")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    mediaButton(icon: "backward.fill", keyCode: 89)
                    mediaButton(icon: "playpause.fill", keyCode: 85, isPrimary: true)
                    mediaButton(icon: "forward.fill", keyCode: 90)
                }

                BeamioDivider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        volumeButton(icon: "speaker.wave.3.fill", keyCode: 24)
                        Text("Vol +")
                            .font(BeamioTheme.captionFont(10))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 8) {
                        volumeButton(icon: "speaker.slash.fill", keyCode: 164)
                        Text("Mute")
                            .font(BeamioTheme.captionFont(10))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 8) {
                        volumeButton(icon: "speaker.wave.1.fill", keyCode: 25)
                        Text("Vol -")
                            .font(BeamioTheme.captionFont(10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        BeamioCard {
            VStack(spacing: 12) {
                Text("Navigation")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    actionButton(title: "Back", icon: "arrow.uturn.backward", keyCode: 4)
                    actionButton(title: "Home", icon: "house.fill", keyCode: 3)
                    actionButton(title: "Menu", icon: "line.3.horizontal", keyCode: 82)
                }

                HStack(spacing: 12) {
                    actionButton(title: "Recent", icon: "square.stack", keyCode: 187)
                    actionButton(title: "Voice", icon: "mic.fill", keyCode: 79)
                    actionButton(title: "Search", icon: "magnifyingglass", keyCode: 84)
                }
            }
        }
    }

    // MARK: - Power Section

    private var powerSection: some View {
        BeamioCard {
            VStack(spacing: 12) {
                Text("Power")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Button {
                        sendKey(26) // Power
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "power")
                            Text("Sleep")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        sendKey(223) // Sleep (some devices)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.fill")
                            Text("Screensaver")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Button Helpers

    private func remoteButton(icon: String, keyCode: Int) -> some View {
        Button {
            sendKey(keyCode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(RemoteButtonStyle())
    }

    private func mediaButton(icon: String, keyCode: Int, isPrimary: Bool = false) -> some View {
        Button {
            sendKey(keyCode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 60, height: 48)
        }
        .buttonStyle(isPrimary ? AnyButtonStyle(RemotePrimaryButtonStyle()) : AnyButtonStyle(RemoteButtonStyle()))
    }

    private func volumeButton(icon: String, keyCode: Int) -> some View {
        Button {
            sendKey(keyCode)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 52, height: 44)
        }
        .buttonStyle(RemoteButtonStyle())
    }

    private func actionButton(title: String, icon: String, keyCode: Int) -> some View {
        Button {
            sendKey(keyCode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(BeamioTheme.captionFont(11))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func sendKey(_ keyCode: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        adbManager.sendKeyEvent(keyCode)
    }
}

// MARK: - Previews

#Preview {
    RemoteView()
        .environmentObject(ADBManager.shared)
}
