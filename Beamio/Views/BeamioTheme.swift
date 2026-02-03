import SwiftUI

enum BeamioTheme {
    // MARK: - Colors
    static let accent = Color(red: 0.0, green: 0.48, blue: 1.0) // Apple Blue
    static let accentSoft = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.12)
    static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // Orange
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35) // Green
    static let destructive = Color(red: 1.0, green: 0.27, blue: 0.23) // Red
    static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let teal = Color(red: 0.35, green: 0.78, blue: 0.98)

    // MARK: - Fonts (SF Pro style using system fonts)
    static func titleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func subtitleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func bodyFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func monoFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    static func captionFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    // MARK: - Spacing
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16

    // MARK: - Shadows
    static let shadowColor = Color.black.opacity(0.08)
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 4
}

// MARK: - Background

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BeamioTheme.accent.opacity(colorScheme == .dark ? 0.15 : 0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.6
                        )
                    )
                    .frame(width: geometry.size.width * 1.2, height: geometry.size.width * 1.2)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.15)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                BeamioTheme.purple.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width * 0.5
                        )
                    )
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .offset(x: geometry.size.width * 0.4, y: geometry.size.height * 0.5)
            }
        }
    }
}

// MARK: - Cards

struct BeamioCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(BeamioTheme.spacing)
            .background(
                RoundedRectangle(cornerRadius: BeamioTheme.cardCornerRadius)
                    .fill(Color(uiColor: colorScheme == .dark ? .secondarySystemGroupedBackground : .systemBackground))
                    .shadow(
                        color: BeamioTheme.shadowColor,
                        radius: BeamioTheme.shadowRadius,
                        x: 0,
                        y: BeamioTheme.shadowY
                    )
            )
    }
}

struct BeamioSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BeamioTheme.captionFont(13))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            content
        }
    }
}

// MARK: - Badges

struct PillBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(BeamioTheme.captionFont(11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    var activeColor: Color = BeamioTheme.success
    var inactiveColor: Color = BeamioTheme.warning
    var size: CGFloat = 10
    var showPulse: Bool = true

    var body: some View {
        ZStack {
            if isActive && showPulse {
                Circle()
                    .fill(activeColor.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(isActive ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isActive)
            }

            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeamioTheme.subtitleFont(15))
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: BeamioTheme.cornerRadius)
                    .fill(BeamioTheme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.4))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeamioTheme.subtitleFont(14))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: BeamioTheme.cornerRadius)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .foregroundColor(isEnabled ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BeamioTheme.subtitleFont(14))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: BeamioTheme.cornerRadius)
                    .fill(BeamioTheme.destructive.opacity(configuration.isPressed ? 0.8 : 0.12))
            )
            .foregroundColor(BeamioTheme.destructive)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct RemoteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct RemotePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(BeamioTheme.accent.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Text Field Style

struct BeamioTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: BeamioTheme.cornerRadius)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
    }
}

extension View {
    func beamioTextField() -> some View {
        modifier(BeamioTextFieldStyle())
    }
}

// MARK: - List Row Style

struct ListRowStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: colorScheme == .dark ? .tertiarySystemBackground : .secondarySystemBackground))
            )
    }
}

extension View {
    func listRowStyle() -> some View {
        modifier(ListRowStyle())
    }
}

// MARK: - Loading Indicator

struct LoadingSpinner: View {
    var size: CGFloat = 20
    var color: Color = BeamioTheme.accent

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: color))
            .scaleEffect(size / 20)
    }
}

// MARK: - Icon Placeholder with Loading

struct IconPlaceholder: View {
    let letter: String
    var isLoading: Bool = false
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(
                    LinearGradient(
                        colors: [
                            BeamioTheme.accentSoft,
                            BeamioTheme.accentSoft.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: BeamioTheme.accent))
                    .scaleEffect(0.8)
            } else {
                Text(letter)
                    .font(BeamioTheme.subtitleFont(size * 0.35))
                    .foregroundColor(BeamioTheme.accent.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 6) {
                Text(title)
                    .font(BeamioTheme.subtitleFont(17))

                Text(message)
                    .font(BeamioTheme.bodyFont(14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - Header View

struct PageHeader: View {
    let title: String
    let subtitle: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BeamioTheme.accent, BeamioTheme.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BeamioTheme.titleFont(28))

                Text(subtitle)
                    .font(BeamioTheme.bodyFont(14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Divider

struct BeamioDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
    }
}
