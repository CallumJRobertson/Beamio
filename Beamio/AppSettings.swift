import Foundation
import SwiftUI

/// Centralized app settings manager
/// Use this instead of scattered @AppStorage declarations to ensure consistency
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Connection Settings
    @AppStorage("fireTVIP") var fireTVIP: String = ""
    @AppStorage("autoConnectOnLaunch") var autoConnectOnLaunch: Bool = false

    // MARK: - Install Settings
    @AppStorage("updateURL") var updateURL: String = ""
    @AppStorage("directApkURL") var directApkURL: String = ""

    // MARK: - App State
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false

    // MARK: - Log Settings
    @AppStorage("hideADBLogs") var hideADBLogs: Bool = true

    // MARK: - Performance
    // Fetching icons by pulling APKs from the device is very slow and can interfere with installs/updates.
    @AppStorage("downloadDeviceIcons") var downloadDeviceIcons: Bool = false

    private init() {}

    /// Reset all settings to defaults
    func reset() {
        fireTVIP = ""
        autoConnectOnLaunch = false
        updateURL = ""
        directApkURL = ""
        hasOnboarded = false
        hideADBLogs = true
        downloadDeviceIcons = false
    }
}
