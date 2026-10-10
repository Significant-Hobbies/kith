import KithCore
import SaaSMakerUI
import SwiftUI
import UIKit

enum KithPalette {
    private static let fieldColor = adaptive(light: rgb(244, 230, 212), dark: rgb(36, 24, 18))
    private static let sheetColor = adaptive(light: rgb(255, 246, 234), dark: rgb(52, 36, 28))
    private static let inkColor = adaptive(light: rgb(58, 36, 24), dark: rgb(255, 242, 226))
    private static let brandColor = adaptive(light: rgb(196, 106, 74), dark: rgb(232, 148, 116))
    static let apricot = adaptive(light: rgb(232, 160, 106), dark: rgb(236, 176, 128))
    static let honey = adaptive(light: rgb(224, 176, 74), dark: rgb(232, 196, 110))
    static let rose = adaptive(light: rgb(212, 122, 120), dark: rgb(228, 150, 146))
    static let rust = adaptive(light: rgb(154, 63, 42), dark: rgb(214, 116, 92))
    static let sand = adaptive(light: rgb(215, 180, 138), dark: rgb(186, 154, 118))
    static let sage = adaptive(light: rgb(139, 154, 109), dark: rgb(164, 178, 136))

    // Gallery supplies the shared roles; Kith keeps its paper, clay and lantern hues.
    static var preset: SMPalette {
        var palette = SMPalette.gallery
        palette.background = fieldColor
        palette.surface = sheetColor
        palette.card = sheetColor
        palette.foreground = inkColor
        palette.primary = inkColor
        palette.mutedForeground = inkColor.opacity(0.62)
        palette.destructive = rust
        palette.success = sage
        palette.warning = honey
        palette.hairline = .clear
        palette.displayWeight = 600
        palette.textFont = palette.sansFont
        palette.textSerif = false
        return palette
    }

    static var theme: SMPalette { preset.brand(brandColor, foreground: .white) }
    static var linen: Color { theme.background }
    static var cream: Color { theme.card }
    static var espresso: Color { theme.foreground }
    static var clay: Color { theme.brand }

    static func fill(for hue: PersonHue) -> Color {
        switch hue {
        case .clay: clay
        case .apricot: apricot
        case .honey: honey
        case .rose: rose
        case .rust: rust
        case .sand: sand
        case .sage: sage
        }
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct KithBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(KithType.body)
            .foregroundStyle(KithPalette.espresso)
            .background(KithPalette.linen.ignoresSafeArea())
            .tint(KithPalette.clay)
    }
}

extension View {
    func kithBackground() -> some View { modifier(KithBackground()) }

    // Keep the existing navigation accessibility title while rendering Fleet's UI voice.
    func kithNavigationTitle(_ title: String, displayTitle: String? = nil) -> some View {
        navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(displayTitle ?? (title == "Kith" ? title : title.lowercased()))
                        .font(KithType.headline)
                        .accessibilityLabel(title)
                }
            }
    }
}

// SMType.font is internal to the package; use its bundled families with native
// relative text styles so every role scales with Dynamic Type.
enum KithType {
    static let largeTitle = Font.custom(KithPalette.theme.displayFont, size: 34, relativeTo: .largeTitle).weight(.semibold)
    static let title2 = Font.custom(KithPalette.theme.displayFont, size: 22, relativeTo: .title2).weight(.semibold)
    static let title3 = Font.custom(KithPalette.theme.displayFont, size: 20, relativeTo: .title3).weight(.semibold)
    static let headline = Font.custom(KithPalette.theme.sansFont, size: 17, relativeTo: .headline).weight(.semibold)
    static let body = Font.custom(KithPalette.theme.sansFont, size: 17, relativeTo: .body)
    static let subheadline = Font.custom(KithPalette.theme.sansFont, size: 15, relativeTo: .subheadline)
    static let footnote = Font.custom(KithPalette.theme.sansFont, size: 13, relativeTo: .footnote)
    static let caption = Font.custom(KithPalette.theme.sansFont, size: 12, relativeTo: .caption)
}

struct ClosenessRow: View {
    @Binding var value: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(1...5, id: \.self) { step in
                Button {
                    value = step
                } label: {
                    Circle()
                        .fill(step <= value ? KithPalette.clay : KithPalette.espresso.opacity(0.12))
                        .frame(width: 10 + CGFloat(step) * 6, height: 10 + CGFloat(step) * 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Closeness \(step)")
                .accessibilityAddTraits(step == value ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Closeness")
        .accessibilityValue("\(value) of 5")
    }
}

struct HueRow: View {
    @Binding var hue: PersonHue

    var body: some View {
        HStack(spacing: 10) {
            ForEach(PersonHue.allCases, id: \.self) { option in
                Button {
                    hue = option
                } label: {
                    Circle()
                        .fill(KithPalette.fill(for: option))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if option == hue {
                                Circle().stroke(KithPalette.espresso, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(option == hue ? .isSelected : [])
            }
        }
    }
}

struct LanternView: View {
    var person: Person
    var diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(KithPalette.fill(for: person.hue))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 2,
                        endRadius: diameter * 0.62
                    )
                )
            VStack(spacing: diameter > 90 ? 4 : 1) {
                Text(person.initials)
                    .font(.system(size: max(14, diameter * 0.22), weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.94))
                if diameter >= 80 {
                    Text(person.firstName)
                        .font(.system(size: max(11, diameter * 0.12), weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: KithPalette.fill(for: person.hue).opacity(0.35), radius: 10, y: 6)
    }
}
