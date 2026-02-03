import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        if hasOnboarded {
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
