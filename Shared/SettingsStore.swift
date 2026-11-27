import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    static let appGroupIdentifier = "group.com.custom.ime.shared"
    static let settingsKey = "jiagu.ime.settings.v1"
    static let darwinNotificationName = "com.custom.ime.settings.changed"
    static let syncPrefix = "JIAGU_CFG_V1:"

    @Published var settings: IMESettings {
        didSet {
            if !isApplyingExternalUpdate && settings != oldValue {
                save(settings)
            }
        }
    }

    let isAppGroupAvailable: Bool
    private let groupDefaults: UserDefaults?
    private var isApplyingExternalUpdate = false
    var onExternalSettingsChanged: ((IMESettings) -> Void)?

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        )
        let suite = (containerURL != nil) ? UserDefaults(suiteName: Self.appGroupIdentifier) : nil
        self.groupDefaults = suite
        self.isAppGroupAvailable = (containerURL != nil && suite != nil)
        self.settings = Self.loadInitial(from: suite)
        registerDarwinObserver()
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    private static func loadInitial(from groupDefaults: UserDefaults?) -> IMESettings {
        if let groupDefaults,
           let data = groupDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(IMESettings.self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(IMESettings.self, from: data) {
            return decoded
        }
        return IMESettings()
    }

    func save(_ value: IMESettings) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
        if let groupDefaults {
            groupDefaults.set(data, forKey: Self.settingsKey)
        }
        postDarwinNotification()
    }

    func reloadFromDisk() {
        let loaded = Self.loadInitial(from: groupDefaults)
        if loaded != settings {
            isApplyingExternalUpdate = true
            settings = loaded
            isApplyingExternalUpdate = false
            onExternalSettingsChanged?(loaded)
        }
    }

    func exportSyncCode() -> String? {
        guard let data = try? JSONEncoder().encode(settings) else { return nil }
        return Self.syncPrefix + data.base64EncodedString()
    }

    @discardableResult
    func importSyncCode(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Self.syncPrefix) else { return false }
        let b64 = String(trimmed.dropFirst(Self.syncPrefix.count))
        guard let data = Data(base64Encoded: b64),
              let decoded = try? JSONDecoder().decode(IMESettings.self, from: data) else {
            return false
        }
        settings = decoded
        onExternalSettingsChanged?(decoded)
        return true
    }

    static func userLexiconStorageDirectory() -> String {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let dir = groupURL.appendingPathComponent("JiaGuUserLexicon", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.path
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("JiaGuUserLexicon", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    private func postDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(Self.darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    private func registerDarwinObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPtr = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observerPtr,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let store = Unmanaged<SettingsStore>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    store.reloadFromDisk()
                }
            },
            Self.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }
}
