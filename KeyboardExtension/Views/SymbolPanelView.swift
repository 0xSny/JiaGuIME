import UIKit

final class SymbolPanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    enum Category: Int, CaseIterable {
        case cnPunct = 0
        case enPunct = 1
        case emoji = 2

        var title: String {
            switch self {
            case .cnPunct: return "中文"
            case .enPunct: return "英文"
            case .emoji: return "表情"
            }
        }
    }

    var onInsertSymbol: ((_ text: String, _ cursorOffsetInside: Int) -> Void)?
    var onBackspace: (() -> Void)?
    var onClose: (() -> Void)?

    private var activeCategory: Category = .cnPunct
    private var palette: KeyboardPalette = .crispLight

    private let categoryItems: [Category: [String]] = [
        .cnPunct: ["，", "。", "、", "？", "！", "：", "；", "……", "——", "·",
                   "「」", "『』", "《》", "“”", "（）", "【】", "〈〉", "～", "￥", "％"],
        .enPunct: [",", ".", "?", "!", ":", ";", "'", "\"", "-", "_",
                   "()", "[]", "{}", "<>", "/", "\\", "@", "#", "$", "&", "*", "+", "="],
        .emoji: ["😀", "😂", "🥹", "😊", "😍", "🤔", "😎", "😭", "👍", "🙏",
                 "❤️", "🔥", "✨", "🎉", "👌", "🤝", "💪", "🫡", "🥳", "😴"],
    ]

    private let pairedSymbols: Set<String> = ["「」", "『』", "《》", "“”", "（）", "【】", "〈〉", "()", "[]", "{}", "<>"]

    private let topBar = UIView()
    private var catButtons: [UIButton] = []
    private let backspaceBtn = UIButton(type: .system)
    private let closeBtn = UIButton(type: .system)
    private let collectionView: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 6, left: 8, bottom: 8, right: 8)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        addSubview(topBar)
        for cat in Category.allCases {
            let b = UIButton(type: .system)
            b.tag = cat.rawValue
            b.setTitle(cat.title, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
            b.layer.cornerRadius = 12
            b.addTarget(self, action: #selector(didTapCat(_:)), for: .touchUpInside)
            topBar.addSubview(b)
            catButtons.append(b)
        }

        backspaceBtn.setTitle("⌫", for: .normal)
        backspaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        backspaceBtn.addTarget(self, action: #selector(didTapBackspace), for: .touchUpInside)
        topBar.addSubview(backspaceBtn)

        closeBtn.setTitle("返回", for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        closeBtn.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        topBar.addSubview(closeBtn)

        collectionView.backgroundColor = .clear
        collectionView.delaysContentTouches = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SymbolCell.self, forCellWithReuseIdentifier: "SymbolCell")
        addSubview(collectionView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette(_ palette: KeyboardPalette) {
        self.palette = palette
        backgroundColor = palette.keyboardBackground
        topBar.backgroundColor = palette.candidateBarBackground
        backspaceBtn.setTitleColor(palette.primaryText, for: .normal)
        closeBtn.setTitleColor(palette.accentColor, for: .normal)
        updateCategoryButtons()
        collectionView.reloadData()
    }

    private func updateCategoryButtons() {
        for b in catButtons {
            let sel = (b.tag == activeCategory.rawValue)
            b.backgroundColor = sel ? palette.pillFill : .clear
            b.setTitleColor(sel ? palette.accentColor : palette.primaryText.withAlphaComponent(0.72), for: .normal)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let topH: CGFloat = 38.0
        topBar.frame = CGRect(x: 0, y: 0, width: w, height: topH)
        collectionView.frame = CGRect(x: 0, y: topH, width: w, height: max(0, h - topH))

        closeBtn.frame = CGRect(x: w - 54, y: 0, width: 48, height: topH)
        backspaceBtn.frame = CGRect(x: w - 98, y: 0, width: 44, height: topH)
        let catW: CGFloat = 54.0
        for (i, b) in catButtons.enumerated() {
            b.frame = CGRect(x: 8 + CGFloat(i) * (catW + 4), y: 6, width: catW, height: 26)
        }
    }

    @objc private func didTapCat(_ sender: UIButton) {
        activeCategory = Category(rawValue: sender.tag) ?? .cnPunct
        updateCategoryButtons()
        collectionView.reloadData()
    }

    @objc private func didTapBackspace() { onBackspace?() }
    @objc private func didTapClose() { onClose?() }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categoryItems[activeCategory]?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SymbolCell", for: indexPath) as! SymbolCell
        let text = categoryItems[activeCategory]?[indexPath.item] ?? ""
        cell.configure(text: text, palette: palette)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cols: CGFloat = 5.0
        let w = (collectionView.bounds.width - 16.0 - 6.0 * (cols - 1)) / cols
        return CGSize(width: max(46, floor(w)), height: 38.0)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = categoryItems[activeCategory]?[indexPath.item] else { return }
        let offset = pairedSymbols.contains(item) ? -1 : 0
        onInsertSymbol?(item, offset)
    }

    private final class SymbolCell: UICollectionViewCell {
        private let label = UILabel()
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.cornerRadius = 7.0
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 18)
            contentView.addSubview(label)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            label.frame = contentView.bounds
        }
        func configure(text: String, palette: KeyboardPalette) {
            backgroundColor = palette.keyFill
            label.text = text
            label.textColor = palette.primaryText
        }
    }
}
