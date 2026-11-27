import UIKit

final class HapticFeedbackEngine {
    private var rigidGenerator: UIImpactFeedbackGenerator?
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?

    func prepare() {
        if rigidGenerator == nil {
            rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
        }
        if lightGenerator == nil {
            lightGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        if mediumGenerator == nil {
            mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        }
        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        rigidGenerator?.prepare()
        lightGenerator?.prepare()
        mediumGenerator?.prepare()
        selectionGenerator?.prepare()
    }

    func triggerKeyTap(level: HapticLevel) {
        switch level {
        case .off:
            return
        case .light:
            let g = lightGenerator ?? UIImpactFeedbackGenerator(style: .light)
            lightGenerator = g
            g.impactOccurred(intensity: 0.65)
            g.prepare()
        case .crisp:
            let g = rigidGenerator ?? UIImpactFeedbackGenerator(style: .rigid)
            rigidGenerator = g
            g.impactOccurred(intensity: 0.85)
            g.prepare()
        case .strong:
            let g = mediumGenerator ?? UIImpactFeedbackGenerator(style: .medium)
            mediumGenerator = g
            g.impactOccurred(intensity: 1.0)
            g.prepare()
        }
    }

    func triggerCursorTick(level: HapticLevel) {
        guard level != .off else { return }
        let g = selectionGenerator ?? UISelectionFeedbackGenerator()
        selectionGenerator = g
        g.selectionChanged()
        g.prepare()
    }
}
