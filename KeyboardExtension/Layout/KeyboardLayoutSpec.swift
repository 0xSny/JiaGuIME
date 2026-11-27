import UIKit

enum KeyKind: Equatable {
    case letter(Character)        // 'a'..'z' (lowercase)
    case shift
    case backspace
    case modeSwitch               // 123 / 符
    case langSwitch               // 中 / 英
    case space
    case separator                // ' / , / .
    case enter
}

struct XiaoheKeyHint {
    let initialHint: String?      // e.g. "sh" on U, "ch" on I, "zh" on V
    let finals: [String]          // 1 or 2 finals for compact stacked layout
}

struct KeySlot {
    let id: String
    let kind: KeyKind
    let frame: CGRect             // Pixel-snapped rect inside KeyCanvasView
    let center: CGPoint
    let primaryLabel: String
    let swipeUpSymbol: String?
    let xiaoheHint: XiaoheKeyHint?
    let isFunctionKey: Bool
}

struct KeyboardLayoutSpec {
    let totalSize: CGSize
    let keys: [KeySlot]
    let letterSlots: [KeySlot]    // Subset of 26 letter keys for Voronoi + 2D Gaussian
    let scale: CGFloat

    static let xiaoheHints: [Character: XiaoheKeyHint] = [
        "q": XiaoheKeyHint(initialHint: nil, finals: ["iu"]),
        "w": XiaoheKeyHint(initialHint: nil, finals: ["ei"]),
        "e": XiaoheKeyHint(initialHint: nil, finals: ["e"]),
        "r": XiaoheKeyHint(initialHint: nil, finals: ["uan"]),
        "t": XiaoheKeyHint(initialHint: nil, finals: ["ue", "ve"]),
        "y": XiaoheKeyHint(initialHint: nil, finals: ["un"]),
        "u": XiaoheKeyHint(initialHint: "sh", finals: ["u"]),
        "i": XiaoheKeyHint(initialHint: "ch", finals: ["i"]),
        "o": XiaoheKeyHint(initialHint: nil, finals: ["uo", "o"]),
        "p": XiaoheKeyHint(initialHint: nil, finals: ["ie"]),

        "a": XiaoheKeyHint(initialHint: nil, finals: ["a"]),
        "s": XiaoheKeyHint(initialHint: nil, finals: ["ong", "iong"]),
        "d": XiaoheKeyHint(initialHint: nil, finals: ["ai"]),
        "f": XiaoheKeyHint(initialHint: nil, finals: ["en"]),
        "g": XiaoheKeyHint(initialHint: nil, finals: ["eng"]),
        "h": XiaoheKeyHint(initialHint: nil, finals: ["ang"]),
        "j": XiaoheKeyHint(initialHint: nil, finals: ["an"]),
        "k": XiaoheKeyHint(initialHint: nil, finals: ["ing", "uai"]),
        "l": XiaoheKeyHint(initialHint: nil, finals: ["iang", "uang"]),

        "z": XiaoheKeyHint(initialHint: nil, finals: ["ou"]),
        "x": XiaoheKeyHint(initialHint: nil, finals: ["ia", "ua"]),
        "c": XiaoheKeyHint(initialHint: nil, finals: ["ao"]),
        "v": XiaoheKeyHint(initialHint: "zh", finals: ["ui", "ü"]),
        "b": XiaoheKeyHint(initialHint: nil, finals: ["in"]),
        "n": XiaoheKeyHint(initialHint: nil, finals: ["iao"]),
        "m": XiaoheKeyHint(initialHint: nil, finals: ["ian"]),
    ]

    static let swipeUpMap: [Character: String] = [
        "q": "1", "w": "2", "e": "3", "r": "4", "t": "5",
        "y": "6", "u": "7", "i": "8", "o": "9", "p": "0",
        "a": "@", "s": "#", "d": "$", "f": "%", "g": "&",
        "h": "*", "j": "-", "k": "+", "l": "=",
        "z": "!", "x": "\"", "c": "'", "v": ":", "b": ";",
        "n": "?", "m": "/"
    ]

    static func snap(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }

    static func snapRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let x0 = snap(rect.minX, scale: scale)
        let y0 = snap(rect.minY, scale: scale)
        let x1 = snap(rect.maxX, scale: scale)
        let y1 = snap(rect.maxY, scale: scale)
        return CGRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
    }

    static func build(boundsSize: CGSize,
                      scale: CGFloat,
                      oneHanded: OneHandedMode,
                      isEnglish: Bool,
                      isShiftActive: Bool,
                      isCapsLock: Bool,
                      isComposing: Bool,
                      returnTitle: String,
                      showXiaoheHints: Bool) -> KeyboardLayoutSpec {
        let w = boundsSize.width
        let h = boundsSize.height
        guard w > 40, h > 40 else {
            return KeyboardLayoutSpec(totalSize: boundsSize, keys: [], letterSlots: [], scale: scale)
        }

        // One-handed horizontal compression (~82% width)
        let activeW: CGFloat = (oneHanded == .full) ? w : min(w * 0.84, 326.0)
        let originX: CGFloat
        switch oneHanded {
        case .full: originX = 0
        case .left: originX = 0
        case .right: originX = w - activeW
        }

        let sidePad: CGFloat = 3.0
        let topPad: CGFloat = 6.0
        let bottomPad: CGFloat = 4.0
        let rowGap: CGFloat = 9.0
        let colGap: CGFloat = activeW < 340 ? 4.5 : 6.0

        let usableH = h - topPad - bottomPad - rowGap * 3.0
        let rowH = usableH / 4.0
        let usableW = activeW - sidePad * 2.0
        let unitW = (usableW - colGap * 9.0) / 10.0

        var slots: [KeySlot] = []
        var letters: [KeySlot] = []
        slots.reserveCapacity(32)
        letters.reserveCapacity(26)

        func makeLetterSlot(_ ch: Character, rect: CGRect) {
            let snapped = snapRect(rect, scale: scale)
            let label = isEnglish
                ? ((isShiftActive || isCapsLock) ? String(ch).uppercased() : String(ch))
                : String(ch).uppercased()
            let slot = KeySlot(
                id: "k_\(ch)",
                kind: .letter(ch),
                frame: snapped,
                center: CGPoint(x: snapped.midX, y: snapped.midY),
                primaryLabel: label,
                swipeUpSymbol: swipeUpMap[ch],
                xiaoheHint: (!isEnglish && showXiaoheHints) ? xiaoheHints[ch] : nil,
                isFunctionKey: false
            )
            slots.append(slot)
            letters.append(slot)
        }

        // Row 0: Q W E R T Y U I O P
        let row0: [Character] = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let y0 = topPad
        for (idx, ch) in row0.enumerated() {
            let x = originX + sidePad + CGFloat(idx) * (unitW + colGap)
            makeLetterSlot(ch, rect: CGRect(x: x, y: y0, width: unitW, height: rowH))
        }

        // Row 1: A S D F G H J K L
        let row1: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let y1 = y0 + rowH + rowGap
        let row1W = CGFloat(9) * unitW + CGFloat(8) * colGap
        let row1StartX = originX + (activeW - row1W) * 0.5
        for (idx, ch) in row1.enumerated() {
            let x = row1StartX + CGFloat(idx) * (unitW + colGap)
            makeLetterSlot(ch, rect: CGRect(x: x, y: y1, width: unitW, height: rowH))
        }

        // Row 2: Shift/分词 + Z X C V B N M + Backspace
        let row2: [Character] = ["z", "x", "c", "v", "b", "n", "m"]
        let y2 = y1 + rowH + rowGap
        let row2LettersW = CGFloat(7) * unitW + CGFloat(6) * colGap
        let row2LettersStartX = originX + (activeW - row2LettersW) * 0.5
        for (idx, ch) in row2.enumerated() {
            let x = row2LettersStartX + CGFloat(idx) * (unitW + colGap)
            makeLetterSlot(ch, rect: CGRect(x: x, y: y2, width: unitW, height: rowH))
        }

        let leftFuncW = max(unitW * 1.25, row2LettersStartX - (originX + sidePad) - colGap * 1.3)
        let leftFuncRect = snapRect(CGRect(x: originX + sidePad, y: y2, width: leftFuncW, height: rowH), scale: scale)
        let leftKind: KeyKind = isEnglish ? .shift : .separator
        let leftLabel = isEnglish ? (isCapsLock ? "⇪" : "⇧") : "分词"
        slots.append(KeySlot(
            id: "k_left_row2",
            kind: leftKind,
            frame: leftFuncRect,
            center: CGPoint(x: leftFuncRect.midX, y: leftFuncRect.midY),
            primaryLabel: leftLabel,
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: true
        ))

        let rightEdge = originX + activeW - sidePad
        let delX = row2LettersStartX + row2LettersW + colGap * 1.3
        let delRect = snapRect(CGRect(x: delX, y: y2, width: max(unitW * 1.25, rightEdge - delX), height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_backspace",
            kind: .backspace,
            frame: delRect,
            center: CGPoint(x: delRect.midX, y: delRect.midY),
            primaryLabel: "⌫",
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: true
        ))

        // Row 3: 123 | 中/英 | Space | ，/。 | Return
        let y3 = y2 + rowH + rowGap
        let modeW = unitW * 1.35
        let langW = unitW * 1.25
        let punctW = unitW * 1.15
        let retW = unitW * 2.15
        let fixedW = modeW + langW + punctW + retW + colGap * 4.0
        let spaceW = max(unitW * 2.2, usableW - fixedW)

        var cx = originX + sidePad
        let modeRect = snapRect(CGRect(x: cx, y: y3, width: modeW, height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_123",
            kind: .modeSwitch,
            frame: modeRect,
            center: CGPoint(x: modeRect.midX, y: modeRect.midY),
            primaryLabel: "123",
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: true
        ))
        cx += modeW + colGap

        let langRect = snapRect(CGRect(x: cx, y: y3, width: langW, height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_lang",
            kind: .langSwitch,
            frame: langRect,
            center: CGPoint(x: langRect.midX, y: langRect.midY),
            primaryLabel: isEnglish ? "英/中" : "中/英",
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: true
        ))
        cx += langW + colGap

        let spaceRect = snapRect(CGRect(x: cx, y: y3, width: spaceW, height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_space",
            kind: .space,
            frame: spaceRect,
            center: CGPoint(x: spaceRect.midX, y: spaceRect.midY),
            primaryLabel: isEnglish ? "space" : "甲骨",
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: false
        ))
        cx += spaceW + colGap

        let punctRect = snapRect(CGRect(x: cx, y: y3, width: punctW, height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_punct",
            kind: .separator,
            frame: punctRect,
            center: CGPoint(x: punctRect.midX, y: punctRect.midY),
            primaryLabel: isEnglish ? "." : (isComposing ? "'" : "，"),
            swipeUpSymbol: isEnglish ? "," : "。",
            xiaoheHint: nil,
            isFunctionKey: false
        ))
        cx += punctW + colGap

        let retRect = snapRect(CGRect(x: cx, y: y3, width: max(unitW * 1.5, rightEdge - cx), height: rowH), scale: scale)
        slots.append(KeySlot(
            id: "k_return",
            kind: .enter,
            frame: retRect,
            center: CGPoint(x: retRect.midX, y: retRect.midY),
            primaryLabel: returnTitle,
            swipeUpSymbol: nil,
            xiaoheHint: nil,
            isFunctionKey: true
        ))

        return KeyboardLayoutSpec(totalSize: boundsSize, keys: slots, letterSlots: letters, scale: scale)
    }
}
