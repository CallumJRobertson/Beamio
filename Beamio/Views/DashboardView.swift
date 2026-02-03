import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @AppStorage("fireTVIP") private var fireTVIP: String = ""
    @AppStorage("updateURL") private var updateURL: String = ""

    @State private var apkItems: [ApkItem] = []
    @State private var selectedApk: ApkItem?
    @State private var directApkURL: String = ""
    @State private var showFileImporter = false
    @State private var fileImportError: String?

    private var keyStoragePath: String {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return url?.path ?? NSTemporaryDirectory()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                statusSection
                actionSection
                apkListSection
            }
            .padding()
            .navigationTitle("Dashboard")
        }
        .onAppear {
            if selectedApk == nil {
                selectedApk = apkItems.first(where: { $0.isPreferred }) ?? apkItems.first
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Status")
                .font(.headline)
            Text(adbManager.connectionStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                adbManager.connect(ipAddress: fireTVIP, keyStoragePath: keyStoragePath)
            } label: {
                Label("Connect", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            .disabled(fireTVIP.isEmpty)

            Button {
                adbManager.scanURL(updateURL) { items in
                    apkItems = items
                    selectedApk = items.first(where: { $0.isPreferred }) ?? items.first
                }
            } label: {
                Label("Scan for APKs", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(updateURL.isEmpty)

            VStack(alignment: .leading, spacing: 8) {
                Text("Direct APK Link")
                    .font(.headline)
                TextField("https://example.com/app.apk", text: $directApkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Button {
                        let trimmed = directApkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let displayName = URL(string: trimmed)?.lastPathComponent ?? "Direct APK"
                        if !apkItems.contains(where: { $0.url == trimmed }) {
                            let item = ApkItem(name: displayName, url: trimmed)
                            apkItems.insert(item, at: 0)
                            selectedApk = item
                        } else {
                            selectedApk = apkItems.first(where: { $0.url == trimmed })
                        }
                    } label: {
                        Label("Add to List", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(directApkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        let trimmed = directApkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        adbManager.installApk(from: trimmed)
                    } label: {
                        Label("Install Link", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(directApkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showFileImporter = true
            } label: {
                Label("Install from File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)

            Button {
                if let selectedApk {
                    adbManager.installApk(from: selectedApk.url)
                }
            } label: {
                Label("Install Selected APK", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(selectedApk == nil)

            if let fileImportError {
                Text(fileImportError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
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
                fileImportError = "File import failed: \(error.localizedDescription)"
            }
        }
    }

    private var apkListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available APKs")
                .font(.headline)

            if apkItems.isEmpty {
                Text("No APKs scanned yet.")
                    .foregroundColor(.secondary)
            } else {
                List(apkItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .fontWeight(item.isPreferred ? .semibold : .regular)
                            Text(item.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if item.isPreferred {
                            Text("ARM")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        if item == selectedApk {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedApk = item
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
