import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("fireTVIP") private var fireTVIP: String = ""
    @AppStorage("updateURL") private var updateURL: String = ""
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch: Bool = false

    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    @State private var showDisconnectAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        PageHeader(
                            title: "Settings",
                            subtitle: "Configure device and app preferences",
                            icon: "gearshape.fill"
                        )

                        if adbManager.isConnected {
                            deviceInfoSection
                        }

                        connectionSection
                        adbSettingsSection
                        sourcesSection
                        cacheSection
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .alert("Clear Icon Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    adbManager.clearIconCache()
                }
            } message: {
                Text("This will remove all cached app icons. They will be re-downloaded when needed.")
            }
            .alert("Reset App?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetApp()
                }
            } message: {
                Text("This will clear all settings and cached data. You'll need to set up the app again.")
            }
            .alert("Disconnect?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    adbManager.disconnect()
                }
            } message: {
                Text("This will disconnect from the current device.")
            }
        }
    }

    // MARK: - Device Info Section

    private var deviceInfoSection: some View {
        BeamioSection("Connected Device") {
            BeamioCard {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(adbManager.deviceInfo.displayName)
                                .font(BeamioTheme.subtitleFont(16))

                            if !adbManager.deviceInfo.androidVersion.isEmpty {
                                Text("Android \(adbManager.deviceInfo.androidVersion)")
                                    .font(BeamioTheme.bodyFont(13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        StatusIndicator(isActive: true)
                    }

                    BeamioDivider()

                    VStack(spacing: 12) {
                        if !adbManager.deviceInfo.manufacturer.isEmpty {
                            deviceInfoRow(label: "Manufacturer", value: adbManager.deviceInfo.manufacturer)
                        }
                        if !adbManager.deviceInfo.model.isEmpty {
                            deviceInfoRow(label: "Model", value: adbManager.deviceInfo.model)
                        }
                        if !adbManager.deviceInfo.sdkVersion.isEmpty {
                            deviceInfoRow(label: "SDK Version", value: adbManager.deviceInfo.sdkVersion)
                        }
                        if !adbManager.deviceInfo.buildId.isEmpty {
                            deviceInfoRow(label: "Build ID", value: adbManager.deviceInfo.buildId)
                        }
                    }

                    Button {
                        showDisconnectAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Disconnect")
                        }
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
            }
        }
    }

    private func deviceInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(BeamioTheme.bodyFont(13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(BeamioTheme.bodyFont(13))
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        BeamioSection("Connection") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Device Address", systemImage: "network")
                            .font(BeamioTheme.subtitleFont(14))

                        TextField("192.168.0.21:5555", text: $fireTVIP)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .beamioTextField()

                        HStack {
                            Image(systemName: BeamioValidator.isValidIP(fireTVIP) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(BeamioValidator.isValidIP(fireTVIP) ? BeamioTheme.success : BeamioTheme.warning)
                                .font(.system(size: 12))

                            Text(BeamioValidator.isValidIP(fireTVIP) ? "Valid address format" : "Enter IPv4 address with optional :port")
                                .font(BeamioTheme.captionFont(12))
                                .foregroundColor(.secondary)
                        }
                    }

                    BeamioDivider()

                    Toggle(isOn: $autoConnectOnLaunch) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(BeamioTheme.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Connect on Launch")
                                    .font(BeamioTheme.bodyFont(14))
                                Text("Connect automatically when opening the app")
                                    .font(BeamioTheme.captionFont(11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(BeamioTheme.accent)

                    Toggle(isOn: $adbManager.autoReconnect) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(BeamioTheme.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Reconnect")
                                    .font(BeamioTheme.bodyFont(14))
                                Text("Automatically reconnect if connection is lost")
                                    .font(BeamioTheme.captionFont(11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(BeamioTheme.accent)
                    .onChange(of: adbManager.autoReconnect) { _ in
                        adbManager.saveSettings()
                    }
                }
            }
        }
    }

    // MARK: - ADB Settings Section

    private var adbSettingsSection: some View {
        BeamioSection("ADB Settings") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Connection Timeout", systemImage: "clock")
                            .font(BeamioTheme.subtitleFont(14))

                        HStack {
                            Slider(
                                value: $adbManager.connectionTimeout,
                                in: 3...30,
                                step: 1
                            )
                            .tint(BeamioTheme.accent)

                            Text("\(Int(adbManager.connectionTimeout))s")
                                .font(BeamioTheme.monoFont(13))
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .onChange(of: adbManager.connectionTimeout) { _ in
                            adbManager.saveSettings()
                        }
                    }

                    BeamioDivider()

                    Toggle(isOn: $adbManager.includeSystemApps) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundColor(BeamioTheme.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show System Apps")
                                    .font(BeamioTheme.bodyFont(14))
                                Text("Include pre-installed system applications")
                                    .font(BeamioTheme.captionFont(11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(BeamioTheme.accent)
                    .onChange(of: adbManager.includeSystemApps) { _ in
                        adbManager.saveSettings()
                        if adbManager.isConnected {
                            adbManager.refreshApps()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        BeamioSection("Download Sources") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("APK Feed URL", systemImage: "link")
                        .font(BeamioTheme.subtitleFont(14))

                    TextField("https://example.com/downloads", text: $updateURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .beamioTextField()

                    Text("Default URL for scanning APK download pages in the Install tab.")
                        .font(BeamioTheme.captionFont(12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        BeamioSection("Storage") {
            BeamioCard {
                VStack(spacing: 12) {
                    Button {
                        showClearCacheAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Clear Icon Cache")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    BeamioDivider()

                    Button {
                        hasOnboarded = false
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restart Onboarding")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    BeamioDivider()

                    Button {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(BeamioTheme.destructive)
                            Text("Reset All Settings")
                                .foregroundColor(BeamioTheme.destructive)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        BeamioSection("About") {
            BeamioCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [BeamioTheme.accent, BeamioTheme.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Beamio")
                                .font(BeamioTheme.titleFont(20))
                            Text("Fire TV Sideloader")
                                .font(BeamioTheme.bodyFont(13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("v1.0")
                            .font(BeamioTheme.captionFont(12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    BeamioDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features")
                            .font(BeamioTheme.captionFont(12))
                            .foregroundColor(.secondary)

                        featureRow(icon: "square.and.arrow.down", text: "Install APKs from URLs or files")
                        featureRow(icon: "square.grid.2x2", text: "Manage installed apps")
                        featureRow(icon: "appletvremote.gen1", text: "Remote control navigation")
                        featureRow(icon: "arrow.triangle.2.circlepath", text: "Auto-reconnect support")
                    }
                }
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(BeamioTheme.accent)
                .frame(width: 20)
            Text(text)
                .font(BeamioTheme.bodyFont(13))
        }
    }

    // MARK: - Actions

    private func resetApp() {
        adbManager.disconnect()
        adbManager.clearIconCache()

        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()

        fireTVIP = ""
        updateURL = ""
        hasOnboarded = false
        autoConnectOnLaunch = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(ADBManager.shared)
}
