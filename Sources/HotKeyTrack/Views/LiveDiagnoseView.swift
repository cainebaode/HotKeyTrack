import SwiftUI

/// 页面二：实时诊断（M2 实现）
/// 时间线视图：每个按键事件与其触发的响应源绑定显示。
struct LiveDiagnoseView: View {
    // 会话由 AppDelegate 持有并注入，便于面板关闭时统一停止监听
    @EnvironmentObject var session: DiagnoseSession

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            timeline
        }
        .onDisappear { session.stop() }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            switch session.state {
            case .idle:
                Button { session.start() } label: {
                    Label(LT("开始排查", "Start"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

            case .recording:
                Button { session.stop() } label: {
                    Label(LT("暂停", "Pause"), systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

            case .paused:
                Button { session.start() } label: {
                    Label(LT("继续", "Resume"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                Button { session.reset() } label: {
                    Label(LT("清空", "Clear"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            HStack(spacing: 6) {
                StatusDot(state: session.state)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private var statusText: String {
        switch session.state {
        case .idle: return LT("点击开始排查，然后按下你要诊断的键", "Click Start, then press the key you want to diagnose")
        case .recording: return LT("正在监听…按任意键捕获", "Listening… press any key to capture")
        case .paused: return LT("已暂停（数据保留）", "Paused (data kept)")
        }
    }

    // MARK: - 时间线

    private var timeline: some View {
        Group {
            if session.events.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(session.events.reversed()) { event in
                            EventRow(event: event)
                            Divider().opacity(0.3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "keyboard")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text(LT("暂无按键", "No keys yet"))
                .font(.callout)
                .foregroundStyle(.tertiary)
            Text(LT("按下任意键，查看它触发了哪些响应", "Press any key to see what it triggers"))
                .font(.caption)
                .foregroundStyle(.quaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 状态指示小圆点

/// 监听中呈现呼吸动效的状态点
private struct StatusDot: View {
    let state: DiagnoseSession.State
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(state == .recording && pulsing ? 1.35 : 1.0)
            .opacity(state == .recording && pulsing ? 0.5 : 1.0)
            .animation(
                state == .recording
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { pulsing = true }
    }

    private var color: Color {
        switch state {
        case .idle: return .secondary
        case .recording: return .green
        case .paused: return .orange
        }
    }
}

// MARK: - 单条按键事件行

private struct EventRow: View {
    let event: DiagnoseSession.KeyEvent
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 按键头部
            HStack {
                Text(event.display)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)

                if !event.responders.isEmpty {
                    Text(LT("\(event.responders.count) 个响应", "\(event.responders.count) responses"))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event.responders.count >= 2 ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                        .foregroundStyle(event.responders.count >= 2 ? .red : .blue)
                        .clipShape(Capsule())
                } else {
                    Text(LT("无响应", "No response"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(event.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !event.responders.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, keyCodeDetail.isEmpty ? 8 : 2)

            // 底层键码信息（P1-3 高级排查）
            if !keyCodeDetail.isEmpty {
                Text(keyCodeDetail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // 响应源列表
            if expanded && !event.responders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(event.responders) { r in
                        ResponderRow(responder: r)
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
    }

    /// 拼接“键码 N · 修饰键”的高级信息
    private var keyCodeDetail: String {
        var parts = [LT("键码 \(event.keyCode)", "Key code \(event.keyCode)")]
        if !event.modifierDetail.isEmpty { parts.append(event.modifierDetail) }
        return parts.joined(separator: "  ·  ")
    }
}

// MARK: - 响应源行

private struct ResponderRow: View {
    let responder: ResponderEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: responder.signalKind == .appActive ? "arrow.up.forward.app.fill" : "macwindow")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(responder.displayName)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                if !responder.windowName.isEmpty {
                    Text(LT("窗口: \(responder.windowName)", "Window: \(responder.windowName)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 图层/尺寸（辅助判断，仅窗口信号有）
                if responder.signalKind == .window, !responder.windowSize.isEmpty {
                    Text(LT("尺寸 \(responder.windowSize) · 图层 \(responder.windowLayer)", "Size \(responder.windowSize) · Layer \(responder.windowLayer)"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !responder.processPath.isEmpty {
                    Text(responder.processPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(responder.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 3)
    }
}
