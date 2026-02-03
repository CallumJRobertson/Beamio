import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var adbManager: ADBManager

    @State private var searchText: String = ""
    @State private var selectedApp: AppInfo?

    private var filteredApps: [AppInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return adbManager.apps }
        return adbManager.apps.filter {
            $0.label.localizedCaseInsensitiveContains(query) ||
            $0.packageName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        ConnectionPanel()

                        installStatusCard

                        appsListCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adbManager.refreshApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(adbManager.isLoadingApps)
                    .accessibilityLabel("Refresh Apps")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onAppear {
                if adbManager.apps.isEmpty {
                    adbManager.refreshApps()
                }
            }
            .onChange(of: adbManager.isConnected) { isConnected in
                if isConnected {
                    adbManager.refreshApps()
                }
            }
            .sheet(item: $selectedApp) { app in
                UpdateSourceSheet(app: app, existingSource: adbManager.updateSource(for: app.packageName))
                    .environmentObject(adbManager)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apps")
                .font(BeamioTheme.titleFont(28))
            Text("Manage your installed apps and keep sideloaded builds updated.")
                .font(BeamioTheme.bodyFont(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var installStatusCard: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Install Activity")
                        .font(BeamioTheme.subtitleFont(16))
                    Spacer()
                    Text(adbManager.installStatus)
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                }

                if let progress = adbManager.installProgress {
                    ProgressView(value: progress)
                        .tint(BeamioTheme.accent)
                } else if adbManager.isInstalling {
                    ProgressView()
                        .tint(BeamioTheme.accent)
                } else {
                    Text("No active installs")
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var appsListCard: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Installed Apps")
                        .font(BeamioTheme.subtitleFont(16))
                    Spacer()
                    if adbManager.isLoadingApps {
                        ProgressView()
                    }
                }

                if let appsError = adbManager.appsError {
                    Text(appsError)
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.red)
                }

                if filteredApps.isEmpty {
                    Text(adbManager.isLoadingApps ? "Loading apps..." : "No apps found.")
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredApps) { app in
                            AppRow(app: app) {
                                let source = adbManager.updateSource(for: app.packageName)
                                if let source {
                                    adbManager.installApk(from: source)
                                } else {
                                    selectedApp = app
                                }
                            }
                            .onAppear {
                                adbManager.loadIcon(for: app)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct AppRow: View {
    @EnvironmentObject private var adbManager: ADBManager
    let app: AppInfo
    let updateAction: () -> Void

    private var sourceBadge: (String, Color)? {
        if app.isSystem {
            return ("System", .gray)
        }
        guard let installer = app.installer?.lowercased(), !installer.isEmpty, installer != "null" else {
            return ("Unknown Source", BeamioTheme.warning)
        }
        let knownInstallers: [String: String] = [
            "com.android.vending": "Google Play",
            "com.amazon.venezia": "Amazon Appstore",
            "com.amazon.appstore": "Amazon Appstore",
            "com.amazon.windowshop": "Amazon Appstore"
        ]
        if let name = knownInstallers[installer] {
            return (name, BeamioTheme.success)
        }
        return ("Sideloaded", BeamioTheme.warning)
    }

    private var updateLabel: String {
        if adbManager.updateSource(for: app.packageName) != nil {
            return "Update"
        }
        return "Set Source"
    }

    private func manualIconUrl(for package: String) -> URL? {
        let map: [String: String] = [
            "com.netflix.ninja": "https://img.icons8.com/color/96/netflix.png",
            "com.google.android.youtube": "https://img.icons8.com/color/96/youtube-play.png",
            "com.google.android.youtube.tv": "https://img.icons8.com/color/96/youtube-play.png",
            "com.stremio.android": "https://img.icons8.com/external-others-pike-picture/96/stremio.png",
            "org.videolan.vlc": "https://img.icons8.com/color/96/vlc.png",
            "com.amazon.avod": "https://img.icons8.com/fluency/96/amazon-prime-video.png",
            "com.amazon.avls.experience": "https://img.icons8.com/fluency/96/amazon-prime-video.png",
            "com.amzn.firebat": "https://img.icons8.com/fluency/96/amazfit.png",
            "com.amazon.hedwig": "https://img.icons8.com/color/96/amazon-alexa.png",
            "com.amazon.cloud9": "https://img.icons8.com/color/96/amazon-s3.png",
            "com.amazon.fireos.webapp": "https://img.icons8.com/color/96/amazon.png",
            "com.spotify.tv.android": "https://img.icons8.com/color/96/spotify.png",
            "com.hulu.plus": "https://img.icons8.com/color/96/hulu.png"
        ]
        guard let urlString = map[package] else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.label)
                    .font(BeamioTheme.subtitleFont(15))
                Text(app.packageName)
                    .font(BeamioTheme.bodyFont(11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let version = app.versionName, !version.isEmpty {
                    Text("Version \(version)")
                        .font(BeamioTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let badge = sourceBadge {
                PillBadge(text: badge.0, color: badge.1)
            }

            Button(updateLabel) {
                updateAction()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground).opacity(0.7))
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if let manualURL = manualIconUrl(for: app.packageName) {
            AsyncImage(url: manualURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    placeholderIcon
                }
            }
        } else if let data = app.iconData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(BeamioTheme.accentSoft)
            Text(String(app.label.prefix(1)))
                .font(BeamioTheme.subtitleFont(16))
                .foregroundColor(.secondary)
        }
    }
}

private struct UpdateSourceSheet: View {
    @EnvironmentObject private var adbManager: ADBManager
    @Environment(\.dismiss) private var dismiss

    let app: AppInfo
    @State private var urlText: String
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    init(app: AppInfo, existingSource: String?) {
        self.app = app
        _urlText = State(initialValue: existingSource ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        BeamioCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(app.label)
                                    .font(BeamioTheme.subtitleFont(16))
                                Text(app.packageName)
                                    .font(BeamioTheme.bodyFont(12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        BeamioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Update Source")
                                    .font(BeamioTheme.subtitleFont(16))

                                TextField("https://example.com/app.apk", text: $urlText)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .beamioTextField()

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(BeamioTheme.bodyFont(12))
                                        .foregroundColor(.red)
                                }

                                HStack(spacing: 12) {
                                    Button("Save") {
                                        adbManager.setUpdateSource(urlText, for: app.packageName)
                                        dismiss()
                                    }
                                    .buttonStyle(SecondaryButtonStyle())

                                    Button("Save & Install") {
                                        adbManager.setUpdateSource(urlText, for: app.packageName)
                                        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !trimmed.isEmpty {
                                            adbManager.installApk(from: trimmed)
                                            dismiss()
                                        } else {
                                            errorMessage = "Please enter a valid URL."
                                        }
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                            }
                        }

                        BeamioCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Install from File")
                                    .font(BeamioTheme.subtitleFont(16))

                                Button("Choose APK File") {
                                    showFileImporter = true
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }

                        Button("Clear Source", role: .destructive) {
                            adbManager.setUpdateSource(nil, for: app.packageName)
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Update Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: apkContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    adbManager.installApkFile(url)
                    dismiss()
                case .failure(let error):
                    errorMessage = "File import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var apkContentTypes: [UTType] {
        if let apk = UTType(filenameExtension: "apk") {
            return [apk, .data]
        }
        return [.data]
    }
}

#Preview {
    DashboardView()
        .environmentObject(ADBManager.shared)
}
