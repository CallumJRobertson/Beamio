import SwiftUI

struct LogView: View {
    @EnvironmentObject private var pythonManager: PythonManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pythonManager.logLines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Logs")
        }
    }
}

#Preview {
    LogView()
        .environmentObject(PythonManager.shared)
}
