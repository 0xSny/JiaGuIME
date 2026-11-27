import Foundation

enum IMEInputMode: Int, Codable, CaseIterable {
    case fullPinyin = 0
    case xiaoheShuangpin = 1

    var displayName: String {
        switch self {
        case .fullPinyin: return "全拼"
        case .xiaoheShuangpin: return "小鹤双拼"
        }
    }
}

enum ShuangpinHintMode: Int, Codable, CaseIterable {
    case full = 0
    case minimal = 1
    case hidden = 2

    var displayName: String {
        switch self {
        case .full: return "完整助记"
        case .minimal: return "极简韵母"
        case .hidden: return "盲打隐藏"
        }
    }
}

enum PreeditFormat: Int, Codable, CaseIterable {
    case expandedFullPinyin = 0
    case rawCodes = 1

    var displayName: String {
        switch self {
        case .expandedFullPinyin: return "展开全拼"
        case .rawCodes: return "原始双拼"
        }
    }
}

enum HapticLevel: Int, Codable, CaseIterable {
    case off = 0
    case light = 1
    case crisp = 2
    case strong = 3

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .light: return "轻微"
        case .crisp: return "清脆"
        case .strong: return "强劲"
        }
    }
}

enum OneHandedMode: Int, Codable, CaseIterable {
    case full = 0
    case left = 1
    case right = 2

    var displayName: String {
        switch self {
        case .full: return "完整"
        case .left: return "居左"
        case .right: return "居右"
        }
    }
}

enum AppearanceMode: Int, Codable, CaseIterable {
    case followSystem = 0
    case crispLight = 1
    case pureWhite = 2
    case dark = 3

    var displayName: String {
        switch self {
        case .followSystem: return "跟随系统"
        case .crispLight: return "清爽浅色"
        case .pureWhite: return "纯净亮白"
        case .dark: return "深色模式"
        }
    }
}

struct FuzzyGroupOption: Identifiable {
    let bit: UInt32
    let title: String

    var id: UInt32 { bit }

    static let allGroups: [FuzzyGroupOption] = [
        FuzzyGroupOption(bit: 1 << 0, title: "z ↔ zh"),
        FuzzyGroupOption(bit: 1 << 1, title: "c ↔ ch"),
        FuzzyGroupOption(bit: 1 << 2, title: "s ↔ sh"),
        FuzzyGroupOption(bit: 1 << 3, title: "l ↔ n"),
        FuzzyGroupOption(bit: 1 << 4, title: "f ↔ h"),
        FuzzyGroupOption(bit: 1 << 5, title: "r ↔ l"),
        FuzzyGroupOption(bit: 1 << 6, title: "an ↔ ang"),
        FuzzyGroupOption(bit: 1 << 7, title: "en ↔ eng"),
        FuzzyGroupOption(bit: 1 << 8, title: "in ↔ ing"),
        FuzzyGroupOption(bit: 1 << 9, title: "ian ↔ iang"),
        FuzzyGroupOption(bit: 1 << 10, title: "uan ↔ uang"),
    ]
}

struct CustomPhraseItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var abbr: String
    var text: String
}

struct IMESettings: Codable, Equatable {
    var inputMode: IMEInputMode = .fullPinyin
    var shuangpinHintMode: ShuangpinHintMode = .full
    var preeditFormat: PreeditFormat = .expandedFullPinyin

    var hapticLevel: HapticLevel = .crisp
    var keySoundEnabled: Bool = true
    var keySoundVolume: Double = 0.75
    var keyPopupEnabled: Bool = true

    var keyboardHeight: Double = 216.0
    var oneHandedMode: OneHandedMode = .full
    var swipeUpSymbolsEnabled: Bool = true

    var fuzzyMask: UInt32 = 0
    var spatialSensitivity: Double = 1.0
    var autoSpaceAfterMixedEnglish: Bool = true
    var doubleSpacePeriod: Bool = true

    var spaceCursorSensitivity: Double = 1.0
    var backspaceLeftSwipeClear: Bool = true
    var clipboardQuickPaste: Bool = true
    var appearanceMode: AppearanceMode = .followSystem

    var customPhrases: [CustomPhraseItem] = [
        CustomPhraseItem(abbr: "yx", text: "example@icloud.com"),
        CustomPhraseItem(abbr: "dz", text: "请填写常用收货地址"),
    ]

    static let defaultHeight: Double = 216.0
    static let minHeight: Double = 185.0
    static let maxHeight: Double = 285.0
}
