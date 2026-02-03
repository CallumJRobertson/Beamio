import SwiftUI

struct SettingsView: View {
    @AppStorage("fireTVIP") private var fireTVIP: String = ""
    @AppStorage("updateURL") private var updateURL: String = ""

    private var isValidIP: Bool {
        let ip = "(25[0-5]|2[0-4]\\\\d|1\\\\d{2}|[1-9]?\\\\d)"
        let pattern = "^\(ip)(\\\\.\(ip)){3}(:[0-9]{1,5})?$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: fireTVIP)
    }

    var body: some View {
        Form {
            Section("Device IP Address") {
                TextField("192.168.0.10:5555", text: $fireTVIP)
                    .keyboardType(.decimalPad)

                HStack {
                    Image(systemName: isValidIP ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundColor(isValidIP ? .green : .orange)
                    Text(isValidIP ? "Valid IP address" : "Enter a valid IPv4 address (optionally with :port)")
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
