import UIKit

final class NumberPadView: UIView {
    var onInsertText: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onReturnToLetters: (() -> Void)?
    var onSwitchToSymbols: (() -> Void)?
    var onEnter: (() -> Void)?

    private var palette: KeyboardPalette = .crispLight
    private var buttons: [UIButton] = []

    private let leftSymbols = ["+", "-", "*", "/", "%", ":", "¥", "$"]
    private let gridDigits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "@"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildButtons() {
        for sym in leftSymbols {
            buttons.append(makeButton(title: sym, tag: 100, isFunc: true))
        }
        for d in gridDigits {
            buttons.append(makeButton(title: d, tag: 200, isFunc: false))
        }
        buttons.append(makeButton(title: "⌫", tag: 301, isFunc: true))
        buttons.append(makeButton(title: "符号", tag: 302, isFunc: true))
        buttons.append(makeButton(title: "返回", tag: 303, isFunc: true))
        buttons.append(makeButton(title: "确定", tag: 304, isFunc: true))
    }

    private func makeButton(title: String, tag: Int, isFunc: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.tag = tag
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: isFunc ? 16 : 21, weight: isFunc ? .medium : .regular)
        b.layer.cornerRadius = 6.0
        b.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
        addSubview(b)
        return b
    }

    func applyPalette(_ palette: KeyboardPalette) {
        self.palette = palette
        backgroundColor = palette.keyboardBackground
        for (idx, b) in buttons.enumerated() {
            let isDigit = (idx >= leftSymbols.count && idx < leftSymbols.count + gridDigits.count)
            if b.tag == 304 {
                b.backgroundColor = palette.returnKeyFill
                b.setTitleColor(palette.returnKeyText, for: .normal)
            } else if isDigit {
                b.backgroundColor = palette.keyFill
                b.setTitleColor(palette.primaryText, for: .normal)
            } else {
                b.backgroundColor = palette.funcKeyFill
                b.setTitleColor(palette.primaryText, for: .normal)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        guard w > 40, h > 40 else { return }

        let pad: CGFloat = 5.0
        let gap: CGFloat = 6.0
        let leftColW = min(64.0, w * 0.17)
        let rightColW = min(68.0, w * 0.18)
        let centerW = w - pad * 2 - leftColW - rightColW - gap * 2

        let rowH = (h - pad * 2 - gap * 3) / 4.0

        // Left 2x4 symbol column
        let symW = (leftColW - gap * 0.5) / 2.0
        for i in 0..<8 {
            let r = i / 2
            let c = i % 2
            let x = pad + CGFloat(c) * (symW + gap * 0.5)
            let y = pad + CGFloat(r) * (rowH + gap)
            buttons[i].frame = CGRect(x: x, y: y, width: symW, height: rowH)
        }

        // Center 3x4 digit grid
        let centerStartX = pad + leftColW + gap
        let cellW = (centerW - gap * 2) / 3.0
        for i in 0..<12 {
            let r = i / 3
            let c = i % 3
            let x = centerStartX + CGFloat(c) * (cellW + gap)
            let y = pad + CGFloat(r) * (rowH + gap)
            buttons[8 + i].frame = CGRect(x: x, y: y, width: cellW, height: rowH)
        }

        // Right 1x4 action column
        let rightX = centerStartX + centerW + gap
        for i in 0..<4 {
            let y = pad + CGFloat(i) * (rowH + gap)
            buttons[20 + i].frame = CGRect(x: rightX, y: y, width: rightColW, height: rowH)
        }
    }

    @objc private func didTap(_ sender: UIButton) {
        switch sender.tag {
        case 100, 200:
            if let t = sender.currentTitle { onInsertText?(t) }
        case 301:
            onBackspace?()
        case 302:
            onSwitchToSymbols?()
        case 303:
            onReturnToLetters?()
        case 304:
            onEnter?()
        default:
            break
        }
    }
}
