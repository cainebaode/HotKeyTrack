import SwiftUI

/// 权限未授权时显示的引导横幅
struct PermissionBanner: View {
    @EnvironmentObject var permission: PermissionManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(LT("需要辅助功能权限", "Accessibility permission required"))
                    .font(.headline)
                Text(LT("HotKeyTrack 需要该权限才能扫描快捷键、监听按键事件。所有数据仅在本地处理。",
                        "HotKeyTrack needs this permission to scan shortcuts and monitor key events. All data is processed locally."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(LT("打开设置", "Open Settings")) {
                permission.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }
}
