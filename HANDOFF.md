# HotKeyTrack 交接说明（AGENT HANDOFF）

> macOS 快捷键冲突诊断工具。菜单栏 App，Swift + SwiftUI，零第三方依赖。
> 本文件面向接手的 AI Agent / 开发者，帮助快速进入状态。

## 一、这是什么

一个**实时定位「某个按键触发了哪些响应源」**的 macOS 诊断工具，填补现有工具（只看输入侧 / 静态扫描 / 已停更）的空白。两个核心页面：

- **总览扫描（静态）**：扫描运行中应用菜单栏 + 系统快捷键 + 配置文件（skhd/Karabiner），同一键组合 ≥2 来源标记「可能冲突」。
- **实时诊断（动态）**：手动开始/停止，监听按键（含 Fn、系统级、第三方 App 盲区）并绑定其响应源。

## 二、当前状态

| 里程碑 | 状态 |
|--------|------|
| M1 工程骨架（菜单栏 App、双页面、权限） | ✅ 完成 |
| M2 实时诊断（按键监听 + 响应源捕获） | ✅ 真机验证通过 |
| M3 总览扫描（静态扫描 + 冲突标记） | ✅ 已实现 |
| M4 打磨（视觉、空状态、P1 增强、打包） | ✅ 已实现 |

已完成：核心响应源刷新 bug 修复、中英双语（系统中文→中文，其余→英文）、总览默认折叠 + 搜索、点击面板外收回并停止监听、稳定自签名证书签名。

**详细进度、已解决问题、根因分析见** `快捷键工具开发进度.md`。

## 三、构建与运行

前置：macOS + Xcode Command Line Tools（无需 Xcode.app）。

```bash
cd HotKeyTrack
swift build -c release      # 仅编译
bash build_app.sh           # 编译 + 组装 .app + 签名
open .build/HotKeyTrack.app # 运行（菜单栏出现 ⌨ 图标）
```

首次运行需在「系统设置 → 隐私与安全性 → 辅助功能」授权本 App（CGEventTap 与 AX 扫描都依赖此权限）。

### 关于签名（重要）

- `build_app.sh` 优先用本地代码签名证书「HotKeyTrack Self-Signed」签名；**该证书的私钥不在本包内**（已剔除）。
- 因此在新机器上首次会**回退到 ad-hoc 签名**（可正常运行，但每次重新打包后辅助功能授权会失效，需重新授权）。
- 若想在本机根治「重复授权」问题，运行一次：`bash HotKeyTrack/setup_signing.sh`，它会在本机创建自己的稳定签名证书。原理：TCC 授权绑定签名的指定要求（DR）= `identifier + 证书哈希`，同证书重签 DR 不变，授权不失效。

## 四、代码结构（HotKeyTrack/Sources/HotKeyTrack/）

```
main.swift / AppDelegate.swift   应用入口（NSStatusItem + NSPopover，LSUIElement）
Localization.swift               轻量国际化 LT("中","en")
Models/Models.swift              数据模型（ShortcutEntry / ResponderEntry / ConflictGroup）
Permission/PermissionManager.swift  辅助功能授权检测（含启动轮询自纠正）
Collectors/
  EventTapMonitor.swift          CGEventTap 全局按键监听
  KeyCodeMap.swift               键码→键名、修饰键符号
  WindowMonitor.swift            CGWindowList 轮询 diff 响应侧新窗口（按图层/尺寸滤噪）
  SystemHotkeyScanner.swift      解析 com.apple.symbolichotkeys
  MenuBarScanner.swift           AX 遍历各 App 菜单栏快捷键
  ConfigFileScanner.swift        解析 skhd / Karabiner 配置
Domain/
  DiagnoseSession.swift          实时诊断会话（按键↔响应源时间线归因）
  ConflictAnalyzer.swift         冲突判定引擎
  OverviewModel.swift            总览页视图模型
Views/                           RootView / OverviewView / LiveDiagnoseView / PermissionBanner
```

## 五、关键设计与坑（务必知悉）

1. **菜单栏图标**：SPM 手动打包下 `MenuBarExtra` 不显示，改用 `NSStatusItem`。
2. **响应源捕获**：表情面板等由 **Window Server** 渲染，不能按进程名把它当噪音过滤；现按「图层 + 尺寸」精准滤噪（丢弃 <40×40 状态图标残影、极高图层小型指示器）。
3. **SwiftUI 刷新坑**：`KeyEvent` 曾自定义「仅按 id 比较」的 Equatable，导致追加响应源后视图不刷新（显示「无响应」）。**不要再给它加仅按 id 的 == / hash**，需按全字段比较。
4. **归因窗口**：按键前 0.5s ~ 后 3s 内新出现的窗口/前台切换归因到该按键；同 pid 去重。
5. **国际化**：菜单项标题（如「左侧/顶部」）来自各 App 自身本地化，不归我们翻译；只翻译我们自己的文案。

## 六、后续可选方向（M4+）

- 应用图标；glyph 键（无 cmdChar/cmdVirtualKey）映射补全；系统功能名 ID 覆盖更全。
- 更多配置源：Hammerspoon / BetterTouchTool 等。
- 分发签名：如需给他人使用，考虑 Developer ID 签名 + 公证。

## 七、需求与规划文档

- `PRD-快捷键诊断工具.md`：产品需求
- `架构与开发规划-快捷键诊断工具.md`：架构与里程碑规划
- `快捷键工具开发进度.md`：开发进度 + 已解决问题 + 根因（**最实时**）
