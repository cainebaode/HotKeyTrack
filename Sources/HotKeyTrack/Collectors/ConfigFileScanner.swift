import Foundation

/// 静态扫描 · 配置文件（P1-2）：解析常见第三方热键守护进程的配置文件，
/// 把它们注册的全局热键也纳入总览与冲突判定。
///
/// 覆盖：
/// - skhd（`~/.config/skhd/skhdrc` 或 `~/.skhdrc`）
/// - Karabiner-Elements（`~/.config/karabiner/karabiner.json` 的 complex_modifications）
///
/// 借鉴 HotkeyClash「每个配置文件一个独立解析方法」的结构组织，
/// 具体字段解析基于各工具的公开格式独立实现。文件不存在时静默跳过。
enum ConfigFileScanner {

    /// 扫描所有已知配置文件，产出统一 ShortcutEntry 列表
    static func scan() -> [ShortcutEntry] {
        var entries: [ShortcutEntry] = []
        entries.append(contentsOf: scanSkhd())
        entries.append(contentsOf: scanKarabiner())
        return entries
    }

    // MARK: - skhd

    private static func scanSkhd() -> [ShortcutEntry] {
        let home = NSHomeDirectory()
        let candidates = [
            home + "/.config/skhd/skhdrc",
            home + "/.skhdrc",
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return []
        }

        var entries: [ShortcutEntry] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // 跳过空行、注释、模式声明（:: 开头/包含）
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("::") { continue }

            // 形如：<mods> - <key> : <command>
            guard let colon = line.range(of: " : ") ?? line.range(of: ":") else { continue }
            let hotkeyPart = String(line[line.startIndex..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
            let command = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces)

            // 分离修饰键与主键：以第一个 " - " 或 "-" 分隔
            let segments = hotkeyPart.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            guard segments.count == 2 else { continue }
            let modTokens = segments[0].components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
            let keyToken = segments[1]
            guard !keyToken.isEmpty else { continue }

            let mods = modifierSymbols(fromTokens: modTokens)
            guard let keyName = normalizeKey(keyToken) else { continue }
            let combo = mods + keyName

            entries.append(
                ShortcutEntry(
                    keyCombo: combo,
                    sourceApp: "skhd",
                    sourcePath: path,
                    action: command.isEmpty ? LT("自定义热键", "Custom hotkey") : command,
                    sourceType: .configFile
                )
            )
        }
        return entries
    }

    // MARK: - Karabiner-Elements

    private static func scanKarabiner() -> [ShortcutEntry] {
        let path = NSHomeDirectory() + "/.config/karabiner/karabiner.json"
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = root["profiles"] as? [[String: Any]] else {
            return []
        }

        var entries: [ShortcutEntry] = []
        for profile in profiles {
            // 仅取当前选中的 profile，避免重复
            if let selected = profile["selected"] as? Bool, selected == false { continue }
            guard let complex = profile["complex_modifications"] as? [String: Any],
                  let rules = complex["rules"] as? [[String: Any]] else { continue }

            for rule in rules {
                let ruleDesc = (rule["description"] as? String) ?? LT("Karabiner 规则", "Karabiner rule")
                guard let manipulators = rule["manipulators"] as? [[String: Any]] else { continue }
                for m in manipulators {
                    guard let from = m["from"] as? [String: Any] else { continue }
                    guard let combo = comboFromKarabiner(from) else { continue }
                    entries.append(
                        ShortcutEntry(
                            keyCombo: combo,
                            sourceApp: "Karabiner-Elements",
                            sourcePath: path,
                            action: ruleDesc,
                            sourceType: .configFile
                        )
                    )
                }
            }
        }
        return entries
    }

    /// 由 Karabiner `from` 字段（key_code + modifiers.mandatory）拼装键组合
    private static func comboFromKarabiner(_ from: [String: Any]) -> String? {
        guard let keyCode = from["key_code"] as? String else { return nil }
        var modTokens: [String] = []
        if let modifiers = from["modifiers"] as? [String: Any],
           let mandatory = modifiers["mandatory"] as? [String] {
            modTokens = mandatory
        }
        let mods = modifierSymbols(fromTokens: modTokens)
        guard let keyName = normalizeKey(keyCode) else { return nil }
        return mods + keyName
    }

    // MARK: - 归一化辅助

    /// 把修饰键关键字集合转成 "⌃⌥⇧⌘" 顺序的符号串（兼容 skhd 与 Karabiner 写法）
    private static func modifierSymbols(fromTokens tokens: [String]) -> String {
        var ctrl = false, opt = false, shift = false, cmd = false
        for raw in tokens {
            switch raw.lowercased() {
            case "ctrl", "control", "lctrl", "rctrl", "left_control", "right_control":
                ctrl = true
            case "alt", "option", "opt", "lalt", "ralt", "left_option", "right_option", "left_alt", "right_alt":
                opt = true
            case "shift", "lshift", "rshift", "left_shift", "right_shift":
                shift = true
            case "cmd", "command", "lcmd", "rcmd", "left_command", "right_command", "gui":
                cmd = true
            case "hyper":                       // hyper = ⌃⌥⇧⌘
                ctrl = true; opt = true; shift = true; cmd = true
            case "meh":                         // meh = ⌃⌥⇧
                ctrl = true; opt = true; shift = true
            default:
                break                           // fn / 其他修饰键忽略（不参与冲突键组合归一化）
            }
        }
        var s = ""
        if ctrl { s += "⌃" }
        if opt { s += "⌥" }
        if shift { s += "⇧" }
        if cmd { s += "⌘" }
        return s
    }

    /// 把 skhd / Karabiner 的键名统一为展示用键名（与其它扫描器一致）
    private static func normalizeKey(_ token: String) -> String? {
        let t = token.lowercased()
        if let special = specialKeyNames[t] { return special }
        // 单字符键（字母/数字/符号）直接大写
        if token.count == 1 { return token.uppercased() }
        // 0xNN 十六进制键码
        if t.hasPrefix("0x"), let code = Int(t.dropFirst(2), radix: 16) {
            let name = KeyCodeMap.keyName(code)
            return name.hasPrefix("key(") ? nil : name
        }
        return nil
    }

    /// skhd / Karabiner 常见特殊键名 → 展示符号
    private static let specialKeyNames: [String: String] = [
        "space": "Space", "spacebar": "Space",
        "return": "↩", "return_or_enter": "↩", "enter": "↩",
        "tab": "⇥",
        "escape": "⎋", "esc": "⎋",
        "delete": "⌫", "backspace": "⌫", "delete_or_backspace": "⌫",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "left_arrow": "←", "right_arrow": "→", "up_arrow": "↑", "down_arrow": "↓",
        "f1": "F1", "f2": "F2", "f3": "F3", "f4": "F4", "f5": "F5", "f6": "F6",
        "f7": "F7", "f8": "F8", "f9": "F9", "f10": "F10", "f11": "F11", "f12": "F12",
        "hyphen": "-", "equal_sign": "=", "slash": "/", "backslash": "\\",
        "comma": ",", "period": ".", "semicolon": ";", "quote": "'",
        "open_bracket": "[", "close_bracket": "]", "grave_accent_and_tilde": "`",
    ]
}
