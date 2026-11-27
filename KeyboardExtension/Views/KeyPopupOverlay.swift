import UIKit

final class KeyPopupOverlay: UIView {
    private let cardLayer = CAShapeLayer()
    private let textLayer = CATextLayer()
    private var currentPalette: KeyboardPalette = .crispLight

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true

        cardLayer.shadowColor = UIColor.black.cgColor
        cardLayer.shadowOpacity = 0.18
        cardLayer.shadowRadius = 4.0
        cardLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(cardLayer)

        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(textLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette(_ palette: KeyboardPalette) {
        currentPalette = palette
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cardLayer.fillColor = palette.popupFill.cgColor
        cardLayer.strokeColor = palette.popupBorder.cgColor
        cardLayer.lineWidth = 1.0 / UIScreen.main.scale
        textLayer.foregroundColor = palette.primaryText.cgColor
        CATransaction.commit()
    }

    func show(for keyFrame: CGRect, title: String, in containerBounds: CGRect, palette: KeyboardPalette) {
        currentPalette = palette
        let popW = max(keyFrame.width * 1.32, 46.0)
        let popH: CGFloat = 54.0
        var popX = keyFrame.midX - popW * 0.5
        popX = max(2.0, min(containerBounds.width - popW - 2.0, popX))
        let popY = keyFrame.minY - popH - 6.0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = CGRect(x: popX, y: popY, width: popW, height: popH)
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 9.0)
        cardLayer.frame = bounds
        cardLayer.path = path.cgPath
        cardLayer.fillColor = palette.popupFill.cgColor
        cardLayer.strokeColor = palette.popupBorder.cgColor

        let fontSize: CGFloat = title.count > 1 ? 22.0 : 28.0
        textLayer.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = palette.primaryText.cgColor
        textLayer.string = title
        textLayer.frame = CGRect(x: 0, y: (popH - fontSize * 1.2) * 0.5 - 1.0, width: popW, height: fontSize * 1.3)
        isHidden = false
        CATransaction.commit()
    }

    func hideImmediately() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        isHidden = true
        CATransaction.commit()
    }
}
