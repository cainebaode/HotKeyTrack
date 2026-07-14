import Foundation
import Combine

/// 总览扫描页的视图模型：协调 MenuBarScanner + SystemHotkeyScanner 采集，
/// 交由 ConflictAnalyzer 分组判定，产出可供 UI 渲染的冲突分组。
@MainActor
final class OverviewModel: ObservableObject {

    @Published private(set) var groups: [ConflictGroup] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    /// 搜索关键字（P1）：匹配键组合 / 来源应用 / 动作
    @Published var searchText: String = ""

    private let scanQueue = DispatchQueue(label: "com.hotkeytrack.overview.scan", qos: .userInitiated)

    /// 冲突分组数量
    var conflictCount: Int { ConflictAnalyzer.conflictCount(groups) }

    /// 快捷键条目总数
    var totalEntryCount: Int { groups.reduce(0) { $0 + $1.entries.count } }

    /// 按搜索关键字过滤后的分组
    var filteredGroups: [ConflictGroup] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !keyword.isEmpty else { return groups }
        return groups.filter { group in
            if group.keyCombo.lowercased().contains(keyword) { return true }
            return group.entries.contains { entry in
                entry.sourceApp.lowercased().contains(keyword) ||
                entry.action.lowercased().contains(keyword)
            }
        }
    }

    /// 触发一次扫描（后台采集，主线程更新）
    func scan() {
        guard !isScanning else { return }
        isScanning = true

        scanQueue.async { [weak self] in
            var entries = MenuBarScanner.scan()
            entries.append(contentsOf: SystemHotkeyScanner.scan())
            entries.append(contentsOf: ConfigFileScanner.scan())
            let groups = ConflictAnalyzer.analyze(entries)

            Task { @MainActor in
                guard let self else { return }
                self.groups = groups
                self.lastScanDate = Date()
                self.isScanning = false
            }
        }
    }
}
