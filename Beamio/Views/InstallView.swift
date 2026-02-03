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
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Install")
                .font(BeamioTheme.titleFont(28))
            Text("Send APKs from a link, file, or a download page.")
                .font(BeamioTheme.bodyFont(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var directLinkSection: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Direct APK Link")
                    .font(BeamioTheme.subtitleFont(16))

                TextField("https://example.com/app.apk", text: $directApkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .beamioTextField()

                Button("Install Link") {
                    let trimmed = directApkURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    adbManager.installApk(from: trimmed)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(directApkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var fileInstallSection: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Install from File")
                    .font(BeamioTheme.subtitleFont(16))

                Button("Choose APK File") {
                    showFileImporter = true
                }
                .buttonStyle(SecondaryButtonStyle())

                if let fileImportError {
                    Text(fileImportError)
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.red)
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
                fileImportError = nil
                adbManager.installApkFile(url)
            case .failure(let error):
                fileImportError = "File import failed: \(error.localizedDescription)"
            }
        }
    }

    private var scanSection: some View {
        BeamioCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan for APKs")
                    .font(BeamioTheme.subtitleFont(16))

                TextField("https://example.com/downloads", text: $updateURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .beamioTextField()

                Button("Scan URL") {
                    adbManager.scanURL(updateURL) { items in
                        apkItems = items
                        selectedApk = items.first(where: { $0.isPreferred }) ?? items.first
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(updateURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if apkItems.isEmpty {
                    Text("No APKs scanned yet.")
                        .font(BeamioTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(apkItems) { item in
                            Button {
                                selectedApk = item
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(BeamioTheme.subtitleFont(14))
                                        Text(item.url)
                                            .font(BeamioTheme.bodyFont(11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if item.isPreferred {
                                        PillBadge(text: "ARM", color: BeamioTheme.accent)
                                    }
                                    if item == selectedApk {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(BeamioTheme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground).opacity(0.7))
                            )
                        }
                    }

                    Button("Install Selected") {
                        if let selectedApk {
                            adbManager.installApk(from: selectedApk.url)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedApk == nil)
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
    InstallView()
        .environmentObject(ADBManager.shared)
}
