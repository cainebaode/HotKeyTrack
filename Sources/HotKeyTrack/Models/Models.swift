import Foundation

// MARK: - 快捷键来源类型

/// 快捷键/占用的来源类型
enum SourceType: String, Codable {
    case menuBar        // 应用菜单栏快捷键
    case systemHotkey   // macOS 系统快捷键
    case configFile     // 配置文件（Karabiner/skhd 等）
    case runtime        // 运行时捕获的响应源（实时诊断）
}

// MARK: - 静态扫描：一条快捷键记录

/// 总览扫描得到的一条快捷键条目
struct ShortcutEntry: Identifiable, Hashable {
    let id = UUID()
    let keyCombo: String    // 归一化后的键组合，如 "⌘⇧G"
    let sourceApp: String   // 来源应用名
    let sourcePath: String  // 来源应用/配置路径
    let action: String      // 对应动作/菜单名
    let sourceType: SourceType
}

// MARK: - 实时诊断：一条响应源记录

/// 实时诊断中，一次按键触发后捕获到的响应源
struct ResponderEntry: Identifiable, Hashable {
    let id = UUID()
    let processName: String
    let processPath: String
    let pid: Int
    let windowName: String
    let timestamp: Date
    var windowLayer: Int = 0        // 窗口图层（辅助判断）
    var windowSize: String = ""     // 如 "340x300"
    var signalKind: ResponderSignal = .window   // 响应来源信号类型

    /// 展示用友好名：Window Server 渲染的面板统一标注为“系统界面”
    var displayName: String {
        switch processName {
        case "Window Server", "WindowServer": return LT("系统界面（系统渲染）", "System UI (system-rendered)")
        default: return processName
        }
    }
}

/// 响应源信号来源
enum ResponderSignal: String, Codable {
    case window     // 新增窗口
    case appActive  // 前台应用切换
}

// MARK: - 冲突分组

/// 同一键组合下的多个来源，用于冲突判定与总览展示
struct ConflictGroup: Identifiable, Hashable {
    let id = UUID()
    let keyCombo: String
    let entries: [ShortcutEntry]   // 占用该键组合的所有快捷键条目

    /// 判定规则：≥2 个不同来源即视为"可能冲突"
    var isConflict: Bool { distinctSourceCount >= 2 }

    /// 去重后的来源数量（同一 App 的同名动作只算一次）
    var distinctSourceCount: Int {
        Set(entries.map { "\($0.sourceApp)|\($0.action)" }).count
    }

    /// 占用该键组合的来源应用名列表（去重、保持出现顺序）
    var sourceApps: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for e in entries where !seen.contains(e.sourceApp) {
            seen.insert(e.sourceApp)
            result.append(e.sourceApp)
        }
        return result
    }
}
