import Foundation

/// 冲突判定引擎：把所有快捷键条目按"归一化键组合"聚合，
/// 同一键组合被 ≥2 个不同来源占用即视为"可能冲突"。
///
/// 借鉴 HotkeyClash 的公开思路（按 key combination 分组聚合），
/// 判定逻辑本项目独立实现，统一为"≥2 来源=可能冲突"。
enum ConflictAnalyzer {

    /// 将快捷键条目分组为 ConflictGroup 列表。
    /// - Parameter entries: 静态扫描产出的所有快捷键条目
    /// - Returns: 按键组合聚合后的分组，冲突组在前、组内条目稳定排序
    static func analyze(_ entries: [ShortcutEntry]) -> [ConflictGroup] {
        // 1. 过滤空键组合（无快捷键的菜单项）
        let valid = entries.filter { !$0.keyCombo.isEmpty }

        // 2. 按归一化键组合聚合
        var buckets: [String: [ShortcutEntry]] = [:]
        for entry in valid {
            buckets[entry.keyCombo, default: []].append(entry)
        }

        // 3. 组装 ConflictGroup，组内条目按来源应用名 + 动作排序
        let groups = buckets.map { combo, items -> ConflictGroup in
            let sorted = items.sorted { lhs, rhs in
                if lhs.sourceApp != rhs.sourceApp { return lhs.sourceApp < rhs.sourceApp }
                return lhs.action < rhs.action
            }
            return ConflictGroup(keyCombo: combo, entries: sorted)
        }

        // 4. 排序：冲突组优先，其次按来源数量降序，最后按键组合字典序
        return groups.sorted { lhs, rhs in
            if lhs.isConflict != rhs.isConflict { return lhs.isConflict }
            if lhs.distinctSourceCount != rhs.distinctSourceCount {
                return lhs.distinctSourceCount > rhs.distinctSourceCount
            }
            return lhs.keyCombo < rhs.keyCombo
        }
    }

    /// 便捷统计：分组中被判定为"可能冲突"的数量
    static func conflictCount(_ groups: [ConflictGroup]) -> Int {
        groups.filter { $0.isConflict }.count
    }
}
