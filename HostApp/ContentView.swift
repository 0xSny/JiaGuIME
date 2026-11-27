import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var store = SettingsStore.shared
    @State private var sandboxText: String = ""
    @State private var newAbbr: String = ""
    @State private var newPhrase: String = ""
    @State private var syncBanner: String?
    @State private var showResetConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "keyboard.fill")
                                .foregroundColor(.accentColor)
                            Text("实时打字测试沙盒")
                                .font(.headline)
                            Spacer()
                            Text(store.settings.inputMode.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                        SandboxTextView(text: $sandboxText)
                            .frame(height: 88)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                        HStack {
                            Button("前往系统设置启用键盘") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.subheadline)
                            Spacer()
                            Button("清空") { sandboxText = "" }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text(store.isAppGroupAvailable
                         ? "App Group 已连通：宿主设置修改将毫秒级同步至键盘。"
                         : "当前为个人证书自签隔离沙盒模式：推荐直接使用键盘顶部工具栏的「快捷设置」，或点击下方复制同步码导入键盘。")
                }

                Section("输入方案与小鹤双拼") {
                    Picker("输入方案", selection: $store.settings.inputMode) {
                        ForEach(IMEInputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("双拼键面助记", selection: $store.settings.shuangpinHintMode) {
                        ForEach(ShuangpinHintMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("行内预编辑格式", selection: $store.settings.preeditFormat) {
                        ForEach(PreeditFormat.allCases, id: \.self) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                }

                Section("手感与声效") {
                    Picker("触感震动", selection: $store.settings.hapticLevel) {
                        ForEach(HapticLevel.allCases, id: \.self) { lv in
                            Text(lv.displayName).tag(lv)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("清脆按键音 (不打断音乐)", isOn: $store.settings.keySoundEnabled)

                    if store.settings.keySoundEnabled {
                        HStack {
                            Text("按键音量")
                            Slider(value: $store.settings.keySoundVolume, in: 0.0...1.0)
                        }
                    }

                    Toggle("按下放大气泡", isOn: $store.settings.keyPopupEnabled)
                }

                Section("布局与尺寸") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("键盘高度")
                            Spacer()
                            Text("\(Int(store.settings.keyboardHeight)) pt")
                                .foregroundColor(.secondary)
                            Button("恢复默认") {
                                store.settings.keyboardHeight = IMESettings.defaultHeight
                            }
                            .font(.caption)
                        }
                        Slider(value: $store.settings.keyboardHeight,
                               in: IMESettings.minHeight...IMESettings.maxHeight,
                               step: 1)
                    }

                    Picker("单手模式", selection: $store.settings.oneHandedMode) {
                        ForEach(OneHandedMode.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("按键上滑输入数字与符号", isOn: $store.settings.swipeUpSymbolsEnabled)
                }

                Section("纠错与混输") {
                    NavigationLink("11 组独立模糊音设置") {
                        FuzzyPinyinSettingsView(fuzzyMask: $store.settings.fuzzyMask)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("邻键空间纠偏灵敏度")
                            Spacer()
                            Text(String(format: "%.1f", store.settings.spatialSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.settings.spatialSensitivity, in: 0.0...2.0, step: 0.1)
                    }

                    Toggle("中英混输自动空格", isOn: $store.settings.autoSpaceAfterMixedEnglish)
                    Toggle("双击空格快捷句号", isOn: $store.settings.doubleSpacePeriod)
                }

                Section("手势、外观与自学习词库") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("空格移动光标灵敏度")
                            Spacer()
                            Text(String(format: "%.1f", store.settings.spaceCursorSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.settings.spaceCursorSensitivity, in: 0.5...2.0, step: 0.1)
                    }

                    Toggle("退格左滑一键清空拼音", isOn: $store.settings.backspaceLeftSwipeClear)
                    Toggle("剪贴板快捷粘贴胶囊", isOn: $store.settings.clipboardQuickPaste)

                    Picker("外观模式", selection: $store.settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }

                    Button("复制同步码 (用于自签沙盒一键导入键盘)") {
                        if let code = store.exportSyncCode() {
                            UIPasteboard.general.string = code
                            syncBanner = "已复制同步码，请在键盘右上「设置」点击导入。"
                        }
                    }
                    if let syncBanner {
                        Text(syncBanner)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }

                    Button("重置个人自学习词库", role: .destructive) {
                        showResetConfirm = true
                    }
                    .alert("确认重置自学习词库？", isPresented: $showResetConfirm) {
                        Button("取消", role: .cancel) {}
                        Button("重置", role: .destructive) {
                            let dir = SettingsStore.userLexiconStorageDirectory()
                            try? FileManager.default.removeItem(atPath: dir + "/user_snapshot.dat")
                            try? FileManager.default.removeItem(atPath: dir + "/user_wal.log")
                        }
                    } message: {
                        Text("将清除本地积累的个人高频词、自动造词与上下文搭配记忆。")
                    }
                }

                Section("自定义快捷短语") {
                    ForEach(store.settings.customPhrases) { item in
                        HStack {
                            Text(item.abbr)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .frame(width: 68, alignment: .leading)
                            Text(item.text)
                                .lineLimit(1)
                        }
                    }
                    .onDelete { offsets in
                        store.settings.customPhrases.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("缩写(如 yx)", text: $newAbbr)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(width: 96)
                        TextField("展开文本", text: $newPhrase)
                        Button("添加") {
                            let a = newAbbr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            let t = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !a.isEmpty, !t.isEmpty else { return }
                            store.settings.customPhrases.append(CustomPhraseItem(abbr: a, text: t))
                            newAbbr = ""
                            newPhrase = ""
                        }
                    }
                }
            }
            .navigationTitle("甲骨输入法")
        }
    }
}

private struct FuzzyPinyinSettingsView: View {
    @Binding var fuzzyMask: UInt32

    var body: some View {
        List {
            ForEach(FuzzyGroupOption.allGroups) { opt in
                Toggle(opt.title, isOn: Binding(
                    get: { (fuzzyMask & opt.bit) != 0 },
                    set: { enabled in
                        if enabled { fuzzyMask |= opt.bit }
                        else { fuzzyMask &= ~opt.bit }
                    }
                ))
            }
        }
        .navigationTitle("模糊音设置")
    }
}

private struct SandboxTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SandboxTextView
        init(_ parent: SandboxTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
