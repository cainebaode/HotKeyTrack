import Foundation
import ApplicationServices
import AppKit

/// 静态扫描 · 应用菜单栏快捷键：通过 Accessibility API 遍历运行中应用的
/// 菜单栏，提取每个菜单项的快捷键（cmdChar / cmdVirtualKey + 修饰键）。
///
/// 借鉴 HotkeyClash 的公开思路（AXMenuBar 递归遍历、读取菜单项快捷键属性），
/// 全部基于 Apple Accessibility API 独立实现。
///
/// 依赖辅助功能权限；无权限时返回空列表。
enum MenuBarScanner {

    /// 遍历所有前台可见应用的菜单栏，产出统一 ShortcutEntry 列表。
    /// 注意：AX 调用较慢，调用方应放到后台线程执行。
    static func scan() -> [ShortcutEntry] {
        guard AXIsProcessTrusted() else { return [] }

        var entries: [ShortcutEntry] = []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            guard app.processIdentifier != ownPID else { continue }
            let appName = app.localizedName ?? LT("未知应用", "Unknown app")
            let appPath = app.bundleURL?.path ?? ""

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let menuBar = copyElement(axApp, kAXMenuBarAttribute) else { continue }

            var collected: [ShortcutEntry] = []
            traverse(menuBar, appName: appName, appPath: appPath, depth: 0, into: &collected)
            entries.append(contentsOf: collected)
        }
        return entries
    }

    // MARK: - 递归遍历

    /// 递归深度上限，避免异常深的菜单树导致卡顿
    private static let maxDepth = 6

    private static func traverse(_ element: AXUIElement,
                                 appName: String,
                                 appPath: String,
                                 depth: Int,
                                 into entries: inout [ShortcutEntry]) {
        guard depth <= maxDepth else { return }

        // 尝试从当前元素读取快捷键（仅菜单项有 cmd 属性）
        if let combo = keyCombo(for: element), !combo.isEmpty {
            let action = copyString(element, kAXTitleAttribute) ?? ""
            if !action.isEmpty {
                entries.append(
                    ShortcutEntry(
                        keyCombo: combo,
                        sourceApp: appName,
                        sourcePath: appPath,
                        action: action,
                        sourceType: .menuBar
                    )
                )
            }
        }

        // 递归子元素（菜单栏项 → 菜单 → 菜单项 → 子菜单）
        for child in children(of: element) {
            traverse(child, appName: appName, appPath: appPath, depth: depth + 1, into: &entries)
        }
    }

    // MARK: - 快捷键解析

    /// 由菜单项的 cmdChar / cmdVirtualKey + cmdModifiers 组装键组合
    private static func keyCombo(for element: AXUIElement) -> String? {
        // 修饰键（无该属性说明不是可带快捷键的菜单项）
        guard let modRaw = copyInt(element, kAXMenuItemCmdModifiersAttribute) else { return nil }

        // 主键：优先 cmdChar，其次 cmdVirtualKey
        var keyName = ""
        if let ch = copyString(element, kAXMenuItemCmdCharAttribute),
           !ch.isEmpty, ch != "\0" {
            keyName = ch.uppercased()
        } else if let vk = copyInt(element, kAXMenuItemCmdVirtualKeyAttribute), vk >= 0 {
            let name = KeyCodeMap.keyName(vk)
            if !name.hasPrefix("key(") { keyName = name }
        }

        guard !keyName.isEmpty else { return nil }
        return modifierString(modRaw) + keyName
    }

    /// AX 菜单项修饰键位（kAXMenuItemCmdModifiers）：
    /// bit3(8)=无 Command（否则默认含 Command），bit0(1)=Shift，bit1(2)=Option，bit2(4)=Control
    private static func modifierString(_ mask: Int) -> String {
        var s = ""
        if mask & 0x04 != 0 { s += "⌃" }        // Control
        if mask & 0x02 != 0 { s += "⌥" }        // Option
        if mask & 0x01 != 0 { s += "⇧" }        // Shift
        if mask & 0x08 == 0 { s += "⌘" }        // Command（默认存在，bit3 置位表示无）
        return s
    }

    // MARK: - AX 读取辅助

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard err == .success, let array = value as? [AXUIElement] else { return [] }
        return array
    }

    private static func copyElement(_ element: AXUIElement, _ attr: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success, let v = value else { return nil }
        // AXUIElement 是 CFType，需用 CFGetTypeID 校验
        if CFGetTypeID(v) == AXUIElementGetTypeID() {
            return (v as! AXUIElement)
        }
        return nil
    }

    private static func copyString(_ element: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    private static func copyInt(_ element: AXUIElement, _ attr: String) -> Int? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard err == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }
}
