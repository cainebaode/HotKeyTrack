import Foundation
import ApplicationServices
import AppKit
import Combine

/// 辅助功能权限管理：检测授权状态、引导用户授权。
/// 实时诊断（CGEventTap）与总览扫描（AX 遍历运行中应用）都依赖此权限。
final class PermissionManager: ObservableObject {

    /// 当前是否已获得辅助功能权限
    @Published private(set) var isTrusted: Bool = false

    private var timer: Timer?

    init() {
        refresh()
        // 冷启动瞬间 AXIsProcessTrusted() 可能尚未被 TCC 确认而误返回 false，
        // 这里立即启动轮询自我纠正；已授权则会在下一次轮询后自动停止，
        // 未授权则持续等待，用户在系统设置里授权后横幅自动消失（无需点击本 App 按钮）。
        startPollingUntilTrusted()
    }

    /// 刷新一次授权状态（不弹系统对话框）
    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    /// 请求授权：弹出系统对话框引导用户前往"系统设置 > 隐私与安全性 > 辅助功能"
    func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        startPollingUntilTrusted()
    }

    /// 直接打开"辅助功能"设置面板
    func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        startPollingUntilTrusted()
    }

    /// 授权通常在应用外完成，轮询直到检测到已授权后停止
    private func startPollingUntilTrusted() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                self.isTrusted = trusted
                if trusted {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
