import SwiftUI

/// 页面一：总览扫描（M3 实现）
/// 扫描运行中应用菜单栏 + 系统快捷键，按键组合分组，冲突置顶高亮。
struct OverviewView: View {
    @EnvironmentObject var permission: PermissionManager
    @StateObject private var model = OverviewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            searchBar
            content
        }
        .onAppear {
            // 首次进入且有权限时自动扫描一次
            if permission.isTrusted && model.lastScanDate == nil {
                model.scan()
            }
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                model.scan()
            } label: {
                Label(model.isScanning ? LT("扫描中…", "Scanning…") : LT("重新扫描", "Rescan"),
                      systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isScanning || !permission.isTrusted)

            Spacer()

            if let date = model.lastScanDate {
                Text(summaryText(date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func summaryText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let time = f.string(from: date)
        return LT("共 \(model.totalEntryCount) 条 · 可能冲突 \(model.conflictCount) 组 · \(time)",
                  "\(model.totalEntryCount) entries · \(model.conflictCount) possible conflicts · \(time)")
    }

    // MARK: - 搜索框（P1）

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField(LT("搜索快捷键、应用或功能…", "Search shortcuts, apps or actions…"), text: $model.searchText)
                .textFieldStyle(.plain)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if !permission.isTrusted {
            centeredHint(icon: "lock.shield",
                         title: LT("需要辅助功能权限", "Accessibility permission required"),
                         detail: LT("授权后可扫描各应用菜单栏与系统快捷键。", "Grant access to scan app menu bars and system shortcuts."))
        } else if model.isScanning && model.lastScanDate == nil {
            centeredProgress
        } else if model.lastScanDate == nil {
            centeredHint(icon: "list.bullet.rectangle",
                         title: LT("尚未扫描", "Not scanned yet"),
                         detail: LT("点击右上角「重新扫描」，采集当前生效的快捷键。", "Click “Rescan” at the top right to collect the shortcuts currently in effect."))
        } else if model.filteredGroups.isEmpty {
            centeredHint(icon: "magnifyingglass",
                         title: model.searchText.isEmpty ? LT("未扫描到快捷键", "No shortcuts found") : LT("无匹配结果", "No matches"),
                         detail: model.searchText.isEmpty ? LT("请确认已授权，并有前台应用在运行。", "Make sure access is granted and some apps are running.") : LT("换个关键字试试。", "Try a different keyword."))
        } else {
            groupList
        }
    }

    private var groupList: some View {
        let conflicts = model.filteredGroups.filter { $0.isConflict }
        let normals = model.filteredGroups.filter { !$0.isConflict }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if !conflicts.isEmpty {
                    sectionHeader(LT("⚠️ 可能冲突", "⚠️ Possible conflicts"), count: conflicts.count, tint: .red)
                    ForEach(conflicts) { GroupRow(group: $0, conflict: true) }
                }
                if !normals.isEmpty {
                    sectionHeader(LT("✅ 无冲突", "✅ No conflict"), count: normals.count, tint: .secondary)
                    ForEach(normals) { GroupRow(group: $0, conflict: false) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func sectionHeader(_ title: String, count: Int, tint: Color) -> some View {
        HStack {
            Text("\(title) (\(count))")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(tint == .secondary ? .secondary : tint)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var centeredProgress: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(LT("扫描中，请稍候…", "Scanning current apps’ shortcuts…"))
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centeredHint(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text(title).font(.callout).foregroundStyle(.tertiary)
            Text(detail)
                .font(.caption).foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 分组行

private struct GroupRow: View {
    let group: ConflictGroup
    let conflict: Bool
    @State private var expanded: Bool

    init(group: ConflictGroup, conflict: Bool) {
        self.group = group
        self.conflict = conflict
        // 默认全部折叠，点击标题展开查看占用来源
        _expanded = State(initialValue: false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(group.keyCombo)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(conflict ? .red : .primary)

                    Text(LT("\(group.distinctSourceCount) 个来源", "\(group.distinctSourceCount) sources"))
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(conflict ? Color.red.opacity(0.15) : Color.secondary.opacity(0.12))
                        .foregroundStyle(conflict ? .red : .secondary)
                        .clipShape(Capsule())

                    Spacer()

                    // 折叠时预览来源应用名
                    if !expanded {
                        Text(group.sourceApps.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.entries) { entry in
                        EntryRow(entry: entry)
                    }
                }
                .padding(.leading, 24).padding(.trailing, 12).padding(.bottom, 8)
            }
        }
        .background(conflict ? Color.red.opacity(0.04) : Color.clear)
    }
}

// MARK: - 单条快捷键条目

private struct EntryRow: View {
    let entry: ShortcutEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.sourceApp)
                        .font(.body).fontWeight(.medium)
                    Text(entry.action)
                        .font(.callout).foregroundStyle(.secondary)
                }
                if !entry.sourcePath.isEmpty {
                    Text(entry.sourcePath)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private var iconName: String {
        switch entry.sourceType {
        case .systemHotkey: return "gearshape.fill"
        case .configFile:   return "doc.text.fill"
        case .menuBar:      return "app.fill"
        case .runtime:      return "dot.radiowaves.left.and.right"
        }
    }

    private var iconColor: Color {
        switch entry.sourceType {
        case .systemHotkey: return .secondary
        case .configFile:   return .orange
        case .menuBar:      return .accentColor
        case .runtime:      return .accentColor
        }
    }
}
