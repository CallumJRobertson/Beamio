import SwiftUI

struct LogView: View {
    @EnvironmentObject private var adbManager: ADBManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var showCopyConfirmation = false

    private var filteredLogs: [String] {
        var logs = adbManager.logLines

        // Filter out technical ADB protocol messages
        if settings.hideADBLogs {
            logs = logs.filter { line in
                !line.contains("[ADB]")
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return logs }
        return logs.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    if adbManager.logLines.isEmpty {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Logs Yet",
                            message: "Activity logs will appear here as you use the app."
                        )
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, line in
                                        LogLineView(line: line)
                                            .id(index)
                                    }
                                }
                                .padding(16)
                            }
                            .onChange(of: adbManager.logLines.count) { _ in
                                withAnimation {
                                    if let lastIndex = filteredLogs.indices.last {
                                        proxy.scrollTo(lastIndex, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(isOn: $settings.hideADBLogs) {
                            Label("Hide Technical Logs", systemImage: "eye.slash")
                        }

                        Divider()

                        Button {
                            copyLogs()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            clearLogs()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopyConfirmation {
                    Text("Logs copied to clipboard")
                        .font(BeamioTheme.captionFont(13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: showCopyConfirmation)
        }
    }

    private func copyLogs() {
        let text = adbManager.logLines.joined(separator: "\n")
        UIPasteboard.general.string = text

        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyConfirmation = false
        }
    }

    private func clearLogs() {
        adbManager.logLines.removeAll()
    }
}

private struct LogLineView: View {
    let line: String

    private var lineColor: Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("failed") {
            return BeamioTheme.destructive
        }
        if lower.contains("warning") {
            return BeamioTheme.warning
        }
        if lower.contains("connected") || lower.contains("success") || lower.contains("complete") {
            return BeamioTheme.success
        }
        return .primary
    }

    private var timestamp: String? {
        if line.hasPrefix("["), let endIndex = line.firstIndex(of: "]") {
            return String(line[line.startIndex...endIndex])
        }
        return nil
    }

    private var message: String {
        if let timestamp {
            return String(line.dropFirst(timestamp.count)).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let timestamp {
                Text(timestamp)
                    .font(BeamioTheme.monoFont(10))
                    .foregroundColor(.secondary)
            }

            Text(message)
                .font(BeamioTheme.monoFont(11))
                .foregroundColor(lineColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

#Preview {
    LogView()
        .environmentObject(ADBManager.shared)
}
