import Foundation
import CoreGraphics

/// 全局按键监听：通过 CGEventTap 捕获所有键盘事件。
/// 需要辅助功能权限才能工作。
final class EventTapMonitor {

    /// 捕获到按键事件时回调（在主线程）
    var onKeyEvent: ((KeyEvent) -> Void)?

    /// 按键事件数据
    struct KeyEvent {
        let keyCode: Int
        let flags: CGEventFlags
        let type: CGEventType
        let timestamp: Date
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    /// 启动全局按键监听
    func start() {
        guard !isRunning else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
                      | (1 << CGEventType.flagsChanged.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            print("[EventTapMonitor] 创建 event tap 失败，可能需要辅助功能权限")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    /// 停止监听
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }

    /// C 回调：转发到 Swift 实例方法
    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
        let monitor = Unmanaged<EventTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let keyEvent = KeyEvent(
            keyCode: keyCode,
            flags: flags,
            type: type,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            monitor.onKeyEvent?(keyEvent)
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        stop()
    }
}
