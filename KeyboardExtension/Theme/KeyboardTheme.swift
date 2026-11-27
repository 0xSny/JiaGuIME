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

/// 5-Layer Dark Mode App-Switch Defense:
/// Prevents iOS multitasking snapshotter's `.light` background trait pass from poisoning
/// extension CALayers, and reconciles multi-source traits across XPC resume delays.
final class AppearanceMonitor {
    private(set) var isHostForeground: Bool = true
    private(set) var didBackgroundDuringSession: Bool = false
    private(set) var wasDarkBeforeBackground: Bool = false
    private(set) var lastKnownForegroundDark: Bool = false
    private(set) var lastForegroundResumeTime: CFTimeInterval = 0
    private var resumeWorkItems: [DispatchWorkItem] = []

    func markResignActive() {
        isHostForeground = false
        wasDarkBeforeBackground = wasDarkBeforeBackground || lastKnownForegroundDark
        cancelResumeTicks()
    }

    func markDidEnterBackground() {
        markResignActive()
        didBackgroundDuringSession = true
    }

    func markKeyboardDismissed() {
        didBackgroundDuringSession = false
        wasDarkBeforeBackground = false
        cancelResumeTicks()
    }

    func markBecomeActive(onTick: @escaping (_ forceRepaint: Bool) -> Void) {
        isHostForeground = true
        lastForegroundResumeTime = CACurrentMediaTime()
        onTick(true)
        scheduleResumeTicks(onTick: onTick)
    }

    func cancelResumeTicks() {
        for item in resumeWorkItems {
            item.cancel()
        }
        resumeWorkItems.removeAll()
    }

    private func scheduleResumeTicks(onTick: @escaping (_ forceRepaint: Bool) -> Void) {
        cancelResumeTicks()
        let delays: [TimeInterval] = [0.05, 0.16, 0.35, 0.70]
        for delay in delays {
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isHostForeground else { return }
                onTick(true)
            }
            resumeWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    func resolveIsDark(mode: AppearanceMode,
                       viewController: UIInputViewController,
                       rootView: UIView,
                       previousTraitStyle: UIUserInterfaceStyle? = nil) -> Bool {
        switch mode {
        case .crispLight, .pureWhite:
            return false
        case .dark:
            return true
        case .followSystem:
            break
        }

        // Never allow background snapshotter to downgrade dark -> light
        if !isHostForeground {
            return lastKnownForegroundDark
        }

        // Genuine live foreground Dark -> Light toggle (e.g. Control Center) clears background lock
        if previousTraitStyle == .dark &&
            viewController.traitCollection.userInterfaceStyle == .light &&
            (CACurrentMediaTime() - lastForegroundResumeTime) > 0.25 {
            didBackgroundDuringSession = false
            wasDarkBeforeBackground = false
        }

        let proxy = viewController.textDocumentProxy.keyboardAppearance
        let windowStyle = rootView.window?.traitCollection.userInterfaceStyle ?? .unspecified
        let sceneStyle = rootView.window?.windowScene?.traitCollection.userInterfaceStyle ?? .unspecified
        let viewStyle = rootView.traitCollection.userInterfaceStyle
        let vcStyle = viewController.traitCollection.userInterfaceStyle
        let screenStyle = (rootView.window?.windowScene?.screen ?? UIScreen.main).traitCollection.userInterfaceStyle
        let currentStyle = UITraitCollection.current.userInterfaceStyle

        let anyDarkSignal = (proxy == .dark ||
                             windowStyle == .dark ||
                             sceneStyle == .dark ||
                             viewStyle == .dark ||
                             vcStyle == .dark ||
                             screenStyle == .dark ||
                             currentStyle == .dark)

        let resolved: Bool
        switch proxy {
        case .dark:
            resolved = true
        case .light:
            if anyDarkSignal {
                resolved = true
            } else if didBackgroundDuringSession && wasDarkBeforeBackground &&
                        (CACurrentMediaTime() - lastForegroundResumeTime) < 0.8 {
                resolved = true
            } else {
                resolved = false
            }
        case .default, .alert:
            fallthrough
        @unknown default:
            if anyDarkSignal {
                resolved = true
            } else if didBackgroundDuringSession && wasDarkBeforeBackground {
                resolved = true
            } else if windowStyle == .unspecified && viewStyle == .unspecified && vcStyle == .unspecified {
                resolved = lastKnownForegroundDark
            } else {
                resolved = false
            }
        }

        lastKnownForegroundDark = resolved
        return resolved
    }
}
