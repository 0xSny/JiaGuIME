import UIKit

final class CandidateGridView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    enum LengthFilter: Int, CaseIterable {
        case all = 0
        case one = 1
        case two = 2
        case three = 3
        case multi = 4

        var title: String {
            switch self {
            case .all: return "全部"
            case .one: return "单字"
            case .two: return "二字"
            case .three: return "三字"
            case .multi: return "多字"
            }
        }
    }

    var onSelectCandidate: ((Int) -> Void)?
    var onClose: (() -> Void)?

    private var allCandidates: [JiaGuCandidateObjC] = []
    private var filteredIndices: [Int] = []
    private var activeFilter: LengthFilter = .all
    private var palette: KeyboardPalette = .crispLight

    private let headerView = UIView()
    private var filterButtons: [UIButton] = []
    private let closeButton = UIButton(type: .system)
    private let collectionView: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 6, left: 8, bottom: 8, right: 8)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        addSubview(headerView)
        for filter in LengthFilter.allCases {
            let btn = UIButton(type: .system)
            btn.tag = filter.rawValue
            btn.setTitle(filter.title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 12
            btn.addTarget(self, action: #selector(didTapFilter(_:)), for: .touchUpInside)
            headerView.addSubview(btn)
            filterButtons.append(btn)
        }

        closeButton.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        headerView.addSubview(closeButton)

        collectionView.backgroundColor = .clear
        collectionView.delaysContentTouches = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GridCell.self, forCellWithReuseIdentifier: "GridCell")
        addSubview(collectionView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette(_ palette: KeyboardPalette) {
        self.palette = palette
        backgroundColor = palette.keyboardBackground
        headerView.backgroundColor = palette.candidateBarBackground
        closeButton.tintColor = palette.primaryText
        updateFilterButtonsAppearance()
        collectionView.reloadData()
    }

    func updateCandidates(_ candidates: [JiaGuCandidateObjC]) {
        self.allCandidates = candidates
        applyFilter()
    }

    private func applyFilter() {
        filteredIndices.removeAll(keepingCapacity: true)
        for (idx, c) in allCandidates.enumerated() {
            let len = c.text.count
            switch activeFilter {
            case .all: filteredIndices.append(idx)
            case .one: if len == 1 { filteredIndices.append(idx) }
            case .two: if len == 2 { filteredIndices.append(idx) }
            case .three: if len == 3 { filteredIndices.append(idx) }
            case .multi: if len >= 4 { filteredIndices.append(idx) }
            }
        }
        updateFilterButtonsAppearance()
        collectionView.reloadData()
    }

    private func updateFilterButtonsAppearance() {
        for btn in filterButtons {
            let isSelected = (btn.tag == activeFilter.rawValue)
            btn.backgroundColor = isSelected ? palette.pillFill : .clear
            btn.setTitleColor(isSelected ? palette.accentColor : palette.primaryText.withAlphaComponent(0.72), for: .normal)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let headerH: CGFloat = 38.0
        headerView.frame = CGRect(x: 0, y: 0, width: w, height: headerH)
        collectionView.frame = CGRect(x: 0, y: headerH, width: w, height: max(0, h - headerH))

        closeButton.frame = CGRect(x: w - 44, y: 0, width: 44, height: headerH)
        let btnW: CGFloat = min(56.0, (w - 58.0) / CGFloat(filterButtons.count))
        for (i, btn) in filterButtons.enumerated() {
            btn.frame = CGRect(x: 8 + CGFloat(i) * (btnW + 2), y: 6, width: btnW, height: 26)
        }
    }

    @objc private func didTapFilter(_ sender: UIButton) {
        activeFilter = LengthFilter(rawValue: sender.tag) ?? .all
        applyFilter()
    }

    @objc private func didTapClose() {
        onClose?()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredIndices.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GridCell", for: indexPath) as! GridCell
        let cand = allCandidates[filteredIndices[indexPath.item]]
        cell.configure(text: cand.text, palette: palette)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cand = allCandidates[filteredIndices[indexPath.item]]
        let textW = (cand.text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 17)]).width
        return CGSize(width: max(56.0, ceil(textW) + 22.0), height: 38.0)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let originalIdx = filteredIndices[indexPath.item]
        onSelectCandidate?(originalIdx)
    }

    private final class GridCell: UICollectionViewCell {
        private let label = UILabel()
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.cornerRadius = 7.0
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
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
