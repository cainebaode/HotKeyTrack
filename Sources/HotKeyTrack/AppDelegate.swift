import AppKit
import SwiftUI
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let permission = PermissionManager()
    // 实时诊断会话在此持有，面板关闭时统一停止监听
    private let session = DiagnoseSession()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⌨"
            button.toolTip = "HotKeyTrack"
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 520)
        popover.behavior = .transient          // 点击面板之外自动收回
        popover.animates = true
        popover.delegate = self

        let rootView = RootView()
            .environmentObject(permission)
            .environmentObject(session)

        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // 每次打开面板主动刷新授权状态，避免启动时误判残留
            permission.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

// MARK: - 面板关闭时停止正在监听的任务

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        // 点击面板之外收回时，一并停止实时诊断的按键/窗口监听，避免后台空耗
        session.stop()
    }
}
