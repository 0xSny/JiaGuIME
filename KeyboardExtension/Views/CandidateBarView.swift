import UIKit

protocol CandidateBarDelegate: AnyObject {
    func candidateBarDidSelectCandidate(at index: Int)
    func candidateBarDidRequestForgetUserWord(_ word: String)
    func candidateBarDidTapExpand()
    func candidateBarDidTapSettings()
    func candidateBarDidTapNumberPanel()
    func candidateBarDidTapSymbolPanel()
    func candidateBarDidTapDismissKeyboard()
    func candidateBarDidTapPasteClipboard(_ text: String)
    func candidateBarDidDismissClipboard()
}

final class CandidateBarView: UIView, UIScrollViewDelegate {
    weak var delegate: CandidateBarDelegate?

    private var palette: KeyboardPalette = .crispLight
    private var candidates: [JiaGuCandidateObjC] = []
    private var cellFrames: [CGRect] = []
    private var dividerXs: [CGFloat] = []
    private var clipboardPreviewText: String?

    // Toolbar mode (shown when candidates are empty)
    private let toolbarContainer = UIView()
    private let settingsBtn = UIButton(type: .system)
    private let numberBtn = UIButton(type: .system)
    private let symbolBtn = UIButton(type: .system)
    private let dismissBtn = UIButton(type: .system)
    private let clipboardPill = UIButton(type: .system)
    private let clipboardCloseBtn = UIButton(type: .system)

    // Candidate mode
    private let scrollView = UIScrollView()
    private let contentCanvas = CandidateStripCanvas()
    private let expandBtn = UIButton(type: .system)
    private let bottomHairline = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        // Candidate scroll view: zero touch delay, crisp 8pt tap-vs-scroll threshold
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.delegate = self
        addSubview(scrollView)

        contentCanvas.onTapPoint = { [weak self] pt in
            self?.handleTap(at: pt)
        }
        contentCanvas.onLongPressPoint = { [weak self] pt in
            self?.handleLongPress(at: pt)
        }
        scrollView.addSubview(contentCanvas)

        expandBtn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        expandBtn.addTarget(self, action: #selector(didTapExpand), for: .touchUpInside)
        addSubview(expandBtn)

        // Toolbar container
        addSubview(toolbarContainer)
        configureToolbarButton(settingsBtn, systemName: "slider.horizontal.3", action: #selector(didTapSettings))
        configureToolbarButton(numberBtn, title: "123", action: #selector(didTapNumbers))
        configureToolbarButton(symbolBtn, systemName: "face.smiling", action: #selector(didTapSymbols))
        configureToolbarButton(dismissBtn, systemName: "keyboard.chevron.compact.down", action: #selector(didTapDismiss))

        clipboardPill.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        clipboardPill.titleLabel?.lineBreakMode = .byTruncatingTail
        clipboardPill.layer.cornerRadius = 13.0
        clipboardPill.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 24)
        clipboardPill.addTarget(self, action: #selector(didTapClipboard), for: .touchUpInside)
        clipboardPill.isHidden = true
        toolbarContainer.addSubview(clipboardPill)

        clipboardCloseBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clipboardCloseBtn.addTarget(self, action: #selector(didDismissClipboard), for: .touchUpInside)
        clipboardCloseBtn.isHidden = true
        toolbarContainer.addSubview(clipboardCloseBtn)

        layer.addSublayer(bottomHairline)
        updateModeVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureToolbarButton(_ btn: UIButton, systemName: String? = nil, title: String? = nil, action: Selector) {
        if let systemName {
            btn.setImage(UIImage(systemName: systemName), for: .normal)
        }
        if let title {
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14.5, weight: .medium)
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        toolbarContainer.addSubview(btn)
    }

    func applyPalette(_ palette: KeyboardPalette) {
        self.palette = palette
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundColor = palette.candidateBarBackground
        bottomHairline.backgroundColor = palette.dividerColor.cgColor

        let tint = palette.primaryText.withAlphaComponent(0.82)
        settingsBtn.tintColor = tint
        numberBtn.setTitleColor(tint, for: .normal)
        symbolBtn.tintColor = tint
        dismissBtn.tintColor = tint
        expandBtn.tintColor = tint

        clipboardPill.backgroundColor = palette.pillFill
        clipboardPill.setTitleColor(palette.pillText, for: .normal)
        clipboardCloseBtn.tintColor = palette.pillText.withAlphaComponent(0.75)

        contentCanvas.palette = palette
        contentCanvas.setNeedsDisplay()
        CATransaction.commit()
    }

    func updateCandidates(_ list: [JiaGuCandidateObjC]) {
        candidates = list
        scrollView.setContentOffset(.zero, animated: false)
        recomputeCandidateFrames()
        updateModeVisibility()
    }

    func setClipboardPreview(_ text: String?) {
        clipboardPreviewText = text
        if let text, !text.isEmpty {
            let trimmed = text.replacingOccurrences(of: "\n", with: " ")
            let shown = trimmed.count > 12 ? String(trimmed.prefix(12)) + "…" : trimmed
            clipboardPill.setTitle("粘贴: \(shown)", for: .normal)
            clipboardPill.isHidden = false
            clipboardCloseBtn.isHidden = false
        } else {
            clipboardPill.isHidden = true
            clipboardCloseBtn.isHidden = true
        }
        setNeedsLayout()
    }

    private func updateModeVisibility() {
        let hasCands = !candidates.isEmpty
        scrollView.isHidden = !hasCands
        expandBtn.isHidden = !hasCands
        toolbarContainer.isHidden = hasCands
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let scale = window?.screen.scale ?? UIScreen.main.scale

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bottomHairline.frame = CGRect(x: 0, y: h - 1.0 / scale, width: w, height: 1.0 / scale)
        CATransaction.commit()

        let expandW: CGFloat = 42.0
        expandBtn.frame = CGRect(x: w - expandW, y: 0, width: expandW, height: h)
        scrollView.frame = CGRect(x: 0, y: 0, width: w - expandW, height: h)

        toolbarContainer.frame = bounds
        let btnW: CGFloat = 44.0
        settingsBtn.frame = CGRect(x: 6, y: 0, width: btnW, height: h)
        numberBtn.frame = CGRect(x: 6 + btnW, y: 0, width: btnW, height: h)
        symbolBtn.frame = CGRect(x: 6 + btnW * 2, y: 0, width: btnW, height: h)
        dismissBtn.frame = CGRect(x: w - btnW - 6, y: 0, width: btnW, height: h)

        if !clipboardPill.isHidden {
            let pillMaxW = max(90.0, w - (6 + btnW * 3 + btnW + 18))
            let fitW = min(pillMaxW, clipboardPill.intrinsicContentSize.width + 4.0)
            let pillX = w - btnW - 10 - fitW
            clipboardPill.frame = CGRect(x: pillX, y: (h - 26) * 0.5, width: fitW, height: 26)
            clipboardCloseBtn.frame = CGRect(x: pillX + fitW - 24, y: (h - 26) * 0.5, width: 22, height: 26)
        }

        recomputeCandidateFrames()
    }

    private func recomputeCandidateFrames() {
        cellFrames.removeAll(keepingCapacity: true)
        dividerXs.removeAll(keepingCapacity: true)

        let h = bounds.height
        guard h > 0 else { return }
        let font = UIFont.systemFont(ofSize: 17.5, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        var x: CGFloat = 0
        for (idx, cand) in candidates.enumerated() {
            let textW = (cand.text as NSString).size(withAttributes: attrs).width
            let cellW = max(48.0, ceil(textW) + 24.0)
            let rect = CGRect(x: x, y: 0, width: cellW, height: h)
            cellFrames.append(rect)
            x += cellW
            if idx + 1 < candidates.count {
                dividerXs.append(x)
            }
        }

        let contentW = max(scrollView.bounds.width, x)
        scrollView.contentSize = CGSize(width: contentW, height: h)
        contentCanvas.frame = CGRect(x: 0, y: 0, width: contentW, height: h)
        contentCanvas.updateData(candidates: candidates, frames: cellFrames, dividerXs: dividerXs, palette: palette)
    }

    private func candidateIndex(at point: CGPoint) -> Int? {
        for (idx, rect) in cellFrames.enumerated() {
            if rect.contains(point) { return idx }
        }
        return nil
    }

    private func handleTap(at point: CGPoint) {
        guard let idx = candidateIndex(at: point) else { return }
        delegate?.candidateBarDidSelectCandidate(at: idx)
    }

    private func handleLongPress(at point: CGPoint) {
        guard let idx = candidateIndex(at: point), idx < candidates.count else { return }
        let cand = candidates[idx]
        guard cand.isUserWord else { return }
        delegate?.candidateBarDidRequestForgetUserWord(cand.text)
    }

    @objc private func didTapExpand() { delegate?.candidateBarDidTapExpand() }
    @objc private func didTapSettings() { delegate?.candidateBarDidTapSettings() }
    @objc private func didTapNumbers() { delegate?.candidateBarDidTapNumberPanel() }
    @objc private func didTapSymbols() { delegate?.candidateBarDidTapSymbolPanel() }
    @objc private func didTapDismiss() { delegate?.candidateBarDidTapDismissKeyboard() }
    @objc private func didTapClipboard() {
        if let text = clipboardPreviewText, !text.isEmpty {
            delegate?.candidateBarDidTapPasteClipboard(text)
        }
    }
    @objc private func didDismissClipboard() { delegate?.candidateBarDidDismissClipboard() }
}

/// Zero-dead-zone full-height/full-width candidate strip canvas with 8pt tap-vs-drag threshold.
private final class CandidateStripCanvas: UIView {
    var palette: KeyboardPalette = .crispLight
    private var candidates: [JiaGuCandidateObjC] = []
    private var frames: [CGRect] = []
    private var dividerXs: [CGFloat] = []
    private var touchStartPoint: CGPoint?
    private var longPressWork: DispatchWorkItem?
    private var didTriggerLongPress = false

    var onTapPoint: ((CGPoint) -> Void)?
    var onLongPressPoint: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateData(candidates: [JiaGuCandidateObjC],
                    frames: [CGRect],
                    dividerXs: [CGFloat],
                    palette: KeyboardPalette) {
        self.candidates = candidates
        self.frames = frames
        self.dividerXs = dividerXs
        self.palette = palette
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let font = UIFont.systemFont(ofSize: 17.5, weight: .regular)
        let firstFont = UIFont.systemFont(ofSize: 17.5, weight: .medium)

        for (idx, cand) in candidates.enumerated() where idx < frames.count {
            let f = frames[idx]
            guard f.intersects(rect) else { continue }
            let color = (idx == 0) ? palette.accentColor : palette.primaryText
            let attrs: [NSAttributedString.Key: Any] = [
                .font: (idx == 0 ? firstFont : font),
                .foregroundColor: color
            ]
            let size = (cand.text as NSString).size(withAttributes: attrs)
            let drawRect = CGRect(
                x: f.minX + (f.width - size.width) * 0.5,
                y: (f.height - size.height) * 0.5,
                width: size.width,
                height: size.height
            )
            (cand.text as NSString).draw(in: drawRect, withAttributes: attrs)
        }

        // Purely visual 0.5pt vertical dividers (never block touch hitboxes)
        ctx.setStrokeColor(palette.dividerColor.cgColor)
        ctx.setLineWidth(0.5)
        let lineTop: CGFloat = 11.0
        let lineBot = bounds.height - 11.0
        for x in dividerXs {
            if x >= rect.minX - 1 && x <= rect.maxX + 1 {
                ctx.move(to: CGPoint(x: x, y: lineTop))
                ctx.addLine(to: CGPoint(x: x, y: lineBot))
            }
        }
        ctx.strokePath()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let pt = t.location(in: self)
        touchStartPoint = pt
        didTriggerLongPress = false

        longPressWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let start = self.touchStartPoint else { return }
            self.didTriggerLongPress = true
            self.onLongPressPoint?(start)
        }
        longPressWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = touchStartPoint else { return }
        let pt = t.location(in: self)
        if hypot(pt.x - start.x, pt.y - start.y) > 8.0 {
            touchStartPoint = nil
            longPressWork?.cancel()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressWork?.cancel()
        guard !didTriggerLongPress, let t = touches.first, touchStartPoint != nil else {
            touchStartPoint = nil
            return
        }
        let pt = t.location(in: self)
        touchStartPoint = nil
        onTapPoint?(pt)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPoint = nil
        longPressWork?.cancel()
    }
}
