import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("fireTVIP") private var fireTVIP: String = ""

    @State private var searchText: String = ""
    @State private var selectedApp: AppInfo?

    private var keyStoragePath: String {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return url?.path ?? NSTemporaryDirectory()
    }

    private var filteredApps: [AppInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return adbManager.apps }
        return adbManager.apps.filter {
            $0.label.localizedCaseInsensitiveContains(query) ||
            $0.packageName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                connectionSection
                installStatusSection
                actionsSection
                appsSection
            }
            .padding()
            .navigationTitle("Apps")
            .onAppear {
                if adbManager.apps.isEmpty {
                    adbManager.refreshApps()
                }
            }
            .sheet(item: $selectedApp) { app in
                UpdateSourceSheet(app: app, existingSource: adbManager.updateSource(for: app.packageName))
                    .environmentObject(adbManager)
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection")
                .font(.headline)
            Text(adbManager.connectionStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                adbManager.connect(ipAddress: fireTVIP, keyStoragePath: keyStoragePath)
            } label: {
                Label("Connect", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            .disabled(fireTVIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var installStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install Status")
                .font(.headline)
            Text(adbManager.installStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let progress = adbManager.installProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else if adbManager.isInstalling {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsSection: some View {
        HStack {
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Button {
                adbManager.refreshApps()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(adbManager.isLoadingApps)
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Installed Apps")
                    .font(.headline)
                Spacer()
                if adbManager.isLoadingApps {
                    ProgressView()
                }
            }

            if let appsError = adbManager.appsError {
                Text(appsError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if filteredApps.isEmpty {
                Text(adbManager.isLoadingApps ? "Loading apps..." : "No apps found.")
                    .foregroundColor(.secondary)
            } else {
                List(filteredApps) { app in
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
                .frame(maxHeight: 420)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppRow: View {
    @EnvironmentObject private var adbManager: ADBManager
    let app: AppInfo
    let updateAction: () -> Void

    private var isSideloaded: Bool {
        guard let installer = app.installer?.lowercased() else { return true }
        if installer.isEmpty || installer == "null" { return true }
        let knownInstallers = [
            "com.android.vending",
            "com.amazon.venezia",
            "com.amazon.appstore",
            "com.amazon.windowshop"
        ]
        return !knownInstallers.contains(installer)
    }

    private var updateLabel: String {
        if adbManager.updateSource(for: app.packageName) != nil {
            return "Update"
        }
        return isSideloaded ? "Add Source" : "Set Source"
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(app.label)
                    .fontWeight(.semibold)
                Text(app.packageName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let version = app.versionName, !version.isEmpty {
                    Text("Version \(version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSideloaded {
                Text("Sideloaded")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }

            Button(updateLabel) {
                updateAction()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = app.iconData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                Text(String(app.label.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
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
        NavigationView {
            Form {
                Section("App") {
                    Text(app.label)
                        .font(.headline)
                    Text(app.packageName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Update Source") {
                    TextField("https://example.com/app.apk", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button("Save Source") {
                        adbManager.setUpdateSource(urlText, for: app.packageName)
                        dismiss()
                    }

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
                }

                Section("Install from File") {
                    Button("Choose APK File") {
                        showFileImporter = true
                    }
                }

                Section {
                    Button("Clear Source", role: .destructive) {
                        adbManager.setUpdateSource(nil, for: app.packageName)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Update \(app.label)")
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
    ContentView()
        .environmentObject(ADBManager.shared)
}
