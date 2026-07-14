import Foundation
import Combine

/// 一次实时诊断会话：协调 EventTapMonitor + WindowMonitor，
/// 将按键事件与其触发的响应源绑定在一起。
final class DiagnoseSession: ObservableObject {

    enum State { case idle, recording, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var events: [KeyEvent] = []

    /// 一次按键事件及其关联的响应源
    struct KeyEvent: Identifiable, Hashable {
        let id = UUID()
        let display: String          // 如 "⌘C"、"fn (双击)"
        let keyCode: Int             // 底层虚拟键码（P1-3 高级排查）
        let modifierDetail: String   // 修饰键英文详情，如 "⌘Command ⇧Shift"
        let timestamp: Date
        var responders: [ResponderEntry] = []
        // 注意：不要自定义仅按 id 比较的 Equatable/Hashable。
        // 否则追加 responders 后 event 仍被判为“相等”，
        // 导致 SwiftUI 跳过该行重绘、始终显示“无响应”。
        // 这里使用编译器合成的按全字段比较，responders 变化即触发刷新。
    }

    private let eventTap = EventTapMonitor()
    private let windowMonitor = WindowMonitor()

    /// 归因窗口：按键前后 N 秒内出现的新窗口归因于该按键
    /// （允许负值因为 macOS 可能预加载窗口，比事件捕获更早出现）
    private let preWindow: TimeInterval = 0.5   // 按键前最多 0.5 秒
    private let postWindow: TimeInterval = 3.0  // 按键后最多 3 秒

    /// 开始诊断
    func start() {
        guard state == .idle || state == .paused else { return }
        events.removeAll()
        state = .recording

        eventTap.onKeyEvent = { [weak self] key in
            self?.handleKeyEvent(key)
        }
        windowMonitor.onNewResponder = { [weak self] entry in
            self?.handleNewResponder(entry)
        }

        eventTap.start()
        windowMonitor.start()
    }

    /// 停止诊断（保留数据）
    func stop() {
        eventTap.stop()
        windowMonitor.stop()
        state = .paused
    }

    /// 清空数据回到初始
    func reset() {
        stop()
        events.removeAll()
        state = .idle
    }

    // MARK: - 事件处理

    private func handleKeyEvent(_ key: EventTapMonitor.KeyEvent) {
        guard key.type == .keyDown else { return }
        let display = KeyCodeMap.describe(keyCode: key.keyCode, flags: key.flags, type: key.type)
        let event = KeyEvent(
            display: display,
            keyCode: key.keyCode,
            modifierDetail: KeyCodeMap.modifierDetail(key.flags),
            timestamp: key.timestamp
        )

        DispatchQueue.main.async {
            self.events.append(event)
        }
    }

    private func handleNewResponder(_ entry: ResponderEntry) {
        DispatchQueue.main.async {
            // 找最近的按键事件，窗口可能在按键前或后出现
            var bestIdx: Int?
            var bestDelta: TimeInterval = .infinity
            for (idx, event) in self.events.enumerated() {
                let delta = entry.timestamp.timeIntervalSince(event.timestamp)
                let absDelta = abs(delta)
                if absDelta <= self.postWindow && absDelta < bestDelta {
                    bestDelta = absDelta
                    bestIdx = idx
                }
            }
            if let idx = bestIdx {
                var updated = self.events[idx]
                // 同一 App(pid) 已记录则不重复添加（窗口+前台切换可能重复）
                if !updated.responders.contains(where: { $0.pid == entry.pid }) {
                    updated.responders.append(entry)
                    self.events[idx] = updated  // 替换整个元素以触发 @Published
                }
            }
        }
    }

    deinit {
        stop()
    }
}
