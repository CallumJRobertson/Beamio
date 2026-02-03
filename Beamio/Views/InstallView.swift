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

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                directLinkSection
                fileInstallSection
                scanSection
            }
            .padding()
            .navigationTitle("Install")
        }
    }

    private var directLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direct APK Link")
                .font(.headline)

            TextField("https://example.com/app.apk", text: $directApkURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileInstallSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Install from File")
                .font(.headline)

            Button {
                showFileImporter = true
            } label: {
                Label("Choose APK File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)

            if let fileImportError {
                Text(fileImportError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan for APKs")
                .font(.headline)

            TextField("https://example.com/downloads", text: $updateURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Button {
                adbManager.scanURL(updateURL) { items in
                    apkItems = items
                    selectedApk = items.first(where: { $0.isPreferred }) ?? items.first
                }
            } label: {
                Label("Scan URL", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(updateURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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

                Button {
                    if let selectedApk {
                        adbManager.installApk(from: selectedApk.url)
                    }
                } label: {
                    Label("Install Selected", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApk == nil)
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
    InstallView()
        .environmentObject(ADBManager.shared)
}
