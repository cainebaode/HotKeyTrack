import Foundation
import CoreGraphics

/// 键码 → 可读名称映射，以及修饰键符号拼装。
/// 纯工具，基于公开的 macOS 虚拟键码常量整理。
enum KeyCodeMap {

    /// 常见虚拟键码 → 键名（覆盖主要按键，未知的以 key(code) 兜底）
    private static let names: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        63: "fn", 179: LT("fn(双击)", "fn (double-tap)")
    ]

    /// 修饰键符号（按惯例顺序：⌃⌥⇧⌘）
    static func modifierString(_ flags: CGEventFlags) -> String {
        var s = ""
        if flags.contains(.maskControl) { s += "⌃" }
        if flags.contains(.maskAlternate) { s += "⌥" }
        if flags.contains(.maskShift) { s += "⇧" }
        if flags.contains(.maskCommand) { s += "⌘" }
        return s
    }

    /// 键名（无修饰键）
    static func keyName(_ keyCode: Int) -> String {
        names[keyCode] ?? "key(\(keyCode))"
    }

    /// 修饰键英文详情（用于 P1-3 高级排查展示），如 "⌃Control ⌘Command"
    static func modifierDetail(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("⌃Control") }
        if flags.contains(.maskAlternate) { parts.append("⌥Option") }
        if flags.contains(.maskShift) { parts.append("⇧Shift") }
        if flags.contains(.maskCommand) { parts.append("⌘Command") }
        if flags.contains(.maskSecondaryFn) { parts.append("fn") }
        return parts.joined(separator: " ")
    }

    /// 组合成完整显示串
    static func describe(keyCode: Int, flags: CGEventFlags, type: CGEventType) -> String {
        // Fn 单独按下 / 系统合成事件
        if keyCode == 63 { return "fn" }
        if type == .flagsChanged {
            // 到这里说明含 Fn 修饰但不是 63，展示为 fn + 组合
            let mods = modifierString(flags)
            return mods.isEmpty ? "fn" : "fn \(mods)"
        }

        let mods = modifierString(flags)
        let name = keyName(keyCode)
        if flags.contains(.maskSecondaryFn) {
            return "fn \(mods)\(name)"
        }
        return "\(mods)\(name)"
    }
}
