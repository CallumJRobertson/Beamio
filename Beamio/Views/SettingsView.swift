import SwiftUI

struct SettingsView: View {
    @AppStorage("fireTVIP") private var fireTVIP: String = ""
    @AppStorage("updateURL") private var updateURL: String = ""
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection

                        BeamioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Device Address")
                                    .font(BeamioTheme.subtitleFont(16))

                                TextField("192.168.0.21:5555", text: $fireTVIP)
                                    .keyboardType(.numbersAndPunctuation)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .beamioTextField()

                                Text(BeamioValidator.isValidIP(fireTVIP) ? "Valid address" : "Enter a valid IPv4 address with optional :port")
                                    .font(BeamioTheme.bodyFont(12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        BeamioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Download Feed")
                                    .font(BeamioTheme.subtitleFont(16))

                                TextField("https://example.com/downloads", text: $updateURL)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .beamioTextField()

                                Text("Used for scanning APKs in the Install tab.")
                                    .font(BeamioTheme.bodyFont(12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        BeamioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Onboarding")
                                    .font(BeamioTheme.subtitleFont(16))

                                Text("Revisit the setup flow if you change devices.")
                                    .font(BeamioTheme.bodyFont(12))
                                    .foregroundColor(.secondary)

                                Button("Restart Onboarding") {
                                    hasOnboarded = false
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(BeamioTheme.titleFont(28))
            Text("Manage device connection and install sources.")
                .font(BeamioTheme.bodyFont(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

#Preview {
    SettingsView()
}
