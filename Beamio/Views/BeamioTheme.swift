import SwiftUI

enum BeamioTheme {
    static let accent = Color(red: 0.15, green: 0.55, blue: 0.92)
    static let accentSoft = Color(red: 0.15, green: 0.55, blue: 0.92).opacity(0.18)
    static let warning = Color(red: 0.95, green: 0.68, blue: 0.28)
    static let success = Color(red: 0.22, green: 0.72, blue: 0.45)

    static func titleFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size).weight(.semibold)
    }

    static func subtitleFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size).weight(.medium)
    }

    static func bodyFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size)
    }

    static func monoFont(_ size: CGFloat) -> Font {
        .custom("Menlo", size: size)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(BeamioTheme.accent.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 40)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.orange.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 35)
                .offset(x: 160, y: 220)
        }
    }
}

struct BeamioCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct PillBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(BeamioTheme.bodyFont(11))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeamioTheme.subtitleFont(15))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BeamioTheme.accent.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .foregroundColor(.white)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeamioTheme.subtitleFont(14))
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground).opacity(configuration.isPressed ? 0.6 : 0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(.primary)
    }
}

struct BeamioTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func beamioTextField() -> some View {
        modifier(BeamioTextFieldStyle())
    }
}
