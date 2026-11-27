import UIKit

/// Root view that forwards window attachment & trait updates directly to the controller.
final class KeyboardRootView: UIView {
    var onTraitsOrWindowChanged: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: KeyboardRootView, _) in
                self.onTraitsOrWindowChanged?()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onTraitsOrWindowChanged?()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        onTraitsOrWindowChanged?()
    }
}

@objc(JiaGuKeyboardViewController)
final class JiaGuKeyboardViewController: UIInputViewController, KeyCanvasDelegate, CandidateBarDelegate {

    private enum ActivePanel {
        case letters
        case candidateGrid
        case numbers
        case symbols
        case quickSettings
    }

    private let rootContainer = KeyboardRootView()
    private let candidateBar = CandidateBarView()
    private let keyCanvas = KeyCanvasView()
    private let candidateGrid = CandidateGridView()
    private let numberPad = NumberPadView()
    private let symbolPanel = SymbolPanelView()
    private let quickSettings = QuickSettingsDrawerView()

    // Learned-word forget prompt bar (triggered on long-press of learned candidate)
    private let forgetBanner = UIView()
    private let forgetLabel = UILabel()
    private let forgetConfirmBtn = UIButton(type: .system)
    private let forgetCancelBtn = UIButton(type: .system)
    private var pendingForgetWord: String?

    private var heightConstraint: NSLayoutConstraint?
    private let candidateBarHeight: CGFloat = 44.0

    private var engine: JiaGuEngineBridge!
    private let settingsStore = SettingsStore.shared
    private var settings: IMESettings = SettingsStore.shared.settings

    private let appearanceMonitor = AppearanceMonitor()
    private var currentPalette: KeyboardPalette = .crispLight
    private var lastAppliedIsDark: Bool?
    private var lastAppliedMode: AppearanceMode?

    private var activePanel: ActivePanel = .letters
    private var isEnglishMode = false
    private var isShiftActive = false
    private var isCapsLock = false
    private var nextLetterMask: UInt32 = (1 << 26) - 1
    private var currentCandidates: [JiaGuCandidateObjC] = []

    // External cursor jump / context tracking
    private var isInternalProxyMutation = false
    private var lastCommittedSpaceMixedEnglish = false
    private var lastClipboardChangeCount: Int = -1
    private var dismissedClipboardChangeCount: Int = -1
    private var clipboardHideWork: DispatchWorkItem?

    override func loadView() {
        let inputView = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        self.inputView = inputView
        self.view = inputView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize C++17 mmap lexicon + user storage
        let lexPath = Bundle.main.path(forResource: "jiagu_lexicon", ofType: "bin") ?? ""
        let userDir = SettingsStore.userLexiconStorageDirectory()
        engine = JiaGuEngineBridge(lexiconPath: lexPath, userStorageDir: userDir)
        applyEngineConfig(settings)

        // Build pure-frame root hierarchy
        rootContainer.translatesAutoresizingMaskIntoConstraints = false
        rootContainer.onTraitsOrWindowChanged = { [weak self] in
            self?.syncAppearance(forceRepaint: false)
        }
        view.addSubview(rootContainer)

        NSLayoutConstraint.activate([
            rootContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootContainer.topAnchor.constraint(equalTo: view.topAnchor),
            rootContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let totalH = candidateBarHeight + CGFloat(settings.keyboardHeight)
        let hc = rootContainer.heightAnchor.constraint(equalToConstant: totalH)
        hc.priority = .defaultHigh
        hc.isActive = true
        self.heightConstraint = hc

        candidateBar.delegate = self
        keyCanvas.delegate = self
        rootContainer.addSubview(candidateBar)
        rootContainer.addSubview(keyCanvas)

        candidateGrid.isHidden = true
        candidateGrid.onSelectCandidate = { [weak self] idx in
            self?.selectCandidate(at: idx)
            self?.switchPanel(to: .letters)
        }
        candidateGrid.onClose = { [weak self] in
            self?.switchPanel(to: .letters)
        }
        rootContainer.addSubview(candidateGrid)

        numberPad.isHidden = true
        numberPad.onInsertText = { [weak self] text in
            self?.insertDirectText(text)
        }
        numberPad.onBackspace = { [weak self] in
            self?.keyCanvasDidTapBackspace()
        }
        numberPad.onReturnToLetters = { [weak self] in
            self?.switchPanel(to: .letters)
        }
        numberPad.onSwitchToSymbols = { [weak self] in
            self?.switchPanel(to: .symbols)
        }
        numberPad.onEnter = { [weak self] in
            self?.keyCanvasDidTapEnter()
        }
        rootContainer.addSubview(numberPad)

        symbolPanel.isHidden = true
        symbolPanel.onInsertSymbol = { [weak self] text, offset in
            self?.insertDirectText(text, cursorOffset: offset)
        }
        symbolPanel.onBackspace = { [weak self] in
            self?.keyCanvasDidTapBackspace()
        }
        symbolPanel.onClose = { [weak self] in
            self?.switchPanel(to: .letters)
        }
        rootContainer.addSubview(symbolPanel)

        quickSettings.isHidden = true
        quickSettings.onSettingsChanged = { [weak self] newSettings in
            guard let self else { return }
            self.settings = newSettings
            self.settingsStore.settings = newSettings
            self.applySettingsUpdate()
        }
        quickSettings.onResetUserLexicon = { [weak self] in
            self?.engine.clearUserLexicon()
        }
        quickSettings.onClose = { [weak self] in
            self?.switchPanel(to: .letters)
        }
        rootContainer.addSubview(quickSettings)

        setupForgetBanner()

        // Settings external reload (from HostApp via AppGroup + Darwin notification)
        settingsStore.onExternalSettingsChanged = { [weak self] updated in
            guard let self else { return }
            self.settings = updated
            self.applySettingsUpdate()
        }

        // Layer 1 & 2 of Dark Mode Defense: observe both NSExtensionHost* and UIApplication* lifecycle
        registerLifecycleObservers()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: JiaGuKeyboardViewController, _) in
                self.syncAppearance(forceRepaint: false)
            }
        }

        syncAppearance(forceRepaint: true)
        refreshKeyCanvasState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        appearanceMonitor.cancelResumeTicks()
    }

    private func setupForgetBanner() {
        forgetBanner.isHidden = true
        forgetBanner.layer.cornerRadius = 10
        forgetBanner.layer.shadowColor = UIColor.black.cgColor
        forgetBanner.layer.shadowOpacity = 0.16
        forgetBanner.layer.shadowRadius = 6
        forgetBanner.layer.shadowOffset = CGSize(width: 0, height: 2)

        forgetLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        forgetConfirmBtn.setTitle("删除记忆", for: .normal)
        forgetConfirmBtn.setTitleColor(.systemRed, for: .normal)
        forgetConfirmBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        forgetConfirmBtn.addTarget(self, action: #selector(confirmForgetWord), for: .touchUpInside)

        forgetCancelBtn.setTitle("取消", for: .normal)
        forgetCancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        forgetCancelBtn.addTarget(self, action: #selector(cancelForgetWord), for: .touchUpInside)

        forgetBanner.addSubview(forgetLabel)
        forgetBanner.addSubview(forgetConfirmBtn)
        forgetBanner.addSubview(forgetCancelBtn)
        rootContainer.addSubview(forgetBanner)
    }

    private func registerLifecycleObservers() {
        let nc = NotificationCenter.default
        let resignNames: [Notification.Name] = [
            Notification.Name("NSExtensionHostWillResignActiveNotification"),
            Notification.Name("NSExtensionHostDidEnterBackgroundNotification"),
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
        ]
        for name in resignNames {
            nc.addObserver(self, selector: #selector(handleHostResignActive), name: name, object: nil)
        }

        let activeNames: [Notification.Name] = [
            Notification.Name("NSExtensionHostWillEnterForegroundNotification"),
            Notification.Name("NSExtensionHostDidBecomeActiveNotification"),
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
        ]
        for name in activeNames {
            nc.addObserver(self, selector: #selector(handleHostBecomeActive), name: name, object: nil)
        }
    }

    @objc private func handleHostResignActive() {
        appearanceMonitor.markResignActive()
        engine.flushUserLexiconAsync()
    }

    @objc private func handleHostBecomeActive() {
        appearanceMonitor.markBecomeActive { [weak self] forceRepaint in
            self?.syncAppearance(forceRepaint: forceRepaint)
        }
        settingsStore.reloadFromDisk()
        checkClipboardForQuickPaste()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearanceMonitor.markBecomeActive { [weak self] forceRepaint in
            self?.syncAppearance(forceRepaint: forceRepaint)
        }
        settingsStore.reloadFromDisk()
        checkClipboardForQuickPaste()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncAppearance(forceRepaint: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        engine.flushUserLexiconAsync()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = rootContainer.bounds.width
        let h = rootContainer.bounds.height
        guard w > 0, h > 0 else { return }

        candidateBar.frame = CGRect(x: 0, y: 0, width: w, height: candidateBarHeight)
        let bodyFrame = CGRect(x: 0, y: candidateBarHeight, width: w, height: max(0, h - candidateBarHeight))
        keyCanvas.frame = bodyFrame
        candidateGrid.frame = bodyFrame
        numberPad.frame = bodyFrame
        symbolPanel.frame = bodyFrame
        quickSettings.frame = bodyFrame

        forgetBanner.frame = CGRect(x: 12, y: 4, width: max(120, w - 24), height: 36)
        forgetLabel.frame = CGRect(x: 12, y: 0, width: max(40, forgetBanner.bounds.width - 140), height: 36)
        forgetConfirmBtn.frame = CGRect(x: forgetBanner.bounds.width - 122, y: 0, width: 68, height: 36)
        forgetCancelBtn.frame = CGRect(x: forgetBanner.bounds.width - 52, y: 0, width: 46, height: 36)

        if view.window != nil {
            syncAppearance(forceRepaint: false)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        syncAppearance(forceRepaint: false)
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        syncAppearance(forceRepaint: false)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        syncAppearance(forceRepaint: false)
        refreshKeyCanvasState()

        if !isInternalProxyMutation && engine.strokeCount() > 0 {
            // External cursor jump or field switch: safely clear dangling preedit
            clearCompositionState(clearMarkedText: true)
        }
    }

    override func selectionWillChange(_ textInput: UITextInput?) {
        super.selectionWillChange(textInput)
        syncAppearance(forceRepaint: false)
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        syncAppearance(forceRepaint: false)
        if !isInternalProxyMutation && engine.strokeCount() > 0 {
            clearCompositionState(clearMarkedText: true)
        }
    }

    // MARK: - 5-Layer Dark Mode Sync

    private func syncAppearance(forceRepaint: Bool) {
        let isDark = appearanceMonitor.resolveIsDark(
            mode: settings.appearanceMode,
            viewController: self,
            rootView: rootContainer
        )
        let palette = KeyboardPalette.resolve(mode: settings.appearanceMode, isDark: isDark)

        if !forceRepaint && lastAppliedIsDark == isDark && lastAppliedMode == settings.appearanceMode && palette == currentPalette {
            return
        }

        lastAppliedIsDark = isDark
        lastAppliedMode = settings.appearanceMode
        currentPalette = palette

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.backgroundColor = palette.keyboardBackground
        rootContainer.backgroundColor = palette.keyboardBackground
        rootContainer.layer.backgroundColor = palette.keyboardBackground.cgColor

        candidateBar.applyPalette(palette)
        keyCanvas.forceRepaint(palette: palette)
        candidateGrid.applyPalette(palette)
        numberPad.applyPalette(palette)
        symbolPanel.applyPalette(palette)
        quickSettings.applyPalette(palette)

        forgetBanner.backgroundColor = palette.popupFill
        forgetLabel.textColor = palette.primaryText
        forgetCancelBtn.setTitleColor(palette.secondaryHintText, for: .normal)
        CATransaction.commit()
    }

    private func applySettingsUpdate() {
        applyEngineConfig(settings)
        heightConstraint?.constant = candidateBarHeight + CGFloat(settings.keyboardHeight)
        syncAppearance(forceRepaint: true)
        refreshKeyCanvasState()
        if engine.strokeCount() > 0 {
            triggerAsyncDecode()
        }
    }

    private func applyEngineConfig(_ cfg: IMESettings) {
        engine.configureMode(
            cfg.inputMode.rawValue,
            fuzzyMask: cfg.fuzzyMask,
            spatialSensitivity: Float(cfg.spatialSensitivity),
            xiaoheExpandedPreedit: (cfg.preeditFormat == .expandedFullPinyin)
        )
        let dictList = cfg.customPhrases.map { ["abbr": $0.abbr, "text": $0.text] }
        engine.setCustomPhrases(dictList)
    }

    private func returnKeyTitle() -> String {
        switch textDocumentProxy.returnKeyType {
        case .go: return "前往"
        case .google, .search, .yahoo: return "搜索"
        case .send: return "发送"
        case .done: return "完成"
        case .next: return "下一项"
        case .join: return "加入"
        case .route: return "路线"
        default: return "换行"
        }
    }

    private func refreshKeyCanvasState() {
        keyCanvas.updateState(
            settings: settings,
            palette: currentPalette,
            isEnglish: isEnglishMode,
            isShiftActive: isShiftActive,
            isCapsLock: isCapsLock,
            isComposing: engine.strokeCount() > 0,
            returnTitle: returnKeyTitle(),
            nextLetterMask: nextLetterMask
        )
    }

    private func switchPanel(to panel: ActivePanel) {
        activePanel = panel
        keyCanvas.isHidden = (panel != .letters)
        candidateGrid.isHidden = (panel != .candidateGrid)
        numberPad.isHidden = (panel != .numbers)
        symbolPanel.isHidden = (panel != .symbols)
        quickSettings.isHidden = (panel != .quickSettings)

        if panel == .quickSettings {
            quickSettings.update(
                settings: settings,
                palette: currentPalette,
                learnedCount: Int(engine.userLearnedCount()),
                isAppGroupSynced: settingsStore.isAppGroupAvailable
            )
        } else if panel == .candidateGrid {
            candidateGrid.updateCandidates(currentCandidates)
        }
    }

    // MARK: - Optimistic Preedit & Async Decode

    private func updateOptimisticPreedit() {
        let text = engine.optimisticPreedit()
        isInternalProxyMutation = true
        textDocumentProxy.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
        isInternalProxyMutation = false
    }

    private func triggerAsyncDecode() {
        engine.requestAsyncDecode { [weak self] result in
            guard let self else { return }
            self.currentCandidates = result.candidates
            self.nextLetterMask = result.nextLetterMask

            if self.engine.strokeCount() > 0 {
                let disp = result.preeditDisplay.isEmpty ? self.engine.optimisticPreedit() : result.preeditDisplay
                self.isInternalProxyMutation = true
                self.textDocumentProxy.setMarkedText(disp, selectedRange: NSRange(location: (disp as NSString).length, length: 0))
                self.isInternalProxyMutation = false
            }

            self.candidateBar.updateCandidates(result.candidates)
            if self.activePanel == .candidateGrid {
                self.candidateGrid.updateCandidates(result.candidates)
            }
            self.refreshKeyCanvasState()
        }
    }

    private func clearCompositionState(clearMarkedText: Bool) {
        engine.clearStrokes()
        currentCandidates.removeAll()
        nextLetterMask = (1 << 26) - 1
        candidateBar.updateCandidates([])
        if clearMarkedText {
            isInternalProxyMutation = true
            textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            textDocumentProxy.unmarkText()
            isInternalProxyMutation = false
        }
        if activePanel == .candidateGrid {
            switchPanel(to: .letters)
        }
        refreshKeyCanvasState()
    }

    private func selectCandidate(at index: Int) {
        guard index >= 0, index < currentCandidates.count else { return }
        var finished: ObjCBool = false
        var synth: NSString?
        let committed = engine.commitCandidate(at: index, compositionFinished: &finished, synthesizedPhrase: &synth)
        guard !committed.isEmpty else { return }

        isInternalProxyMutation = true
        if finished.boolValue {
            textDocumentProxy.insertText(committed)
        } else {
            // Partial segmented selection: commit selected segment and keep remaining preedit marked
            textDocumentProxy.unmarkText()
            textDocumentProxy.insertText(committed)
            let rem = engine.optimisticPreedit()
            textDocumentProxy.setMarkedText(rem, selectedRange: NSRange(location: (rem as NSString).length, length: 0))
        }
        isInternalProxyMutation = false

        if finished.boolValue {
            clearCompositionState(clearMarkedText: false)
        } else {
            triggerAsyncDecode()
        }
    }

    private func insertDirectText(_ text: String, cursorOffset: Int = 0) {
        isInternalProxyMutation = true
        if engine.strokeCount() > 0 {
            let first = currentCandidates.first?.text ?? engine.rawInputString()
            textDocumentProxy.insertText(first)
            clearCompositionState(clearMarkedText: false)
        }
        textDocumentProxy.insertText(text)
        if cursorOffset != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: cursorOffset)
        }
        isInternalProxyMutation = false
    }

    // MARK: - KeyCanvasDelegate

    func keyCanvasWillBeginInteraction() {
        syncAppearance(forceRepaint: false)
    }

    func keyCanvasDidTapLetter(_ sample: SpatialTouchSample) {
        if isEnglishMode {
            engine.clearRegretHistory()
            let chStr = (isShiftActive || isCapsLock) ? String(sample.primary).uppercased() : String(sample.primary)
            isInternalProxyMutation = true
            textDocumentProxy.insertText(chStr)
            isInternalProxyMutation = false
            lastCommittedSpaceMixedEnglish = true
            if isShiftActive && !isCapsLock {
                isShiftActive = false
                refreshKeyCanvasState()
            }
            return
        }

        engine.clearRegretHistory()
        lastCommittedSpaceMixedEnglish = false
        let a1: unichar = sample.alt1?.utf16.first ?? 0
        let a2: unichar = sample.alt2?.utf16.first ?? 0
        engine.pushStrokePrimary(
            sample.primary.utf16.first ?? 0,
            alt1Char: a1,
            alt1LogProb: sample.alt1LogProb,
            alt2Char: a2,
            alt2LogProb: sample.alt2LogProb
        )
        updateOptimisticPreedit()
        triggerAsyncDecode()
    }

    func keyCanvasDidTapSwipeSymbol(_ symbol: String) {
        engine.clearRegretHistory()
        insertDirectText(symbol)
    }

    func keyCanvasDidTapSpace(isDoubleSpace: Bool) {
        if !isEnglishMode && engine.strokeCount() > 0 {
            selectCandidate(at: 0)
            return
        }

        if isDoubleSpace {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            if before.hasSuffix(" ") {
                isInternalProxyMutation = true
                textDocumentProxy.deleteBackward()
                let trimmed = before.dropLast()
                let prevIsDigitOrUrl = trimmed.last?.isNumber == true || trimmed.hasSuffix("www") || trimmed.hasSuffix("http")
                let period = (isEnglishMode || prevIsDigitOrUrl) ? ". " : "。"
                textDocumentProxy.insertText(period)
                isInternalProxyMutation = false
                return
            }
        }

        isInternalProxyMutation = true
        textDocumentProxy.insertText(" ")
        isInternalProxyMutation = false
    }

    func keyCanvasDidMoveSpaceCursor(steps: Int) {
        isInternalProxyMutation = true
        textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
        isInternalProxyMutation = false
    }

    func keyCanvasDidTapBackspace() {
        if engine.strokeCount() > 0 {
            engine.popStroke()
            if engine.strokeCount() == 0 {
                clearCompositionState(clearMarkedText: true)
            } else {
                updateOptimisticPreedit()
                triggerAsyncDecode()
            }
            return
        }

        // Regret rollback hook when user backspaces right after committing a candidate
        engine.notifyBackspaceAfterCommit()
        isInternalProxyMutation = true
        textDocumentProxy.deleteBackward()
        isInternalProxyMutation = false
    }

    func keyCanvasDidSwipeLeftBackspaceClear() {
        if engine.strokeCount() > 0 {
            clearCompositionState(clearMarkedText: true)
        }
    }

    func keyCanvasDidTapSeparator(_ symbol: String) {
        if !isEnglishMode && engine.strokeCount() > 0 && symbol == "'" {
            engine.pushStrokePrimary(unichar(39), alt1Char: 0, alt1LogProb: 0, alt2Char: 0, alt2LogProb: 0)
            updateOptimisticPreedit()
            triggerAsyncDecode()
            return
        }
        insertDirectText(symbol)
    }

    func keyCanvasDidTapShift() {
        if isCapsLock {
            isCapsLock = false
            isShiftActive = false
        } else {
            isShiftActive.toggle()
        }
        refreshKeyCanvasState()
    }

    func keyCanvasDidDoubleTapShift() {
        isCapsLock = true
        isShiftActive = true
        refreshKeyCanvasState()
    }

    func keyCanvasDidTapModeSwitch123() {
        switchPanel(to: .numbers)
    }

    func keyCanvasDidTapLangSwitch() {
        if !isEnglishMode && engine.strokeCount() > 0 {
            let raw = engine.rawInputString()
            clearCompositionState(clearMarkedText: true)
            isInternalProxyMutation = true
            textDocumentProxy.insertText(raw)
            isInternalProxyMutation = false
        }
        isEnglishMode.toggle()
        if !isEnglishMode && settings.autoSpaceAfterMixedEnglish && lastCommittedSpaceMixedEnglish {
            lastCommittedSpaceMixedEnglish = false
        }
        refreshKeyCanvasState()
    }

    func keyCanvasDidTapEnter() {
        if !isEnglishMode && engine.strokeCount() > 0 {
            let raw = engine.rawInputString()
            clearCompositionState(clearMarkedText: true)
            isInternalProxyMutation = true
            textDocumentProxy.insertText(raw)
            isInternalProxyMutation = false
            return
        }
        isInternalProxyMutation = true
        textDocumentProxy.insertText("\n")
        isInternalProxyMutation = false
    }

    // MARK: - CandidateBarDelegate

    func candidateBarDidSelectCandidate(at index: Int) {
        selectCandidate(at: index)
    }

    func candidateBarDidRequestForgetUserWord(_ word: String) {
        pendingForgetWord = word
        forgetLabel.text = "忘记自学习词「\(word)」？"
        forgetBanner.isHidden = false
    }

    @objc private func confirmForgetWord() {
        if let w = pendingForgetWord {
            engine.forgetUserWord(w)
        }
        pendingForgetWord = nil
        forgetBanner.isHidden = true
        if engine.strokeCount() > 0 {
            triggerAsyncDecode()
        }
    }

    @objc private func cancelForgetWord() {
        pendingForgetWord = nil
        forgetBanner.isHidden = true
    }

    func candidateBarDidTapExpand() {
        switchPanel(to: activePanel == .candidateGrid ? .letters : .candidateGrid)
    }

    func candidateBarDidTapSettings() {
        switchPanel(to: activePanel == .quickSettings ? .letters : .quickSettings)
    }

    func candidateBarDidTapNumberPanel() {
        switchPanel(to: activePanel == .numbers ? .letters : .numbers)
    }

    func candidateBarDidTapSymbolPanel() {
        switchPanel(to: activePanel == .symbols ? .letters : .symbols)
    }

    func candidateBarDidTapDismissKeyboard() {
        dismissKeyboard()
    }

    func candidateBarDidTapPasteClipboard(_ text: String) {
        insertDirectText(text)
        dismissedClipboardChangeCount = UIPasteboard.general.changeCount
        candidateBar.setClipboardPreview(nil)
        clipboardHideWork?.cancel()
    }

    func candidateBarDidDismissClipboard() {
        dismissedClipboardChangeCount = UIPasteboard.general.changeCount
        candidateBar.setClipboardPreview(nil)
        clipboardHideWork?.cancel()
    }

    private func checkClipboardForQuickPaste() {
        guard settings.clipboardQuickPaste, hasFullAccess else {
            candidateBar.setClipboardPreview(nil)
            return
        }
        let pb = UIPasteboard.general
        let cc = pb.changeCount
        guard cc != dismissedClipboardChangeCount, cc != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = cc

        if let str = pb.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !str.hasPrefix(SettingsStore.syncPrefix) {
            candidateBar.setClipboardPreview(str)
            clipboardHideWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.candidateBar.setClipboardPreview(nil)
            }
            clipboardHideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: work)
        }
    }
}
