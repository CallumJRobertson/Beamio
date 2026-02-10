import SwiftUI

// MARK: - ADB Key Storage Helper

/// Provides a consistent path for ADB key storage across the app
enum ADBKeyStorage {
    private static let keychainService = "com.beamio.adb.keys"
    private static let keychainAccount = "adb_private_key"

    /// Returns a consistent path for storing the ADB key pair (file-based backup)
    static func path() -> String {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to documents directory which is always available
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let keyDir = docs.appendingPathComponent("ADBKeys", isDirectory: true)
            try? fileManager.createDirectory(at: keyDir, withIntermediateDirectories: true)
            return keyDir.path
        }

        // Create a dedicated subdirectory for ADB keys
        let keyDir = appSupport.appendingPathComponent("ADBKeys", isDirectory: true)
        try? fileManager.createDirectory(at: keyDir, withIntermediateDirectories: true)
        return keyDir.path
    }

    /// Save private key data to Keychain
    static func saveToKeychain(_ data: Data) -> Bool {
        // Prefer update-in-place so a transient add failure can't wipe an existing key.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        // Only update the data. Some Keychain attributes (like accessibility) can't always be updated in-place.
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    /// Load private key data from Keychain
    static func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        return nil
    }

    /// Check if key exists in Keychain
    static func hasKeychainKey() -> Bool {
        return loadFromKeychain() != nil
    }
}

struct ConnectionPanel: View {
    @EnvironmentObject private var adbManager: ADBManager
    @ObservedObject private var settings = AppSettings.shared

    @State private var hasAttemptedAutoConnect = false

    var body: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Connection")
                            .font(BeamioTheme.subtitleFont(15))

                        HStack(spacing: 6) {
                            statusIcon
                            Text(adbManager.connectionState.displayText)
                                .font(BeamioTheme.captionFont(12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    StatusIndicator(
                        isActive: adbManager.isConnected,
                        activeColor: BeamioTheme.success,
                        inactiveColor: statusIndicatorColor
                    )
                }

                TextField("192.168.0.21:5555", text: $settings.fireTVIP)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .beamioTextField()
                    .disabled(isConnecting)

                HStack {
                    validationText
                    Spacer()
                    connectButton
                }
            }
        }
        .onAppear {
            attemptAutoConnect()
        }
    }

    private var isConnecting: Bool {
        if case .connecting = adbManager.connectionState { return true }
        if case .reconnecting = adbManager.connectionState { return true }
        return false
    }

    private var statusIndicatorColor: Color {
        switch adbManager.connectionState {
        case .connecting, .reconnecting:
            return BeamioTheme.accent
        case .failed:
            return BeamioTheme.destructive
        default:
            return BeamioTheme.warning
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch adbManager.connectionState {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(BeamioTheme.success)
                .font(.system(size: 12))
        case .connecting, .reconnecting:
            ProgressView()
                .scaleEffect(0.6)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(BeamioTheme.destructive)
                .font(.system(size: 12))
        case .disconnected:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
        }
    }

    @ViewBuilder
    private var validationText: some View {
        HStack(spacing: 4) {
            Image(systemName: BeamioValidator.isValidIP(settings.fireTVIP) ? "checkmark.circle" : "info.circle")
                .font(.system(size: 11))

            Text(BeamioValidator.isValidIP(settings.fireTVIP) ? "Ready to connect" : "Enter a valid IPv4 address")
                .font(BeamioTheme.captionFont(11))
        }
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var connectButton: some View {
        Button {
            performConnect()
        } label: {
            HStack(spacing: 6) {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: adbManager.isConnected ? "arrow.triangle.2.circlepath" : "link")
                        .font(.system(size: 12))
                }
                Text(buttonTitle)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!BeamioValidator.isValidIP(settings.fireTVIP) || isConnecting)
    }

    private var buttonTitle: String {
        switch adbManager.connectionState {
        case .connecting:
            return "Connecting"
        case .reconnecting:
            return "Reconnecting"
        case .connected:
            return "Reconnect"
        default:
            return "Connect"
        }
    }

    private func performConnect() {
        let storagePath = ADBKeyStorage.path()
        adbManager.connect(ipAddress: settings.fireTVIP, keyStoragePath: storagePath)
    }

    private func attemptAutoConnect() {
        guard !hasAttemptedAutoConnect else { return }
        hasAttemptedAutoConnect = true

        guard settings.autoConnectOnLaunch,
              !adbManager.isConnected,
              BeamioValidator.isValidIP(settings.fireTVIP) else {
            return
        }

        performConnect()
    }
}

// MARK: - Compact Connection Panel (for inline use)

struct CompactConnectionPanel: View {
    @EnvironmentObject private var adbManager: ADBManager
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Button {
            let storagePath = ADBKeyStorage.path()
            adbManager.connect(ipAddress: settings.fireTVIP, keyStoragePath: storagePath)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                Text("Connect")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!BeamioValidator.isValidIP(settings.fireTVIP))
    }
}

// MARK: - Connect Required View

struct ConnectRequiredView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BeamioTheme.accent.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "tv.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [BeamioTheme.accent, BeamioTheme.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Connect Your Fire TV")
                            .font(BeamioTheme.titleFont(24))

                        Text("Enter your device IP address to manage apps, install APKs, and control your Fire TV.")
                            .font(BeamioTheme.bodyFont(15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }

                ConnectionPanel()
                    .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    Text("Need help finding your IP?")
                        .font(BeamioTheme.captionFont(13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Settings")
                        Image(systemName: "chevron.right")
                        Text("Device Options")
                        Image(systemName: "chevron.right")
                        Text("About")
                        Image(systemName: "chevron.right")
                        Text("Network")
                    }
                    .font(BeamioTheme.captionFont(11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .cornerRadius(8)
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Connection Gate

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

// MARK: - Connection Status Banner

struct ConnectionStatusBanner: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        switch adbManager.connectionState {
        case .reconnecting:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Reconnecting...")
                    .font(BeamioTheme.captionFont(12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(BeamioTheme.accent.opacity(0.15))
            .cornerRadius(20)

        case .failed(let reason):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(BeamioTheme.destructive)
                Text(reason)
                    .font(BeamioTheme.captionFont(12))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(BeamioTheme.destructive.opacity(0.15))
            .cornerRadius(20)

        default:
            EmptyView()
        }
    }
}
