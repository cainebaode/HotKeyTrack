import Foundation
import CoreGraphics
import AppKit

/// 响应侧监听：轮询 CGWindowList，检测按键触发后新出现的窗口及其所属进程。
/// 完全自研，思路来自本项目已验证的 win_watch 原型。
///
/// v2 说明：现代 macOS 上，表情面板、系统覆盖层等响应由 **Window Server** 渲染，
/// 早期版本按进程名把 Window Server 整体过滤为噪音，导致真实响应被误杀。
/// 现改为按「图层 + 尺寸」精准滤噪：只丢弃极小的状态指示器 / 1×1 占位窗口，
/// 保留有实际尺寸的面板窗口。
final class WindowMonitor {

    /// 检测到新窗口时回调（在主线程）
    var onNewResponder: ((ResponderEntry) -> Void)?

    private var timer: Timer?
    private var knownWindowIDs = Set<Int>()
    private var activationObserver: NSObjectProtocol?
    private(set) var isRunning = false

    /// 轮询间隔（秒），需 ≤0.3s 以捕捉快速弹出的窗口
    private let interval: TimeInterval = 0.2

    /// 启动监听：先记录当前窗口快照作为基线，再周期性 diff 新增窗口
    func start() {
        guard !isRunning else { return }
        knownWindowIDs = Set(currentSnapshot().map { $0.windowID })
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // 加入 commonModes，避免主线程处于事件跟踪模式时定时器暂停
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        // 补充信号：前台应用切换（兜住 Jotty 这类会激活到前台的 App）
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.handleAppActivation(note)
        }
        isRunning = true
    }

    /// 停止监听
    func stop() {
        timer?.invalidate()
        timer = nil
        if let obs = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            activationObserver = nil
        }
        knownWindowIDs.removeAll()
        isRunning = false
    }

    /// 前台应用切换 → 作为一个响应源上报
    private func handleAppActivation(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = Int(app.processIdentifier)
        if pid == Int(ProcessInfo.processInfo.processIdentifier) { return }
        let name = app.localizedName ?? LT("未知应用", "Unknown app")
        let entry = ResponderEntry(
            processName: name,
            processPath: app.bundleURL?.path ?? "",
            pid: pid,
            windowName: LT("（切换到前台）", "(brought to front)"),
            timestamp: Date(),
            windowLayer: 0,
            windowSize: "",
            signalKind: .appActive
        )
        onNewResponder?(entry)
    }

    // MARK: - 噪音过滤

    /// 需要过滤的系统底层进程名（仅保留确定无意义的）
    private static let noiseProcesses: Set<String> = [
        "loginwindow"
    ]

    /// 需要过滤的系统窗口名（状态栏图标刷新等，不是真正的响应源）
    private static let noiseWindows: Set<String> = [
        "StatusIndicator", "MenuBarWindow", "Backstop Menubar", "Dock"
    ]

    private func tick() {
        let windows = currentSnapshot()
        for w in windows where !knownWindowIDs.contains(w.windowID) {
            knownWindowIDs.insert(w.windowID)
            guard shouldReport(w) else { continue }

            let entry = ResponderEntry(
                processName: w.ownerName,
                processPath: pathForPID(w.pid),
                pid: w.pid,
                windowName: w.windowName,
                timestamp: Date(),
                windowLayer: w.layer,
                windowSize: "\(Int(w.width))x\(Int(w.height))",
                signalKind: .window
            )
            onNewResponder?(entry)
        }
    }

    /// 判定一个新窗口是否值得作为响应源上报
    private func shouldReport(_ w: WindowInfo) -> Bool {
        // 过滤自身窗口
        if w.pid == Int(ProcessInfo.processInfo.processIdentifier) { return false }
        // 过滤系统底层噪音进程
        if Self.noiseProcesses.contains(w.ownerName) { return false }
        // 过滤已知系统噪音窗口名
        if Self.noiseWindows.contains(w.windowName) { return false }
        // 过滤 1×1 / 极小占位窗口
        if w.width <= 3 || w.height <= 3 { return false }
        // 过滤菜单栏图标残影等超小窗口（如控制中心图标 16×13、状态栏克隆 28×23）
        if w.width < 40 && w.height < 40 { return false }
        // 过滤极高图层的小型状态指示器（如录制/定位指示器，约 28×40，layer 约 21 亿）
        if w.layer > 1_000_000_000 && w.width <= 80 && w.height <= 80 { return false }
        return true
    }

    // MARK: - 窗口快照

    private struct WindowInfo {
        let windowID: Int
        let ownerName: String
        let pid: Int
        let windowName: String
        let layer: Int
        let width: Double
        let height: Double
    }

    private func currentSnapshot() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { dict in
            guard let windowID = dict[kCGWindowNumber as String] as? Int,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int else {
                return nil
            }
            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? LT("未知进程", "Unknown process")
            let windowName = dict[kCGWindowName as String] as? String ?? ""
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            var width = 0.0, height = 0.0
            if let b = dict[kCGWindowBounds as String] as? [String: Any] {
                width = b["Width"] as? Double ?? 0
                height = b["Height"] as? Double ?? 0
            }
            return WindowInfo(windowID: windowID, ownerName: ownerName, pid: pid,
                              windowName: windowName, layer: layer, width: width, height: height)
        }
    }

    private func pathForPID(_ pid: Int) -> String {
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            return app.bundleURL?.path ?? app.executableURL?.path ?? ""
        }
        return ""
    }

    deinit {
        stop()
    }
}
