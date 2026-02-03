import SwiftUI

struct LogView: View {
    @EnvironmentObject private var adbManager: ADBManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(adbManager.logLines, id: \.self) { line in
                            Text(line)
                                .font(BeamioTheme.monoFont(11))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Logs")
        }
    }
}

#Preview {
    LogView()
        .environmentObject(ADBManager.shared)
}
