import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Welcome to Beamio")
                            .font(BeamioTheme.titleFont(28))
                        Text("Connect your Fire TV and manage installs, updates, and remote control from your iPhone.")
                            .font(BeamioTheme.bodyFont(15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    BeamioCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Get Ready")
                                .font(BeamioTheme.subtitleFont(17))

                            OnboardingStep(number: "1", title: "Same Wi-Fi", detail: "Keep your iPhone and Fire TV on the same network.")
                            OnboardingStep(number: "2", title: "Enable ADB", detail: "Settings → My Fire TV → Developer Options → ADB Debugging.")
                            OnboardingStep(number: "3", title: "Find IP", detail: "Settings → My Fire TV → About → Network.")
                        }
                    }
                    .padding(.horizontal, 20)

                    ConnectionPanel()
                        .padding(.horizontal, 20)

                    if adbManager.isConnected {
                        Button("Continue") {
                            hasOnboarded = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.bottom, 24)
                    } else {
                        Text("Connect to continue")
                            .font(BeamioTheme.bodyFont(13))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
    }
}

struct OnboardingStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(BeamioTheme.subtitleFont(14))
                .frame(width: 26, height: 26)
                .background(BeamioTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BeamioTheme.subtitleFont(15))
                Text(detail)
                    .font(BeamioTheme.bodyFont(13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ADBManager.shared)
}
