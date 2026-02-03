import SwiftUI
import UniformTypeIdentifiers

struct InstallView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("updateURL") private var updateURL: String = ""
    @AppStorage("directApkURL") private var directApkURL: String = ""

    @State private var apkItems: [ApkItem] = []
    @State private var selectedApk: ApkItem?
    @State private var showFileImporter = false
    @State private var fileImportError: String?
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        PageHeader(
                            title: "Install",
                            subtitle: "Sideload APKs to your device",
                            icon: "square.and.arrow.down.fill"
                        )

                        installProgressCard
                        directLinkSection
                        fileInstallSection
                        scanSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
        }
    }

    // MARK: - Install Progress Card

    @ViewBuilder
    private var installProgressCard: some View {
        if adbManager.isInstalling {
            BeamioCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(BeamioTheme.accent)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Installing...")
                                .font(BeamioTheme.subtitleFont(15))
                            Text(adbManager.installStatus)
                                .font(BeamioTheme.captionFont(12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        ProgressView()
                    }

                    if let progress = adbManager.installProgress {
                        ProgressView(value: progress)
                            .tint(BeamioTheme.accent)
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Direct Link Section

    private var directLinkSection: some View {
        BeamioSection("Direct Install") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("APK URL", systemImage: "link")
                        .font(BeamioTheme.subtitleFont(15))

                    TextField("https://example.com/app.apk", text: $directApkURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .beamioTextField()

                    Text("Paste a direct link to an APK file to install it.")
                        .font(BeamioTheme.captionFont(12))
                        .foregroundColor(.secondary)

                    Button {
                        let trimmed = directApkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        adbManager.installApk(from: trimmed)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Install from URL")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(directApkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || adbManager.isInstalling)
                }
            }
        }
    }

    // MARK: - File Install Section

    private var fileInstallSection: some View {
        BeamioSection("Local File") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Install from Device", systemImage: "doc.fill")
                        .font(BeamioTheme.subtitleFont(15))

                    Text("Select an APK file from your iPhone or iPad.")
                        .font(BeamioTheme.captionFont(12))
                        .foregroundColor(.secondary)

                    if let fileImportError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(BeamioTheme.destructive)
                            Text(fileImportError)
                                .font(BeamioTheme.bodyFont(12))
                                .foregroundColor(BeamioTheme.destructive)
                        }
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text("Choose APK File")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(adbManager.isInstalling)
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
                    fileImportError = nil
                    adbManager.installApkFile(url)
                case .failure(let error):
                    fileImportError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Scan Section

    private var scanSection: some View {
        BeamioSection("Scan Web Page") {
            BeamioCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Find APKs", systemImage: "magnifyingglass")
                        .font(BeamioTheme.subtitleFont(15))

                    TextField("https://example.com/downloads", text: $updateURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .beamioTextField()

                    Text("Scan a web page to find APK download links.")
                        .font(BeamioTheme.captionFont(12))
                        .foregroundColor(.secondary)

                    Button {
                        performScan()
                    } label: {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.primary)
                            } else {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                            Text(isScanning ? "Scanning..." : "Scan URL")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(updateURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isScanning)

                    if !apkItems.isEmpty {
                        BeamioDivider()
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Found APKs")
                                    .font(BeamioTheme.captionFont(12))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(apkItems.count) files")
                                    .font(BeamioTheme.captionFont(11))
                                    .foregroundColor(.secondary)
                            }

                            ForEach(apkItems) { item in
                                apkItemRow(item)
                            }
                        }

                        Button {
                            if let selectedApk {
                                adbManager.installApk(from: selectedApk.url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Install Selected")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedApk == nil || adbManager.isInstalling)
                    }
                }
            }
        }
    }

    private func apkItemRow(_ item: ApkItem) -> some View {
        Button {
            selectedApk = item
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(BeamioTheme.bodyFont(14))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(item.url)
                        .font(BeamioTheme.captionFont(11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if item.isPreferred {
                    PillBadge(text: "ARM", color: BeamioTheme.accent, icon: "cpu")
                }

                if item == selectedApk {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(BeamioTheme.accent)
                        .font(.system(size: 20))
                }
            }
            .listRowStyle()
        }
        .buttonStyle(.plain)
    }

    private func performScan() {
        isScanning = true
        apkItems = []
        selectedApk = nil

        adbManager.scanURL(updateURL) { items in
            apkItems = items
            selectedApk = items.first(where: { $0.isPreferred }) ?? items.first
            isScanning = false
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
    InstallView()
        .environmentObject(ADBManager.shared)
}
