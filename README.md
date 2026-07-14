# HotKeyTrack

<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="HotKeyTrack app icon">
</p>

一款原生 macOS 快捷键冲突诊断工具。它不仅能扫描已占用的快捷键，还能帮助你判断：**按下一个键后，究竟有哪些应用或系统界面作出了响应。**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://github.com/cainebaode/HotKeyTrack/releases/latest)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 下载

**[下载最新版 HotKeyTrack for macOS（Apple Silicon）](https://github.com/cainebaode/HotKeyTrack/releases/latest/download/HotKeyTrack-macOS-Apple-Silicon.zip)**

系统要求：macOS 14 或更高版本。当前预编译包支持 Apple Silicon；Intel Mac 可从源码构建。

> 当前版本尚未使用 Apple Developer ID 签名和公证。首次打开时，macOS 可能显示安全提示；请右键点击 App 并选择“打开”。只从本仓库的 Releases 页面下载安装包。

## 它能做什么

### 总览扫描

- 扫描运行中应用的菜单栏快捷键
- 读取 macOS 系统快捷键
- 读取 skhd 和 Karabiner-Elements 配置
- 将相同键组合的多个来源标记为“可能冲突”
- 支持按快捷键、应用或动作搜索

### 实时诊断

- 监听全局按键事件，包括 Fn 和系统级按键
- 检测按键后出现的新窗口与前台应用切换
- 将按键与可能的响应程序关联展示
- 一个按键出现多个响应源时提示“可能冲突”

例如：双击 Fn 同时弹出语音输入和“表情与符号”面板时，HotKeyTrack 可以帮助确认两个响应来源。

## 使用方法

1. 下载并解压 `HotKeyTrack-macOS-Apple-Silicon.zip`。
2. 将 `HotKeyTrack.app` 移入“应用程序”文件夹。
3. 右键点击 App，选择“打开”。
4. 按提示前往“系统设置 → 隐私与安全性 → 辅助功能”授权。
5. 点击菜单栏中的键盘图标开始使用。

辅助功能权限用于读取应用菜单和监听键盘事件。HotKeyTrack 不会修改快捷键或系统设置。

## 隐私

- 所有数据仅在本机处理
- 不连接服务器
- 不上传按键或应用信息
- 不包含遥测与用户追踪

## 工作原理

HotKeyTrack 使用纯 Apple 原生框架实现：

- Accessibility API：读取运行中应用的菜单栏快捷键
- `com.apple.symbolichotkeys`：读取 macOS 系统快捷键
- CGEventTap：捕获全局按键事件
- CGWindowList：检测新增窗口及其所属进程
- SwiftUI + AppKit：构建菜单栏界面

实时诊断是一种基于时间窗口和系统信号的推断，因此结果代表“可能的响应来源”，并非系统提供的绝对因果关系。

## 从源码构建

需要 macOS 14+ 和 Xcode Command Line Tools：

```bash
git clone git@github.com:cainebaode/HotKeyTrack.git
cd HotKeyTrack
swift build -c release
bash build_app.sh
open .build/HotKeyTrack.app
```

如果需要在本机反复构建并保留辅助功能授权，可运行一次：

```bash
bash setup_signing.sh
```

该脚本只在本机钥匙串中创建 HotKeyTrack 自用的稳定签名证书，不会上传私钥。

## 当前限制

- 部分只有 glyph、没有字符或虚拟键码的菜单快捷键可能无法识别
- 运行时响应通过窗口变化和应用激活信号推断，可能存在漏报或误报
- 当前仅解析 skhd 和 Karabiner-Elements 配置
- 发布包尚未经过 Apple 公证

## 参与贡献

欢迎提交 Issue 和 Pull Request。报告识别问题时，请附上 macOS 版本、触发快捷键、相关应用和实际观察到的现象，但不要上传包含隐私信息的配置文件。

## License

本项目采用 [MIT License](LICENSE)。
