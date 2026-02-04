import SwiftUI

struct RootView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        if settings.hasOnboarded {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ADBManager.shared)
}
