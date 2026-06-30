import SwiftUI

enum Geist {
    enum Colors {
        static let primary = Color(light: "#171717", dark: "#ededed")
        static let secondary = Color(light: "#4d4d4d", dark: "#aaa9a6")
        static let disabled = Color(light: "#8f8f8f", dark: "#8f8f8f")
        static let background = Color(light: "#f3f3f080", dark: "#30302f8c")
        static let backgroundSecondary = Color(light: "#ffffff42", dark: "#202524a6")
        static let neutral = Color(light: "#00000016", dark: "#ffffff20")
        static let border = Color(light: "#0000001f", dark: "#ffffff24")
        static let borderHover = Color(light: "#0000003d", dark: "#ffffff42")
        static let separator = Color(light: "#ffffff66", dark: "#ffffff1a")
        static let overlay = Color(light: "#ffffff30", dark: "#ffffff10")
        static let highlight = Color(light: "#ffffff99", dark: "#ffffff24")
        static let shadow = Color(light: "#0000002e", dark: "#00000059")
        static let blue = Color(light: "#006bff", dark: "#1e91ff")
        static let red = Color(light: "#ea001d", dark: "#e2162a")
        static let amber = Color(light: "#aa4d00", dark: "#ff9300")
        static let green = Color(light: "#28a948", dark: "#00ca50")
        static let teal = Color(light: "#00ac96", dark: "#00cfb7")
    }

    enum Spacing {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let full: CGFloat = 9999
    }

    enum Fonts {
        static let heading24 = sans(size: 24, weight: .semibold)
        static let heading20 = sans(size: 20, weight: .semibold)
        static let heading16 = sans(size: 16, weight: .semibold)
        static let heading14 = sans(size: 14, weight: .semibold)
        static let label14 = sans(size: 14, weight: .regular)
        static let label13 = sans(size: 13, weight: .regular)
        static let label12 = sans(size: 12, weight: .regular)
        static let button14 = sans(size: 14, weight: .medium)
        static let button12 = sans(size: 12, weight: .medium)
        static let mono24 = mono(size: 24, weight: .semibold)
        static let mono20 = mono(size: 20, weight: .semibold)
        static let mono14 = mono(size: 14, weight: .medium)
        static let mono12 = mono(size: 12, weight: .regular)

        private static func sans(size: CGFloat, weight: Font.Weight) -> Font {
            Font.custom("Geist", size: size).weight(weight)
        }

        private static func mono(size: CGFloat, weight: Font.Weight) -> Font {
            Font.custom("Geist Mono", size: size).weight(weight)
        }
    }
}

extension Color {
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        switch hex.count {
        case 8:
            red = CGFloat((value >> 24) & 0xff) / 255
            green = CGFloat((value >> 16) & 0xff) / 255
            blue = CGFloat((value >> 8) & 0xff) / 255
            alpha = CGFloat(value & 0xff) / 255
        default:
            red = CGFloat((value >> 16) & 0xff) / 255
            green = CGFloat((value >> 8) & 0xff) / 255
            blue = CGFloat(value & 0xff) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct GeistPanel: ViewModifier {
    var padding: CGFloat = Geist.Spacing.x4
    var radius: CGFloat = Geist.Radius.medium

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Geist.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Geist.Colors.border, lineWidth: 1)
            )
            .shadow(color: Geist.Colors.shadow, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func geistPanel(padding: CGFloat = Geist.Spacing.x4, radius: CGFloat = Geist.Radius.medium) -> some View {
        modifier(GeistPanel(padding: padding, radius: radius))
    }
}

struct GeistButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case tertiary
        case icon
    }

    var kind: Kind = .secondary
    var height: CGFloat = 32

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(height <= 32 ? Geist.Fonts.button12 : Geist.Fonts.button14)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, kind == .icon ? 0 : (height <= 32 ? 8 : 10))
            .frame(minWidth: kind == .icon ? height : nil, minHeight: height)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: kind == .primary ? 0 : 1)
            )
            .opacity(isEnabled ? 1 : 0.58)
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return Geist.Colors.disabled
        }

        switch kind {
        case .primary:
            return Geist.Colors.background
        case .secondary, .tertiary, .icon:
            return Geist.Colors.primary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Geist.Colors.neutral
        }

        switch kind {
        case .primary:
            return Geist.Colors.primary
        case .secondary, .icon:
            return isPressed ? Geist.Colors.neutral.opacity(0.82) : Geist.Colors.neutral
        case .tertiary:
            return isPressed ? Geist.Colors.overlay : .clear
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return Geist.Colors.border
        }

        switch kind {
        case .primary, .tertiary:
            return .clear
        case .secondary, .icon:
            return isPressed ? Geist.Colors.borderHover : Geist.Colors.border
        }
    }
}

struct GeistStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Geist.Spacing.x2) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 7, height: 7)

            Text(text)
                .font(Geist.Fonts.label12)
                .foregroundStyle(Geist.Colors.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, Geist.Spacing.x2)
        .frame(height: 24)
        .background(Geist.Colors.neutral)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }
}
