import UIKit

struct SpatialTouchSample {
    let primary: Character
    let alt1: Character?
    let alt1LogProb: Float
    let alt2: Character?
    let alt2LogProb: Float
}

protocol KeyCanvasDelegate: AnyObject {
    func keyCanvasWillBeginInteraction()
    func keyCanvasDidTapLetter(_ sample: SpatialTouchSample)
    func keyCanvasDidTapSwipeSymbol(_ symbol: String)
    func keyCanvasDidTapSpace(isDoubleSpace: Bool)
    func keyCanvasDidMoveSpaceCursor(steps: Int)
    func keyCanvasDidTapBackspace()
    func keyCanvasDidSwipeLeftBackspaceClear()
    func keyCanvasDidTapSeparator(_ symbol: String)
    func keyCanvasDidTapShift()
    func keyCanvasDidDoubleTapShift()
    func keyCanvasDidTapModeSwitch123()
    func keyCanvasDidTapLangSwitch()
    func keyCanvasDidTapEnter()
}

final class KeyCanvasView: UIView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }

    weak var delegate: KeyCanvasDelegate?

    private(set) var layoutSpec: KeyboardLayoutSpec
    private var palette: KeyboardPalette = .crispLight
    private var settings: IMESettings = IMESettings()
    private var nextLetterMask: UInt32 = (1 << 26) - 1
    private var isEnglishMode = false
    private var isShiftActive = false
    private var isCapsLock = false
    private var isComposing = false
    private var returnTitle = "换行"

    private let keysLayer = CALayer()
    private let popupOverlay = KeyPopupOverlay()
    private var keySublayers: [String: CALayer] = [:]

    // Deterministic raw-touch FSM state
    private struct ActiveTouch {
        let touch: UITouch
        var slot: KeySlot
        let startPoint: CGPoint
        var currentPoint: CGPoint
        let startTime: CFTimeInterval
        var isSwipingUp: Bool = false
        var isSpaceTracking: Bool = false
        var spaceAccumulatedX: CGFloat = 0
        var didClearByLeftSwipe: Bool = false
        var settled: Bool = false
    }

    private var activeTouches: [ObjectIdentifier: ActiveTouch] = [:]
    private var highlightedKeyId: String?
    private var highlightShownAt: CFTimeInterval = 0
    private var pendingHideHighlightWork: DispatchWorkItem?
    private var pendingHidePopupWork: DispatchWorkItem?

    private var lastSpaceTapTime: CFTimeInterval = 0
    private var lastShiftTapTime: CFTimeInterval = 0

    // Backspace accelerated repeat
    private var backspaceTimer: DispatchSourceTimer?
    private var backspaceRepeatCount: Int = 0

    private let haptics = HapticFeedbackEngine()
    private let soundEngine = KeySoundEngine()

    override init(frame: CGRect) {
        self.layoutSpec = KeyboardLayoutSpec(totalSize: frame.size, keys: [], letterSlots: [], scale: UIScreen.main.scale)
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        clipsToBounds = false
        layer.actions = ["sublayers": NSNull(), "bounds": NSNull(), "position": NSNull()]
        keysLayer.actions = ["sublayers": NSNull(), "bounds": NSNull(), "position": NSNull()]

        layer.addSublayer(keysLayer)
        addSubview(popupOverlay)
        haptics.prepare()
        soundEngine.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateState(settings: IMESettings,
                     palette: KeyboardPalette,
                     isEnglish: Bool,
                     isShiftActive: Bool,
                     isCapsLock: Bool,
                     isComposing: Bool,
                     returnTitle: String,
                     nextLetterMask: UInt32) {
        let needsRebuild = (self.settings.oneHandedMode != settings.oneHandedMode ||
                            self.settings.shuangpinHintMode != settings.shuangpinHintMode ||
                            self.settings.inputMode != settings.inputMode ||
                            self.settings.swipeUpSymbolsEnabled != settings.swipeUpSymbolsEnabled ||
                            self.isEnglishMode != isEnglish ||
                            self.isShiftActive != isShiftActive ||
                            self.isCapsLock != isCapsLock ||
                            self.isComposing != isComposing ||
                            self.returnTitle != returnTitle ||
                            self.palette != palette)

        self.settings = settings
        self.palette = palette
        self.isEnglishMode = isEnglish
        self.isShiftActive = isShiftActive
        self.isCapsLock = isCapsLock
        self.isComposing = isComposing
        self.returnTitle = returnTitle
        self.nextLetterMask = nextLetterMask

        popupOverlay.applyPalette(palette)
        if needsRebuild {
            rebuildLayoutAndLayers()
        }
    }

    func forceRepaint(palette: KeyboardPalette) {
        self.palette = palette
        popupOverlay.applyPalette(palette)
        rebuildLayoutAndLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        keysLayer.frame = bounds
        CATransaction.commit()
        rebuildLayoutAndLayers()
    }

    private func rebuildLayoutAndLayers() {
        guard bounds.width > 40, bounds.height > 40 else { return }
        let showHints = (settings.inputMode == .xiaoheShuangpin && settings.shuangpinHintMode != .hidden)
        layoutSpec = KeyboardLayoutSpec.build(
            boundsSize: bounds.size,
            scale: window?.screen.scale ?? UIScreen.main.scale,
            oneHanded: settings.oneHandedMode,
            isEnglish: isEnglishMode,
            isShiftActive: isShiftActive,
            isCapsLock: isCapsLock,
            isComposing: isComposing,
            returnTitle: returnTitle,
            showXiaoheHints: showHints
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        keysLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        keySublayers.removeAll(keepingCapacity: true)

        let scale = layoutSpec.scale
        let radius: CGFloat = 5.5

        for slot in layoutSpec.keys {
            let container = CALayer()
            container.frame = slot.frame
            container.cornerRadius = radius

            let isHighlighted = (slot.id == highlightedKeyId)
            let fillColor: UIColor
            if slot.kind == .enter {
                fillColor = isHighlighted ? palette.returnKeyHighlightedFill : palette.returnKeyFill
            } else if slot.isFunctionKey {
                let activeShift = (slot.kind == .shift && (isShiftActive || isCapsLock))
                fillColor = (isHighlighted || activeShift) ? palette.funcKeyHighlightedFill : palette.funcKeyFill
            } else {
                fillColor = isHighlighted ? palette.keyHighlightedFill : palette.keyFill
            }

            // 1pt bottom lip shadow
            let lip = CALayer()
            lip.frame = CGRect(x: 0, y: 1.0, width: slot.frame.width, height: slot.frame.height)
            lip.cornerRadius = radius
            lip.backgroundColor = palette.keyLipShadow.cgColor
            container.addSublayer(lip)

            // Main keycap face
            let face = CALayer()
            face.frame = CGRect(x: 0, y: 0, width: slot.frame.width, height: slot.frame.height)
            face.cornerRadius = radius
            face.backgroundColor = fillColor.cgColor
            face.borderWidth = 1.0 / scale
            face.borderColor = palette.keyTopHighlight.cgColor
            container.addSublayer(face)

            renderKeyLabels(slot: slot, onto: face, scale: scale)

            keysLayer.addSublayer(container)
            keySublayers[slot.id] = container
        }
        CATransaction.commit()
    }

    private func renderKeyLabels(slot: KeySlot, onto face: CALayer, scale: CGFloat) {
        let w = slot.frame.width
        let h = slot.frame.height

        switch slot.kind {
        case .letter(let ch):
            let hint = slot.xiaoheHint
            let showXiaohe = (hint != nil && settings.inputMode == .xiaoheShuangpin && settings.shuangpinHintMode != .hidden)
            let isRow0 = "qwertyuiop".contains(ch)

            // Anti-clutter: when Xiaohe hints are displayed, hide secondary punctuation corners on rows 1-2,
            // keeping only ultra-subtle digit hints on row 0.
            if settings.swipeUpSymbolsEnabled, let sym = slot.swipeUpSymbol, (!showXiaohe || isRow0) {
                let symLayer = CATextLayer()
                symLayer.contentsScale = scale
                symLayer.font = UIFont.systemFont(ofSize: 9.5, weight: .medium)
                symLayer.fontSize = 9.5
                symLayer.foregroundColor = palette.swipeHintText.cgColor
                symLayer.alignmentMode = .right
                symLayer.string = sym
                symLayer.frame = CGRect(x: 2, y: 2.0, width: w - 5.0, height: 11.0)
                face.addSublayer(symLayer)
            }

            if showXiaohe, let hint {
                // Upper-middle main letter (2pt smaller for clean vertical room)
                let mainFontSize: CGFloat = w < 31 ? 16.5 : 18.5
                let mainLayer = CATextLayer()
                mainLayer.contentsScale = scale
                mainLayer.font = UIFont.systemFont(ofSize: mainFontSize, weight: .regular)
                mainLayer.fontSize = mainFontSize
                mainLayer.foregroundColor = palette.primaryText.cgColor
                mainLayer.alignmentMode = .center
                mainLayer.string = slot.primaryLabel
                let mainY = h * 0.12
                mainLayer.frame = CGRect(x: 0, y: mainY, width: w, height: mainFontSize + 3.0)
                face.addSublayer(mainLayer)

                // Optional sh/ch/zh initial badge on U/I/V (in .full mode)
                if settings.shuangpinHintMode == .full, let initHint = hint.initialHint {
                    let badge = CATextLayer()
                    badge.contentsScale = scale
                    badge.font = UIFont.systemFont(ofSize: 8.5, weight: .semibold)
                    badge.fontSize = 8.5
                    badge.foregroundColor = palette.accentColor.withAlphaComponent(0.85).cgColor
                    badge.alignmentMode = .left
                    badge.string = initHint
                    badge.frame = CGRect(x: 3.0, y: 2.5, width: w - 6.0, height: 10.0)
                    face.addSublayer(badge)
                }

                // Bottom Shuangpin finals with >= 3pt side safe inset & compact 2-line stacking for dual finals
                let safeW = max(12.0, w - 6.0)
                if hint.finals.count == 1 {
                    let fText = hint.finals[0]
                    let fSize: CGFloat = (fText.count >= 3 && w < 33) ? 8.5 : 9.5
                    let fLayer = CATextLayer()
                    fLayer.contentsScale = scale
                    fLayer.font = UIFont.systemFont(ofSize: fSize, weight: .medium)
                    fLayer.fontSize = fSize
                    fLayer.foregroundColor = palette.secondaryHintText.cgColor
                    fLayer.alignmentMode = .center
                    fLayer.string = fText
                    fLayer.frame = CGRect(x: 3.0, y: h - 14.5, width: safeW, height: 12.0)
                    face.addSublayer(fLayer)
                } else if hint.finals.count >= 2 {
                    let stacked = "\(hint.finals[0])\n\(hint.finals[1])"
                    let maxLen = max(hint.finals[0].count, hint.finals[1].count)
                    let fSize: CGFloat = (maxLen >= 4) ? (w < 33 ? 7.0 : 7.8) : (w < 33 ? 7.8 : 8.5)
                    let fLayer = CATextLayer()
                    fLayer.contentsScale = scale
                    fLayer.font = UIFont.systemFont(ofSize: fSize, weight: .medium)
                    fLayer.fontSize = fSize
                    fLayer.foregroundColor = palette.secondaryHintText.cgColor
                    fLayer.alignmentMode = .center
                    fLayer.isWrapped = true
                    fLayer.string = stacked
                    fLayer.frame = CGRect(x: 3.0, y: h - 21.0, width: safeW, height: 19.5)
                    face.addSublayer(fLayer)
                }
            } else {
                // Clean standard letter
                let mainFontSize: CGFloat = w < 31 ? 19.5 : 22.0
                let mainLayer = CATextLayer()
                mainLayer.contentsScale = scale
                mainLayer.font = UIFont.systemFont(ofSize: mainFontSize, weight: .regular)
                mainLayer.fontSize = mainFontSize
                mainLayer.foregroundColor = palette.primaryText.cgColor
                mainLayer.alignmentMode = .center
                mainLayer.string = slot.primaryLabel
                mainLayer.frame = CGRect(x: 0, y: (h - mainFontSize * 1.18) * 0.5, width: w, height: mainFontSize * 1.25)
                face.addSublayer(mainLayer)
            }

        default:
            let fontSize: CGFloat
            switch slot.kind {
            case .enter, .langSwitch, .modeSwitch:
                fontSize = 14.5
            case .space:
                fontSize = 15.0
            case .backspace, .shift:
                fontSize = 18.0
            case .separator:
                fontSize = slot.primaryLabel.count > 1 ? 13.5 : 18.0
            case .letter:
                fontSize = 20.0
            }
            let lbl = CATextLayer()
            lbl.contentsScale = scale
            lbl.font = UIFont.systemFont(ofSize: fontSize, weight: slot.kind == .enter ? .semibold : .regular)
            lbl.fontSize = fontSize
            lbl.foregroundColor = (slot.kind == .enter ? palette.returnKeyText : palette.primaryText).cgColor
            lbl.alignmentMode = .center
            lbl.string = slot.primaryLabel
            lbl.frame = CGRect(x: 2, y: (h - fontSize * 1.22) * 0.5, width: w - 4, height: fontSize * 1.3)
            face.addSublayer(lbl)
        }
    }

    // MARK: - Voronoi & 2D Gaussian Spatial Hit-Testing

    private func hitTestSlot(at point: CGPoint) -> KeySlot? {
        // 1. Direct containment check first for speed
        for slot in layoutSpec.keys {
            if slot.frame.contains(point) {
                return slot
            }
        }
        // 2. Voronoi zero-dead-zone nearest neighbor (modulated gently by prefix prior for letters)
        var bestSlot: KeySlot?
        var bestScore = CGFloat.greatestFiniteMagnitude
        let isXiaohe = (settings.inputMode == .xiaoheShuangpin)
        let priorBias: CGFloat = isXiaohe ? 2.5 : 5.0

        for slot in layoutSpec.keys {
            let dx = max(0, max(slot.frame.minX - point.x, point.x - slot.frame.maxX))
            let dy = max(0, max(slot.frame.minY - point.y, point.y - slot.frame.maxY))
            var distSq = dx * dx + dy * dy
            if case .letter(let ch) = slot.kind, !isEnglishMode, let ascii = ch.asciiValue, ascii >= 97, ascii <= 122 {
                let bit = UInt32(1) << (ascii - 97)
                if (nextLetterMask & bit) != 0 {
                    distSq = max(0, distSq - priorBias)
                }
            }
            if distSq < bestScore {
                bestScore = distSq
                bestSlot = slot
            }
        }
        return bestSlot
    }

    private func makeSpatialSample(primary: Character, at point: CGPoint) -> SpatialTouchSample {
        let isXiaohe = (settings.inputMode == .xiaoheShuangpin)
        let unitW = layoutSpec.letterSlots.first?.frame.width ?? 32.0
        let sigma = unitW * (isXiaohe ? 0.42 : 0.58)
        let twoSigmaSq = Float(2.0 * sigma * sigma)

        var candidates: [(Character, Float)] = []
        candidates.reserveCapacity(8)
        for slot in layoutSpec.letterSlots {
            guard case .letter(let ch) = slot.kind else { continue }
            if ch == primary { continue }
            let dx = Float(point.x - slot.center.x)
            let dy = Float(point.y - slot.center.y)
            let distSq = dx * dx + dy * dy
            if distSq > Float(unitW * unitW * 3.6) { continue }
            var logP = -distSq / twoSigmaSq
            if !isEnglishMode, let ascii = ch.asciiValue, ascii >= 97, ascii <= 122 {
                let bit = UInt32(1) << (ascii - 97)
                if (nextLetterMask & bit) != 0 {
                    logP += (isXiaohe ? 0.15 : 0.35)
                }
            }
            candidates.append((ch, logP))
        }
        candidates.sort { $0.1 > $1.1 }

        let alt1 = candidates.count > 0 ? candidates[0].0 : nil
        let alt1P = candidates.count > 0 ? candidates[0].1 : -10.0
        let alt2 = candidates.count > 1 ? candidates[1].0 : nil
        let alt2P = candidates.count > 1 ? candidates[1].1 : -10.0

        return SpatialTouchSample(primary: primary, alt1: alt1, alt1LogProb: alt1P, alt2: alt2, alt2LogProb: alt2P)
    }

    // MARK: - Highlight & Popup Instant Lifecycle (35ms min floor, instant snap-off)

    private func showHighlight(for slot: KeySlot, customTitle: String? = nil) {
        pendingHideHighlightWork?.cancel()
        pendingHidePopupWork?.cancel()

        let prevId = highlightedKeyId
        highlightedKeyId = slot.id
        highlightShownAt = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let prevId, prevId != slot.id {
            applyHighlightAppearance(forKeyId: prevId, highlighted: false)
        }
        applyHighlightAppearance(forKeyId: slot.id, highlighted: true)
        CATransaction.commit()

        if settings.keyPopupEnabled, case .letter = slot.kind {
            popupOverlay.show(
                for: slot.frame,
                title: customTitle ?? slot.primaryLabel,
                in: bounds,
                palette: palette
            )
        } else {
            popupOverlay.hideImmediately()
        }
    }

    private func scheduleReleaseHighlight(forKeyId keyId: String) {
        let elapsed = CACurrentMediaTime() - highlightShownAt
        let minVisible: CFTimeInterval = 0.035 // 35ms crisp visibility floor
        let remaining = max(0.0, minVisible - elapsed)

        let hideHighlight = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.highlightedKeyId == keyId {
                self.highlightedKeyId = nil
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.applyHighlightAppearance(forKeyId: keyId, highlighted: false)
                CATransaction.commit()
            }
        }
        let hidePopup = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.highlightedKeyId == nil || self.highlightedKeyId == keyId {
                self.popupOverlay.hideImmediately()
            }
        }

        pendingHideHighlightWork?.cancel()
        pendingHidePopupWork?.cancel()
        pendingHideHighlightWork = hideHighlight
        pendingHidePopupWork = hidePopup

        if remaining <= 0.002 {
            hideHighlight.perform()
            hidePopup.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: hideHighlight)
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: hidePopup)
        }
    }

    private func applyHighlightAppearance(forKeyId keyId: String, highlighted: Bool) {
        guard let container = keySublayers[keyId],
              let slot = layoutSpec.keys.first(where: { $0.id == keyId }),
              container.sublayers?.count ?? 0 >= 2,
              let face = container.sublayers?[1] else { return }

        if slot.kind == .enter {
            face.backgroundColor = (highlighted ? palette.returnKeyHighlightedFill : palette.returnKeyFill).cgColor
        } else if slot.isFunctionKey {
            let activeShift = (slot.kind == .shift && (isShiftActive || isCapsLock))
            face.backgroundColor = ((highlighted || activeShift) ? palette.funcKeyHighlightedFill : palette.funcKeyFill).cgColor
        } else {
            face.backgroundColor = (highlighted ? palette.keyHighlightedFill : palette.keyFill).cgColor
        }
    }

    private func fireFeedback(isFunctionKey: Bool) {
        haptics.triggerKeyTap(level: settings.hapticLevel)
        if settings.keySoundEnabled {
            soundEngine.playKeyClick(volume: Float(settings.keySoundVolume), isFunctionKey: isFunctionKey)
        }
    }

    // MARK: - Raw Multi-Touch Finite State Machine

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.keyCanvasWillBeginInteraction()

        for touch in touches {
            let pt = touch.location(in: self)
            guard let slot = hitTestSlot(at: pt) else { continue }

            // Two-finger high-speed rollover: settle any active unsettled letter touch immediately!
            if case .letter = slot.kind {
                for (tid, var existing) in activeTouches where !existing.settled {
                    if case .letter = existing.slot.kind {
                        settleTouch(&existing)
                        activeTouches[tid] = existing
                    }
                }
            }

            let tid = ObjectIdentifier(touch)
            let state = ActiveTouch(
                touch: touch,
                slot: slot,
                startPoint: pt,
                currentPoint: pt,
                startTime: CACurrentMediaTime()
            )
            activeTouches[tid] = state

            // Immediate <2ms feedback burst on touchDown
            fireFeedback(isFunctionKey: slot.isFunctionKey)
            showHighlight(for: slot)

            if slot.kind == .backspace {
                delegate?.keyCanvasDidTapBackspace()
                startBackspaceRepeatTimer()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let tid = ObjectIdentifier(touch)
            guard var state = activeTouches[tid], !state.settled else { continue }
            let pt = touch.location(in: self)
            state.currentPoint = pt
            let dx = pt.x - state.startPoint.x
            let dy = pt.y - state.startPoint.y

            switch state.slot.kind {
            case .space:
                let stepWidth: CGFloat = max(6.0, 14.0 / CGFloat(max(0.5, settings.spaceCursorSensitivity)))
                if !state.isSpaceTracking && abs(dx) > 10.0 && abs(dx) > abs(dy) {
                    state.isSpaceTracking = true
                    state.spaceAccumulatedX = dx
                    popupOverlay.hideImmediately()
                }
                if state.isSpaceTracking {
                    let delta = pt.x - (state.startPoint.x + state.spaceAccumulatedX)
                    let steps = Int(delta / stepWidth)
                    if steps != 0 {
                        state.spaceAccumulatedX += CGFloat(steps) * stepWidth
                        haptics.triggerCursorTick(level: settings.hapticLevel)
                        delegate?.keyCanvasDidMoveSpaceCursor(steps: steps)
                    }
                }

            case .backspace:
                if settings.backspaceLeftSwipeClear && !state.didClearByLeftSwipe && dx < -28.0 && abs(dx) > abs(dy) * 1.2 {
                    state.didClearByLeftSwipe = true
                    stopBackspaceRepeatTimer()
                    haptics.triggerKeyTap(level: settings.hapticLevel)
                    delegate?.keyCanvasDidSwipeLeftBackspaceClear()
                }

            case .letter:
                if settings.swipeUpSymbolsEnabled, let sym = state.slot.swipeUpSymbol {
                    let shouldSwipeUp = (dy < -24.0 && abs(dy) > abs(dx) * 1.1)
                    if shouldSwipeUp != state.isSwipingUp {
                        state.isSwipingUp = shouldSwipeUp
                        if settings.keyPopupEnabled {
                            popupOverlay.show(
                                for: state.slot.frame,
                                title: shouldSwipeUp ? sym : state.slot.primaryLabel,
                                in: bounds,
                                palette: palette
                            )
                        }
                    }
                }

            default:
                break
            }

            activeTouches[tid] = state
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let tid = ObjectIdentifier(touch)
            guard var state = activeTouches.removeValue(forKey: tid) else { continue }
            state.currentPoint = touch.location(in: self)

            if state.slot.kind == .backspace {
                stopBackspaceRepeatTimer()
            }
            if !state.settled {
                settleTouch(&state)
            }
            scheduleReleaseHighlight(forKeyId: state.slot.id)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let tid = ObjectIdentifier(touch)
            guard let state = activeTouches.removeValue(forKey: tid) else { continue }
            if state.slot.kind == .backspace {
                stopBackspaceRepeatTimer()
            }
            scheduleReleaseHighlight(forKeyId: state.slot.id)
        }
    }

    private func settleTouch(_ state: inout ActiveTouch) {
        state.settled = true
        let slot = state.slot
        let now = CACurrentMediaTime()

        switch slot.kind {
        case .letter(let ch):
            if state.isSwipingUp, let sym = slot.swipeUpSymbol {
                delegate?.keyCanvasDidTapSwipeSymbol(sym)
            } else {
                let sample = makeSpatialSample(primary: ch, at: state.currentPoint)
                delegate?.keyCanvasDidTapLetter(sample)
            }

        case .space:
            if !state.isSpaceTracking {
                let isDouble = settings.doubleSpacePeriod && (now - lastSpaceTapTime < 0.34)
                lastSpaceTapTime = isDouble ? 0 : now
                delegate?.keyCanvasDidTapSpace(isDoubleSpace: isDouble)
            }

        case .backspace:
            // Already handled on touchDown + repeat timer
            break

        case .separator:
            if state.currentPoint.y - state.startPoint.y < -22.0, let up = slot.swipeUpSymbol {
                delegate?.keyCanvasDidTapSeparator(up)
            } else {
                delegate?.keyCanvasDidTapSeparator(slot.primaryLabel)
            }

        case .shift:
            let isDouble = (now - lastShiftTapTime < 0.32)
            lastShiftTapTime = isDouble ? 0 : now
            if isDouble {
                delegate?.keyCanvasDidDoubleTapShift()
            } else {
                delegate?.keyCanvasDidTapShift()
            }

        case .modeSwitch:
            delegate?.keyCanvasDidTapModeSwitch123()

        case .langSwitch:
            delegate?.keyCanvasDidTapLangSwitch()

        case .enter:
            delegate?.keyCanvasDidTapEnter()
        }
    }

    // MARK: - Backspace Stepless Acceleration Timer

    private func startBackspaceRepeatTimer() {
        stopBackspaceRepeatTimer()
        backspaceRepeatCount = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.34, repeating: 0.085)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.backspaceRepeatCount += 1
            if !self.isComposing && self.backspaceRepeatCount >= 18 {
                self.delegate?.keyCanvasDidTapBackspace()
                self.delegate?.keyCanvasDidTapBackspace()
            } else {
                self.delegate?.keyCanvasDidTapBackspace()
            }
            if self.backspaceRepeatCount == 4 {
                self.backspaceTimer?.schedule(deadline: .now() + 0.048, repeating: 0.048)
            } else if self.backspaceRepeatCount == 12 {
                self.backspaceTimer?.schedule(deadline: .now() + 0.032, repeating: 0.032)
            }
        }
        backspaceTimer = timer
        timer.resume()
    }

    private func stopBackspaceRepeatTimer() {
        backspaceTimer?.cancel()
        backspaceTimer = nil
        backspaceRepeatCount = 0
    }
}
