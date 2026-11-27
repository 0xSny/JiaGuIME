import UIKit

struct KeyboardPalette: Equatable {
    let isDark: Bool
    let keyboardBackground: UIColor
    let candidateBarBackground: UIColor
    let keyFill: UIColor
    let keyHighlightedFill: UIColor
    let keyLipShadow: UIColor
    let keyTopHighlight: UIColor
    let funcKeyFill: UIColor
    let funcKeyHighlightedFill: UIColor
    let returnKeyFill: UIColor
    let returnKeyHighlightedFill: UIColor
    let returnKeyText: UIColor
    let primaryText: UIColor
    let secondaryHintText: UIColor
    let swipeHintText: UIColor
    let dividerColor: UIColor
    let popupFill: UIColor
    let popupBorder: UIColor
    let accentColor: UIColor
    let pillFill: UIColor
    let pillText: UIColor

    static let crispLight = KeyboardPalette(
        isDark: false,
        keyboardBackground: UIColor(red: 0.824, green: 0.839, blue: 0.871, alpha: 1.0),
        candidateBarBackground: UIColor(red: 0.945, green: 0.953, blue: 0.969, alpha: 1.0),
        keyFill: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        keyHighlightedFill: UIColor(red: 0.895, green: 0.914, blue: 0.945, alpha: 1.0),
        keyLipShadow: UIColor(red: 0.545, green: 0.569, blue: 0.616, alpha: 0.82),
        keyTopHighlight: UIColor(white: 1.0, alpha: 0.95),
        funcKeyFill: UIColor(red: 0.686, green: 0.710, blue: 0.757, alpha: 1.0),
        funcKeyHighlightedFill: UIColor(red: 0.976, green: 0.980, blue: 0.992, alpha: 1.0),
        returnKeyFill: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0),
        returnKeyHighlightedFill: UIColor(red: 0.055, green: 0.329, blue: 0.725, alpha: 1.0),
        returnKeyText: .white,
        primaryText: UIColor(red: 0.090, green: 0.102, blue: 0.125, alpha: 1.0),
        secondaryHintText: UIColor(red: 0.090, green: 0.102, blue: 0.125, alpha: 0.58),
        swipeHintText: UIColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 0.44),
        dividerColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.10),
        popupFill: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        popupBorder: UIColor(red: 0.65, green: 0.68, blue: 0.74, alpha: 0.45),
        accentColor: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0),
        pillFill: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 0.12),
        pillText: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0)
    )

    static let pureWhite = KeyboardPalette(
        isDark: false,
        keyboardBackground: UIColor(red: 0.957, green: 0.961, blue: 0.973, alpha: 1.0),
        candidateBarBackground: UIColor(red: 0.988, green: 0.990, blue: 0.996, alpha: 1.0),
        keyFill: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        keyHighlightedFill: UIColor(red: 0.922, green: 0.933, blue: 0.957, alpha: 1.0),
        keyLipShadow: UIColor(red: 0.765, green: 0.784, blue: 0.824, alpha: 0.78),
        keyTopHighlight: UIColor(white: 1.0, alpha: 1.0),
        funcKeyFill: UIColor(red: 0.878, green: 0.894, blue: 0.922, alpha: 1.0),
        funcKeyHighlightedFill: UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0),
        returnKeyFill: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0),
        returnKeyHighlightedFill: UIColor(red: 0.055, green: 0.329, blue: 0.725, alpha: 1.0),
        returnKeyText: .white,
        primaryText: UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0),
        secondaryHintText: UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 0.56),
        swipeHintText: UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 0.42),
        dividerColor: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08),
        popupFill: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        popupBorder: UIColor(red: 0.75, green: 0.78, blue: 0.83, alpha: 0.50),
        accentColor: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0),
        pillFill: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 0.10),
        pillText: UIColor(red: 0.086, green: 0.416, blue: 0.878, alpha: 1.0)
    )

    static let dark = KeyboardPalette(
        isDark: true,
        keyboardBackground: UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0),
        candidateBarBackground: UIColor(red: 0.141, green: 0.141, blue: 0.153, alpha: 1.0),
        keyFill: UIColor(red: 0.255, green: 0.255, blue: 0.271, alpha: 1.0),
        keyHighlightedFill: UIColor(red: 0.369, green: 0.369, blue: 0.392, alpha: 1.0),
        keyLipShadow: UIColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 0.88),
        keyTopHighlight: UIColor(white: 1.0, alpha: 0.07),
        funcKeyFill: UIColor(red: 0.184, green: 0.184, blue: 0.196, alpha: 1.0),
        funcKeyHighlightedFill: UIColor(red: 0.290, green: 0.290, blue: 0.310, alpha: 1.0),
        returnKeyFill: UIColor(red: 0.145, green: 0.455, blue: 0.910, alpha: 1.0),
        returnKeyHighlightedFill: UIColor(red: 0.106, green: 0.365, blue: 0.769, alpha: 1.0),
        returnKeyText: .white,
        primaryText: UIColor(red: 0.957, green: 0.961, blue: 0.973, alpha: 1.0),
        secondaryHintText: UIColor(red: 0.957, green: 0.961, blue: 0.973, alpha: 0.60),
        swipeHintText: UIColor(red: 0.957, green: 0.961, blue: 0.973, alpha: 0.42),
        dividerColor: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.11),
        popupFill: UIColor(red: 0.310, green: 0.310, blue: 0.329, alpha: 1.0),
        popupBorder: UIColor(white: 1.0, alpha: 0.14),
        accentColor: UIColor(red: 0.290, green: 0.580, blue: 0.980, alpha: 1.0),
        pillFill: UIColor(red: 0.290, green: 0.580, blue: 0.980, alpha: 0.18),
        pillText: UIColor(red: 0.478, green: 0.718, blue: 1.0, alpha: 1.0)
    )

    static func resolve(mode: AppearanceMode, isDark: Bool) -> KeyboardPalette {
        switch mode {
        case .crispLight: return .crispLight
        case .pureWhite: return .pureWhite
        case .dark: return .dark
        case .followSystem: return isDark ? .dark : .crispLight
        }
    }
}

/// Single owner of the keyboard colour scheme (absorbed from Xiaoxiang IME's proven settling pattern).
/// Merges controller / window / screen traits + host proxy appearance, ignores `.unspecified` readings,
/// and re-evaluates across the XPC app-switch settling window without any permanent background latch.
final class ThemeController {
    enum ResolvedKind: Equatable {
        case crispLight
        case pureWhite
        case dark
    }

    struct Inputs {
        var appearanceMode: AppearanceMode
        var proxyAppearance: UIKeyboardAppearance
        var traits: [UITraitCollection]
    }

    private(set) var kind: ResolvedKind = .crispLight
    private var applied: ResolvedKind?
    private var lastSystemDark: Bool = false
    private var settleToken: Int = 0
    private var lastSettleStart: CFTimeInterval = 0

    private let inputs: () -> Inputs
    private let apply: (KeyboardPalette) -> Void

    init(inputs: @escaping () -> Inputs, apply: @escaping (KeyboardPalette) -> Void) {
        self.inputs = inputs
        self.apply = apply
    }

    var currentPalette: KeyboardPalette {
        ThemeController.palette(for: kind)
    }

    static func palette(for kind: ResolvedKind) -> KeyboardPalette {
        switch kind {
        case .crispLight: return .crispLight
        case .pureWhite: return .pureWhite
        case .dark: return .dark
        }
    }

    func refresh(force: Bool = false) {
        let i = inputs()
        let resolved = resolve(i)
        kind = resolved
        if force || applied != resolved {
            applied = resolved
            apply(ThemeController.palette(for: resolved))
        }
    }

    func refreshSettling(force: Bool = false) {
        refresh(force: force)
        let now = CACurrentMediaTime()
        if !force && (now - lastSettleStart) < 0.5 { return }
        lastSettleStart = now
        settleToken += 1
        let token = settleToken
        for delay in [0.06, 0.25, 0.8, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.settleToken == token else { return }
                self.refresh()
            }
        }
    }

    func cancelSettling() {
        settleToken += 1
    }

    private func resolve(_ i: Inputs) -> ResolvedKind {
        switch i.appearanceMode {
        case .dark:
            return .dark
        case .crispLight:
            return .crispLight
        case .pureWhite:
            return .pureWhite
        case .followSystem:
            let hostDark = (i.proxyAppearance == .dark || i.proxyAppearance == .alert)
            return (hostDark || systemDark(i.traits)) ? .dark : .crispLight
        }
    }

    /// Dark when any determinate trait says dark; `.unspecified` readings are ignored.
    private func systemDark(_ traits: [UITraitCollection]) -> Bool {
        var determinate = false
        var dark = false
        for t in traits where t.userInterfaceStyle != .unspecified {
            determinate = true
            if t.userInterfaceStyle == .dark { dark = true }
        }
        if determinate { lastSystemDark = dark }
        return determinate ? dark : lastSystemDark
    }
}
