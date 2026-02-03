import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var adbManager: ADBManager

    @State private var searchText: String = ""
    @State private var selectedApp: AppInfo?
    @State private var showSortOptions = false
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case packageName = "Package"
        case source = "Source"
    }

    private var filteredApps: [AppInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var apps = adbManager.apps

        if !query.isEmpty {
            apps = apps.filter {
                $0.label.localizedCaseInsensitiveContains(query) ||
                $0.packageName.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOrder {
        case .name:
            apps.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        case .packageName:
            apps.sort { $0.packageName < $1.packageName }
        case .source:
            apps.sort { ($0.installer ?? "zz") < ($1.installer ?? "zz") }
        }

        return apps
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        deviceStatusCard
                        installStatusCard
                        appsListCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await refreshApps()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }

                        Button {
                            adbManager.refreshApps()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(adbManager.isLoadingApps)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onAppear {
                if adbManager.apps.isEmpty && adbManager.isConnected {
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

    private func refreshApps() async {
        adbManager.refreshApps()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        PageHeader(
            title: "Apps",
            subtitle: "Manage installed apps and updates",
            icon: "square.grid.2x2.fill"
        )
    }

    // MARK: - Device Status Card

    private var deviceStatusCard: some View {
        BeamioCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(adbManager.isConnected ? BeamioTheme.success.opacity(0.15) : BeamioTheme.warning.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: adbManager.isConnected ? "tv.fill" : "tv")
                        .font(.system(size: 18))
                        .foregroundColor(adbManager.isConnected ? BeamioTheme.success : BeamioTheme.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(adbManager.isConnected ? adbManager.deviceInfo.displayName : "No Device")
                        .font(BeamioTheme.subtitleFont(15))

                    HStack(spacing: 6) {
                        StatusIndicator(isActive: adbManager.isConnected, showPulse: false)
                        Text(adbManager.connectionState.displayText)
                            .font(BeamioTheme.captionFont(12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !adbManager.isConnected {
                    ConnectionPanel()
                        .frame(maxWidth: 120)
                }
            }
        }
    }

    // MARK: - Install Status Card

    @ViewBuilder
    private var installStatusCard: some View {
        if adbManager.isInstalling || adbManager.installStatus != "Idle" {
            BeamioCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(BeamioTheme.accent)

                        Text("Installation")
                            .font(BeamioTheme.subtitleFont(15))

                        Spacer()

                        if adbManager.isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: adbManager.installStatus.contains("complete") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(adbManager.installStatus.contains("complete") ? BeamioTheme.success : BeamioTheme.destructive)
                        }
                    }

                    Text(adbManager.installStatus)
                        .font(BeamioTheme.bodyFont(13))
                        .foregroundColor(.secondary)

                    if let progress = adbManager.installProgress {
                        ProgressView(value: progress)
                            .tint(BeamioTheme.accent)
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: adbManager.isInstalling)
        }
    }

    // MARK: - Apps List Card

    private var appsListCard: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Installed Apps")
                        .font(BeamioTheme.subtitleFont(16))

                    if !adbManager.apps.isEmpty {
                        Text("\(filteredApps.count)")
                            .font(BeamioTheme.captionFont(12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if adbManager.isLoadingApps {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading...")
                                .font(BeamioTheme.captionFont(12))
                                .foregroundColor(.secondary)
                        }
                    } else if adbManager.totalIconsToLoad > 0 && adbManager.iconLoadingCount < adbManager.totalIconsToLoad {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 11))
                            Text("\(adbManager.iconLoadingCount)/\(adbManager.totalIconsToLoad)")
                                .font(BeamioTheme.captionFont(11))
                        }
                        .foregroundColor(.secondary)
                    }
                }

                if let appsError = adbManager.appsError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(BeamioTheme.warning)
                        Text(appsError)
                            .font(BeamioTheme.bodyFont(13))
                    }
                    .padding(12)
                    .background(BeamioTheme.warning.opacity(0.1))
                    .cornerRadius(10)
                }

                if filteredApps.isEmpty {
                    EmptyStateView(
                        icon: adbManager.isLoadingApps ? "arrow.clockwise" : "square.grid.2x2",
                        title: adbManager.isLoadingApps ? "Loading Apps" : "No Apps Found",
                        message: adbManager.isLoadingApps
                            ? "Fetching installed applications..."
                            : (searchText.isEmpty ? "Connect to a device to see installed apps" : "No apps match your search"),
                        action: !adbManager.isLoadingApps && searchText.isEmpty && adbManager.isConnected ? {
                            adbManager.refreshApps()
                        } : nil,
                        actionTitle: "Refresh"
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredApps) { app in
                            AppRow(app: app) {
                                handleUpdateAction(for: app)
                            }
                            .onAppear {
                                adbManager.loadIcon(for: app)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .animation(.spring(response: 0.3), value: filteredApps.count)
                }
            }
        }
    }

    private func handleUpdateAction(for app: AppInfo) {
        let source = adbManager.updateSource(for: app.packageName)
        if let source {
            adbManager.installApk(from: source)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            selectedApp = app
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    @EnvironmentObject private var adbManager: ADBManager
    let app: AppInfo
    let updateAction: () -> Void

    private var sourceBadge: (String, Color, String)? {
        if app.isSystem {
            return ("System", .gray, "gearshape")
        }
        guard let installer = app.installer?.lowercased(), !installer.isEmpty, installer != "null" else {
            return ("Unknown", BeamioTheme.warning, "questionmark.circle")
        }
        let knownInstallers: [String: (String, Color, String)] = [
            "com.android.vending": ("Play Store", BeamioTheme.success, "checkmark.seal.fill"),
            "com.amazon.venezia": ("Amazon", BeamioTheme.teal, "checkmark.seal.fill"),
            "com.amazon.appstore": ("Amazon", BeamioTheme.teal, "checkmark.seal.fill"),
            "com.amazon.windowshop": ("Amazon", BeamioTheme.teal, "checkmark.seal.fill")
        ]
        if let info = knownInstallers[installer] {
            return info
        }
        return ("Sideloaded", BeamioTheme.purple, "arrow.down.circle")
    }

    private var hasUpdateSource: Bool {
        adbManager.updateSource(for: app.packageName) != nil
    }

    private func manualIconUrl(for package: String) -> URL? {
        let map: [String: String] = [
            "com.netflix.ninja": "https://img.icons8.com/color/96/netflix.png",
            "com.netflix.mediaclient": "https://img.icons8.com/color/96/netflix.png",
            "com.google.android.youtube": "https://img.icons8.com/color/96/youtube-play.png",
            "com.google.android.youtube.tv": "https://img.icons8.com/color/96/youtube-play.png",
            "com.stremio.android": "https://img.icons8.com/external-others-pike-picture/96/stremio.png",
            "org.videolan.vlc": "https://img.icons8.com/color/96/vlc.png",
            "com.amazon.avod": "https://img.icons8.com/fluency/96/amazon-prime-video.png",
            "com.amazon.avs": "https://img.icons8.com/fluency/96/amazon-prime-video.png",
            "com.spotify.tv.android": "https://img.icons8.com/color/96/spotify.png",
            "com.hulu.plus": "https://img.icons8.com/color/96/hulu.png",
            "com.emerson.youtube": "https://img.icons8.com/color/96/youtube-play.png",
            "com.mxtech.videoplayer.ad": "https://img.icons8.com/color/96/video.png",
            "com.pandora.android": "https://img.icons8.com/color/96/pandora.png"
        ]
        guard let urlString = map[package] else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.label)
                    .font(BeamioTheme.subtitleFont(15))
                    .lineLimit(1)

                Text(app.packageName)
                    .font(BeamioTheme.bodyFont(11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let version = app.versionName, !version.isEmpty {
                        Text("v\(version)")
                            .font(BeamioTheme.captionFont(10))
                            .foregroundColor(.secondary)
                    }

                    if let badge = sourceBadge {
                        PillBadge(text: badge.0, color: badge.1, icon: badge.2)
                    }
                }
            }

            Spacer()

            Button {
                updateAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: hasUpdateSource ? "arrow.down.circle.fill" : "ellipsis.circle")
                        .font(.system(size: 14))
                    Text(hasUpdateSource ? "Update" : "Source")
                        .font(BeamioTheme.captionFont(12))
                }
            }
            .buttonStyle(hasUpdateSource ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
        }
        .listRowStyle()
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
                    IconPlaceholder(letter: String(app.label.prefix(1)), isLoading: true)
                }
            }
        } else if let data = app.iconData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            IconPlaceholder(letter: String(app.label.prefix(1)), isLoading: app.isLoadingIcon)
        }
    }
}

// MARK: - Update Source Sheet

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
                    VStack(spacing: 20) {
                        appInfoCard
                        updateSourceCard
                        fileInstallCard
                        clearSourceButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Update Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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

    private var appInfoCard: some View {
        BeamioCard {
            HStack(spacing: 14) {
                IconPlaceholder(letter: String(app.label.prefix(1)), size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.label)
                        .font(BeamioTheme.subtitleFont(16))

                    Text(app.packageName)
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)

                    if let version = app.versionName {
                        Text("Version \(version)")
                            .font(BeamioTheme.captionFont(11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    private var updateSourceCard: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("APK Update URL", systemImage: "link")
                    .font(BeamioTheme.subtitleFont(15))

                TextField("https://example.com/app.apk", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .beamioTextField()

                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(BeamioTheme.destructive)
                        Text(errorMessage)
                            .font(BeamioTheme.bodyFont(12))
                            .foregroundColor(BeamioTheme.destructive)
                    }
                }

                Text("Enter a direct link to the APK file for one-tap updates.")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Save") {
                        adbManager.setUpdateSource(urlText, for: app.packageName)
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Save & Install") {
                        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            adbManager.setUpdateSource(trimmed, for: app.packageName)
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
    }

    private var fileInstallCard: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Install from File", systemImage: "doc.fill")
                    .font(BeamioTheme.subtitleFont(15))

                Text("Select an APK file from your device to install directly.")
                    .font(BeamioTheme.captionFont(12))
                    .foregroundColor(.secondary)

                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Choose APK File")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var clearSourceButton: some View {
        if adbManager.updateSource(for: app.packageName) != nil {
            Button {
                adbManager.setUpdateSource(nil, for: app.packageName)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove Update Source")
                }
            }
            .buttonStyle(DestructiveButtonStyle())
        }
    }

    private var apkContentTypes: [UTType] {
        if let apk = UTType(filenameExtension: "apk") {
            return [apk, .data]
        }
        return [.data]
    }
}

// MARK: - Type Erased Button Style

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

#Preview {
    DashboardView()
        .environmentObject(ADBManager.shared)
}
