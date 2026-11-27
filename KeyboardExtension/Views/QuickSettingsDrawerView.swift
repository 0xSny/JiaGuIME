import UIKit

final class QuickSettingsDrawerView: UIView {
    var onSettingsChanged: ((IMESettings) -> Void)?
    var onResetUserLexicon: (() -> Void)?
    var onClose: (() -> Void)?

    private var settings: IMESettings = IMESettings()
    private var palette: KeyboardPalette = .crispLight
    private var learnedCount: Int = 0
    private var isAppGroupSynced: Bool = false

    private let headerBar = UIView()
    private let titleLabel = UILabel()
    private let syncBadgeLabel = UILabel()
    private let closeBtn = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // Interactive controls
    private let inputModeSeg = UISegmentedControl(items: IMEInputMode.allCases.map { $0.displayName })
    private let hintModeSeg = UISegmentedControl(items: ShuangpinHintMode.allCases.map { $0.displayName })
    private let preeditSeg = UISegmentedControl(items: PreeditFormat.allCases.map { $0.displayName })
    private let appearanceSeg = UISegmentedControl(items: AppearanceMode.allCases.map { $0.displayName })
    private let hapticSeg = UISegmentedControl(items: HapticLevel.allCases.map { $0.displayName })
    private let oneHandedSeg = UISegmentedControl(items: OneHandedMode.allCases.map { $0.displayName })

    private let soundSwitch = UISwitch()
    private let soundVolumeSlider = UISlider()
    private let popupSwitch = UISwitch()
    private let swipeSymSwitch = UISwitch()
    private let doubleSpaceSwitch = UISwitch()
    private let fuzzyQuickSwitch = UISwitch()

    private let heightSlider = UISlider()
    private let heightValueLabel = UILabel()
    private let spatialSlider = UISlider()
    private let importSyncBtn = UIButton(type: .system)
    private let clearLexiconBtn = UIButton(type: .system)
    private let statusToastLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        addSubview(headerBar)
        titleLabel.text = "键盘快捷设置"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        headerBar.addSubview(titleLabel)

        syncBadgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        syncBadgeLabel.textAlignment = .center
        syncBadgeLabel.layer.cornerRadius = 8
        syncBadgeLabel.clipsToBounds = true
        headerBar.addSubview(syncBadgeLabel)

        closeBtn.setTitle("完成", for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        closeBtn.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        headerBar.addSubview(closeBtn)

        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -14),
        ])

        addSegmentRow(title: "输入方案", control: inputModeSeg, action: #selector(didChangeSegment(_:)))
        addSegmentRow(title: "双拼键面助记", control: hintModeSeg, action: #selector(didChangeSegment(_:)))
        addSegmentRow(title: "预编辑格式", control: preeditSeg, action: #selector(didChangeSegment(_:)))
        addSegmentRow(title: "外观主题", control: appearanceSeg, action: #selector(didChangeSegment(_:)))
        addSegmentRow(title: "震动反馈", control: hapticSeg, action: #selector(didChangeSegment(_:)))
        addSegmentRow(title: "单手模式", control: oneHandedSeg, action: #selector(didChangeSegment(_:)))

        addSwitchRow(title: "清脆按键音", sw: soundSwitch, action: #selector(didChangeSwitch(_:)))

        soundVolumeSlider.minimumValue = 0.0
        soundVolumeSlider.maximumValue = 1.0
        soundVolumeSlider.addTarget(self, action: #selector(didChangeSlider(_:)), for: .valueChanged)
        addSliderRow(title: "按键音量", slider: soundVolumeSlider, valueLabel: nil)

        addSwitchRow(title: "按键放大气泡", sw: popupSwitch, action: #selector(didChangeSwitch(_:)))
        addSwitchRow(title: "上滑输入数字符号", sw: swipeSymSwitch, action: #selector(didChangeSwitch(_:)))
        addSwitchRow(title: "双击空格句号", sw: doubleSpaceSwitch, action: #selector(didChangeSwitch(_:)))
        addSwitchRow(title: "常用模糊音总开关", sw: fuzzyQuickSwitch, action: #selector(didChangeSwitch(_:)))

        heightSlider.minimumValue = Float(IMESettings.minHeight)
        heightSlider.maximumValue = Float(IMESettings.maxHeight)
        heightSlider.addTarget(self, action: #selector(didChangeSlider(_:)), for: .valueChanged)
        heightValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
        addSliderRow(title: "键盘高度", slider: heightSlider, valueLabel: heightValueLabel)

        spatialSlider.minimumValue = 0.0
        spatialSlider.maximumValue = 2.0
        spatialSlider.addTarget(self, action: #selector(didChangeSlider(_:)), for: .valueChanged)
        addSliderRow(title: "触控纠偏灵敏度", slider: spatialSlider, valueLabel: nil)

        let btnRow = UIStackView()
        btnRow.axis = .horizontal
        btnRow.spacing = 8
        btnRow.distribution = .fillEqually

        importSyncBtn.setTitle("从剪贴板导入宿主配置", for: .normal)
        importSyncBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        importSyncBtn.layer.cornerRadius = 8
        importSyncBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        importSyncBtn.addTarget(self, action: #selector(didTapImportSync), for: .touchUpInside)

        clearLexiconBtn.setTitle("清空自学习词库", for: .normal)
        clearLexiconBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        clearLexiconBtn.layer.cornerRadius = 8
        clearLexiconBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        clearLexiconBtn.addTarget(self, action: #selector(didTapClearLexicon), for: .touchUpInside)

        btnRow.addArrangedSubview(importSyncBtn)
        btnRow.addArrangedSubview(clearLexiconBtn)
        stackView.addArrangedSubview(btnRow)

        statusToastLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusToastLabel.textAlignment = .center
        statusToastLabel.isHidden = true
        stackView.addArrangedSubview(statusToastLabel)
    }

    private func addSegmentRow(title: String, control: UISegmentedControl, action: Selector) {
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        control.addTarget(self, action: action, for: .valueChanged)

        let box = UIStackView(arrangedSubviews: [lbl, control])
        box.axis = .vertical
        box.spacing = 4
        stackView.addArrangedSubview(box)
    }

    private func addSwitchRow(title: String, sw: UISwitch, action: Selector) {
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        sw.addTarget(self, action: action, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [lbl, sw])
        row.axis = .horizontal
        row.alignment = .center
        stackView.addArrangedSubview(row)
    }

    private func addSliderRow(title: String, slider: UISlider, valueLabel: UILabel?) {
        let lbl = UILabel()
        lbl.text = title
        lbl.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        let top = UIStackView(arrangedSubviews: valueLabel != nil ? [lbl, valueLabel!] : [lbl])
        top.axis = .horizontal
        top.alignment = .center

        let box = UIStackView(arrangedSubviews: [top, slider])
        box.axis = .vertical
        box.spacing = 2
        stackView.addArrangedSubview(box)
    }

    func update(settings: IMESettings, palette: KeyboardPalette, learnedCount: Int, isAppGroupSynced: Bool) {
        self.settings = settings
        self.palette = palette
        self.learnedCount = learnedCount
        self.isAppGroupSynced = isAppGroupSynced

        inputModeSeg.selectedSegmentIndex = settings.inputMode.rawValue
        hintModeSeg.selectedSegmentIndex = settings.shuangpinHintMode.rawValue
        preeditSeg.selectedSegmentIndex = settings.preeditFormat.rawValue
        appearanceSeg.selectedSegmentIndex = settings.appearanceMode.rawValue
        hapticSeg.selectedSegmentIndex = settings.hapticLevel.rawValue
        oneHandedSeg.selectedSegmentIndex = settings.oneHandedMode.rawValue

        soundSwitch.isOn = settings.keySoundEnabled
        soundVolumeSlider.value = Float(settings.keySoundVolume)
        popupSwitch.isOn = settings.keyPopupEnabled
        swipeSymSwitch.isOn = settings.swipeUpSymbolsEnabled
        doubleSpaceSwitch.isOn = settings.doubleSpacePeriod
        fuzzyQuickSwitch.isOn = (settings.fuzzyMask != 0)
        heightSlider.value = Float(settings.keyboardHeight)
        heightValueLabel.text = "\(Int(settings.keyboardHeight)) pt"
        spatialSlider.value = Float(settings.spatialSensitivity)

        clearLexiconBtn.setTitle("清空词库 (\(learnedCount)词)", for: .normal)
        syncBadgeLabel.text = isAppGroupSynced ? "AppGroup 已互通" : "键盘独立沙盒"

        applyPalette(palette)
    }

    func applyPalette(_ palette: KeyboardPalette) {
        self.palette = palette
        backgroundColor = palette.keyboardBackground
        headerBar.backgroundColor = palette.candidateBarBackground
        titleLabel.textColor = palette.primaryText
        closeBtn.setTitleColor(palette.accentColor, for: .normal)
        syncBadgeLabel.backgroundColor = palette.pillFill
        syncBadgeLabel.textColor = palette.pillText

        importSyncBtn.backgroundColor = palette.keyFill
        importSyncBtn.setTitleColor(palette.accentColor, for: .normal)
        clearLexiconBtn.backgroundColor = palette.keyFill
        clearLexiconBtn.setTitleColor(.systemRed, for: .normal)
        statusToastLabel.textColor = palette.accentColor

        for sub in stackView.arrangedSubviews {
            if let lbl = sub as? UILabel {
                lbl.textColor = palette.primaryText
            } else if let st = sub as? UIStackView {
                for inner in st.arrangedSubviews {
                    if let l = inner as? UILabel {
                        l.textColor = palette.primaryText
                    } else if let innerSt = inner as? UIStackView {
                        for l2 in innerSt.arrangedSubviews {
                            if let l = l2 as? UILabel { l.textColor = palette.primaryText }
                        }
                    }
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let headerH: CGFloat = 40.0
        headerBar.frame = CGRect(x: 0, y: 0, width: w, height: headerH)
        titleLabel.frame = CGRect(x: 12, y: 0, width: 100, height: headerH)
        syncBadgeLabel.frame = CGRect(x: 116, y: 10, width: 96, height: 20)
        closeBtn.frame = CGRect(x: w - 60, y: 0, width: 52, height: headerH)
        scrollView.frame = CGRect(x: 0, y: headerH, width: w, height: max(0, h - headerH))
    }

    @objc private func didChangeSegment(_ sender: UISegmentedControl) {
        if sender === inputModeSeg, let m = IMEInputMode(rawValue: sender.selectedSegmentIndex) {
            settings.inputMode = m
        } else if sender === hintModeSeg, let m = ShuangpinHintMode(rawValue: sender.selectedSegmentIndex) {
            settings.shuangpinHintMode = m
        } else if sender === preeditSeg, let m = PreeditFormat(rawValue: sender.selectedSegmentIndex) {
            settings.preeditFormat = m
        } else if sender === appearanceSeg, let m = AppearanceMode(rawValue: sender.selectedSegmentIndex) {
            settings.appearanceMode = m
        } else if sender === hapticSeg, let m = HapticLevel(rawValue: sender.selectedSegmentIndex) {
            settings.hapticLevel = m
        } else if sender === oneHandedSeg, let m = OneHandedMode(rawValue: sender.selectedSegmentIndex) {
            settings.oneHandedMode = m
        }
        onSettingsChanged?(settings)
    }

    @objc private func didChangeSwitch(_ sender: UISwitch) {
        if sender === soundSwitch {
            settings.keySoundEnabled = sender.isOn
        } else if sender === popupSwitch {
            settings.keyPopupEnabled = sender.isOn
        } else if sender === swipeSymSwitch {
            settings.swipeUpSymbolsEnabled = sender.isOn
        } else if sender === doubleSpaceSwitch {
            settings.doubleSpacePeriod = sender.isOn
        } else if sender === fuzzyQuickSwitch {
            // Toggle standard common fuzzy groups (z/zh, c/ch, s/sh, an/ang, en/eng, in/ing)
            settings.fuzzyMask = sender.isOn ? ((1 << 0) | (1 << 1) | (1 << 2) | (1 << 6) | (1 << 7) | (1 << 8)) : 0
        }
        onSettingsChanged?(settings)
    }

    @objc private func didChangeSlider(_ sender: UISlider) {
        if sender === soundVolumeSlider {
            settings.keySoundVolume = Double(sender.value)
        } else if sender === heightSlider {
            let rounded = Double(Int(sender.value.rounded()))
            settings.keyboardHeight = rounded
            heightValueLabel.text = "\(Int(rounded)) pt"
        } else if sender === spatialSlider {
            settings.spatialSensitivity = Double(sender.value)
        }
        onSettingsChanged?(settings)
    }

    @objc private func didTapImportSync() {
        let clip = UIPasteboard.general.string ?? ""
        if SettingsStore.shared.importSyncCode(clip) {
            showToast("已成功导入宿主配置与快捷短语")
            onSettingsChanged?(SettingsStore.shared.settings)
        } else {
            showToast("剪贴板中未检测到有效的甲骨同步码")
        }
    }

    @objc private func didTapClearLexicon() {
        onResetUserLexicon?()
        clearLexiconBtn.setTitle("清空词库 (0词)", for: .normal)
        showToast("已清空本地自学习词库")
    }

    private func showToast(_ msg: String) {
        statusToastLabel.text = msg
        statusToastLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.statusToastLabel.isHidden = true
        }
    }

    @objc private func didTapClose() {
        onClose?()
    }
}
