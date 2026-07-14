import Foundation
import CoreGraphics

/// 静态扫描 · 系统快捷键：读取 `com.apple.symbolichotkeys` plist，
/// 解析 macOS 系统级快捷键（Spotlight、截图、调度中心、输入法切换等）。
///
/// 借鉴 HotkeyClash 的公开思路（该 plist 的字段映射与解析方式），
/// 代码基于 Foundation 独立实现。
enum SystemHotkeyScanner {

    /// 扫描系统快捷键，产出统一 ShortcutEntry 列表
    static func scan() -> [ShortcutEntry] {
        guard let dict = loadSymbolicHotkeys() else { return [] }

        var entries: [ShortcutEntry] = []
        for (idKey, rawValue) in dict {
            guard let id = Int(idKey),
                  let item = rawValue as? [String: Any] else { continue }

            // 仅收录已启用的快捷键
            if let enabled = item["enabled"] as? Bool, !enabled { continue }
            if let enabledNum = item["enabled"] as? Int, enabledNum == 0 { continue }

            guard let value = item["value"] as? [String: Any],
                  let params = value["parameters"] as? [Int], params.count >= 3 else { continue }

            let asciiCode = params[0]
            let keyCode = params[1]
            let modifierMask = params[2]

            guard let combo = keyCombo(asciiCode: asciiCode, keyCode: keyCode, modifierMask: modifierMask),
                  !combo.isEmpty else { continue }

            entries.append(
                ShortcutEntry(
                    keyCombo: combo,
                    sourceApp: LT("macOS 系统", "macOS System"),
                    sourcePath: LT("系统设置 › 键盘 › 快捷键", "System Settings › Keyboard › Shortcuts"),
                    action: actionName(for: id),
                    sourceType: .systemHotkey
                )
            )
        }
        return entries
    }

    // MARK: - plist 读取

    private static func loadSymbolicHotkeys() -> [String: Any]? {
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.symbolichotkeys.plist"
        guard let root = NSDictionary(contentsOfFile: path) as? [String: Any],
              let hotkeys = root["AppleSymbolicHotKeys"] as? [String: Any] else {
            return nil
        }
        return hotkeys
    }

    // MARK: - 键组合归一化

    /// 将 (asciiCode, keyCode, modifierMask) 归一化为 "⌃⌥⇧⌘X" 形式
    private static func keyCombo(asciiCode: Int, keyCode: Int, modifierMask: Int) -> String? {
        let mods = modifierString(modifierMask)

        // 优先用虚拟键码映射（可处理方向键、F 键等特殊键）
        var keyName = KeyCodeMap.keyName(keyCode)

        // 若键码未知，退回 ASCII 字符（asciiCode 为 65535 表示无字符）
        if keyName.hasPrefix("key("), asciiCode > 0, asciiCode != 65535,
           let scalar = UnicodeScalar(asciiCode) {
            keyName = String(scalar).uppercased()
        }

        // 既无有效键码也无字符，无法展示
        if keyName.hasPrefix("key("), (asciiCode <= 0 || asciiCode == 65535) {
            return nil
        }
        return mods + keyName
    }

    /// symbolichotkeys 使用 Cocoa NSEvent 修饰键位（device-independent flags）
    private static func modifierString(_ mask: Int) -> String {
        var s = ""
        if mask & 0x40000 != 0 { s += "⌃" }   // Control  (1 << 18)
        if mask & 0x80000 != 0 { s += "⌥" }   // Option   (1 << 19)
        if mask & 0x20000 != 0 { s += "⇧" }   // Shift    (1 << 17)
        if mask & 0x100000 != 0 { s += "⌘" }  // Command  (1 << 20)
        return s
    }

    // MARK: - 功能名映射

    /// 常见系统快捷键 ID → 功能名（未知的以通用名兜底）
    private static let actionNames: [Int: String] = [
        7: LT("聚焦窗口工具栏", "Focus window toolbar"),
        8: LT("打开/关闭全键盘控制", "Turn full keyboard access on/off"),
        9: LT("更改全键盘控制方式", "Change full keyboard access mode"),
        10: LT("聚焦窗口", "Focus the window"),
        11: LT("聚焦下一个窗口", "Focus the next window"),
        12: LT("聚焦程序坞", "Focus the Dock"),
        13: LT("聚焦菜单栏", "Focus the menu bar"),
        15: LT("打开/关闭缩放", "Turn zoom on/off"),
        17: LT("放大", "Zoom in"),
        19: LT("缩小", "Zoom out"),
        21: LT("打开/关闭图像反转", "Turn image smoothing on/off"),
        27: LT("聚焦菜单栏", "Focus the menu bar"),
        28: LT("将屏幕图片存储为文件", "Save picture of screen as a file"),
        29: LT("将屏幕图片拷贝到剪贴板", "Copy picture of screen to clipboard"),
        30: LT("将所选区域图片存储为文件", "Save picture of selected area as a file"),
        31: LT("将所选区域图片拷贝到剪贴板", "Copy picture of selected area to clipboard"),
        32: LT("调度中心（Mission Control）", "Mission Control"),
        33: LT("应用程序窗口", "Application windows"),
        34: LT("调度中心 · 上一个", "Mission Control · previous"),
        35: LT("调度中心 · 下一个", "Mission Control · next"),
        36: LT("显示桌面", "Show Desktop"),
        52: LT("打开/关闭反转颜色", "Turn invert colors on/off"),
        57: LT("聚焦状态菜单", "Focus the status menus"),
        59: LT("选择上一个输入法", "Select the previous input method"),
        60: LT("选择上一个输入源", "Select the previous input source"),
        61: LT("选择下一个输入源", "Select next source in input menu"),
        62: LT("显示字符检视器", "Show Character Viewer"),
        64: LT("聚焦聚焦搜索框（Spotlight）", "Show Spotlight search"),
        65: LT("显示访达搜索窗口（Spotlight）", "Show Finder search window"),
        70: LT("打开/关闭 VoiceOver", "Turn VoiceOver on/off"),
        73: LT("聚焦下一个窗口", "Focus the next window"),
        79: LT("移至左侧一个空间", "Move left a space"),
        80: LT("移至左侧一个空间", "Move left a space"),
        81: LT("移至右侧一个空间", "Move right a space"),
        82: LT("移至右侧一个空间", "Move right a space"),
        118: LT("切换到桌面 1", "Switch to Desktop 1"),
        119: LT("切换到桌面 2", "Switch to Desktop 2"),
        120: LT("切换到桌面 3", "Switch to Desktop 3"),
        160: LT("显示启动台（Launchpad）", "Show Launchpad"),
        162: LT("显示通知中心", "Show Notification Center"),
        163: LT("显示通知中心", "Show Notification Center"),
        175: LT("打开/关闭勿扰模式", "Turn Do Not Disturb on/off"),
        179: LT("打开/关闭勿扰模式", "Turn Do Not Disturb on/off"),
        184: LT("截屏与录屏选项", "Screenshot and recording options"),
        190: LT("使用表情与符号", "Show Emoji & Symbols"),
        222: LT("锁定屏幕", "Lock screen"),
    ]

    private static func actionName(for id: Int) -> String {
        actionNames[id] ?? LT("系统功能 #\(id)", "System function #\(id)")
    }
}
