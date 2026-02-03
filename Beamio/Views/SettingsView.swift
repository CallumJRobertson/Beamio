import SwiftUI

struct SettingsView: View {
    @AppStorage("fireTVIP") private var fireTVIP: String = ""
    @AppStorage("updateURL") private var updateURL: String = ""

    private var isValidIP: Bool {
        let pattern = "^(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)){3}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: fireTVIP)
    }

    var body: some View {
        Form {
            Section("Fire TV IP Address") {
                TextField("192.168.0.10", text: $fireTVIP)
                    .keyboardType(.decimalPad)

                HStack {
                    Image(systemName: isValidIP ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundColor(isValidIP ? .green : .orange)
                    Text(isValidIP ? "Valid IP address" : "Enter a valid IPv4 address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Update Source URL") {
                TextField("https://example.com/downloads", text: $updateURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("This URL is provided by you and is not hardcoded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
