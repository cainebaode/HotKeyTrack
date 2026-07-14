import SwiftUI

/// 主界面：顶部权限状态横幅 + 双 Tab（总览扫描 / 实时诊断）
struct RootView: View {
    @EnvironmentObject var permission: PermissionManager
    @State private var selectedTab: Tab = .liveDiagnose

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "overview"
        case liveDiagnose = "liveDiagnose"
        var id: String { rawValue }

        /// 展示标题（随系统语言中/英切换）
        var title: String {
            switch self {
            case .overview: return LT("总览扫描", "Overview")
            case .liveDiagnose: return LT("实时诊断", "Live Diagnose")
            }
        }

        var icon: String {
            switch self {
            case .overview: return "list.bullet.rectangle"
            case .liveDiagnose: return "dot.radiowaves.left.and.right"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !permission.isTrusted {
                PermissionBanner()
                    .environmentObject(permission)
            }

            Divider()

            Group {
                switch selectedTab {
                case .overview:
                    OverviewView()
                case .liveDiagnose:
                    LiveDiagnoseView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { permission.refresh() }
    }

    private var header: some View {
        HStack {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 320)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help(LT("退出 HotKeyTrack", "Quit HotKeyTrack"))
        }
        .padding(10)
    }
}
