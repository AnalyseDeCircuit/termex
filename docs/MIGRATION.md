# Termex v0.39 → v0.49 Migration Guide

> 本指南面向 **Vue+Tauri 版 Termex 用户**。如果你是全新用户，直接下载 v0.49.0 即可。

---

## 重大变化

Termex 在 v0.49.0 完成了 UI 技术栈的整体切换：

| 层 | v0.39.x | v0.49.0 |
|---|---|---|
| UI 框架 | Vue 3 + Element Plus | Flutter 3.24 (自绘 widgets) |
| 运行时 | Tauri 2 WebView | Flutter native |
| 终端渲染 | xterm.js (WebGL) | 自写 VT100 / CustomPainter |
| IPC | Tauri `invoke` | flutter_rust_bridge v2 |
| Rust backend | unchanged | unchanged |
| SQLCipher 数据库 | unchanged | unchanged |

核心业务逻辑（SSH、SFTP、加密、AI、同步）完全没变——只换了 UI 外壳。

---

## 你的数据

**完全保留，无需迁移**：

- SSH 服务器配置
- 密码、密钥、passphrase（OS Keychain）
- 主密码（若启用）
- 团队同步数据（含 Git 远端）
- AI 对话历史
- Snippet 库
- 端口转发规则
- 审计日志
- 录制文件（`.cast`）
- 监控设置

v0.49.0 第一次启动时会检测到现有 `termex.db`，直接读取。**没有迁移步骤。**

---

## 如何升级

### macOS

1. 打开当前 v0.39.x「设置 → 关于」，点击「检查更新」
2. 应用会提示「v0.49.0 有重大架构更新可用」，点击「下载」
3. 或直接从 https://termex.app 下载 `termex-0.49.0-macos-arm64.dmg`（Apple Silicon）或 `-x64.dmg`（Intel）
4. 双击 DMG → 拖入 Applications → 替换旧版

### Windows

1. 从 https://termex.app 下载 `termex-0.49.0-windows-x64.msix`
2. 双击安装；系统会自动替换旧版本
3. 或使用「设置 → 关于 → 检查更新」

### Linux

- AppImage：下载 `termex-0.49.0-linux-x64.AppImage`，`chmod +x`，运行
- Debian/Ubuntu：`sudo apt install ./termex-0.49.0-linux-x64.deb`
- RHEL/Fedora：`sudo rpm -i termex-0.49.0-linux-x64.rpm`

---

## 新特性（Flutter 版独有）

- 60 fps 原生终端渲染（v0.39 受 xterm.js+WebView 限制）
- GPU 加速的监控图表
- 跨 tab 搜索 scrollback（一次性搜所有终端）
- 插件权限 UI + 开发者模式
- 窗口状态持久化（重新打开恢复上次 tab 布局）
- 可自定义快捷键（GUI 编辑 + 冲突检测）
- 全面 a11y：VoiceOver / NVDA / Orca 兼容

---

## 已知差异

| 行为 | v0.39.x | v0.49.0 | 说明 |
|---|---|---|---|
| 字体平滑 | 系统 | 自绘 | 视觉略有不同，可在设置调整 |
| 右键菜单动画 | 200 ms fade | 160 ms easeIn | 自绘后统一 |
| Cmd+W 关闭 tab | 弹确认 | 弹确认 | 行为一致 |
| 多窗口 (Cmd+N) | 支持 | **暂未实现** | 计划在 v0.50+ 恢复 |
| 打印视图 | 支持 | **暂未实现** | 很少使用，下沉到 v0.51 |

---

## 回滚指南

若 v0.49.0 在你的环境下出现严重问题（崩溃、数据损坏、关键功能缺失）：

1. 访问 https://termex.app/legacy 下载 **stable-legacy** 通道的 v0.39.x
2. 卸载 v0.49.0，安装 v0.39.x
3. 数据库完全兼容 —— 你的服务器、密码、设置、AI 历史完整保留
4. 在 GitHub issue 报告问题，附带：
   - 操作系统版本
   - 重现步骤
   - v0.49.0 日志（「设置 → 关于 → 导出诊断日志」）

**stable-legacy 通道保留至 2027-04**（v0.49 GA 后 6 个月）。之后 v0.39.x 不再维护。

---

## 反馈

- GitHub: https://github.com/termex/termex/issues
- Discord: https://discord.gg/termex
- Email: feedback@termex.app

**关键信号请在 v0.49 beta 阶段报告**（预计 2026-09 开放 beta），这样 GA 前还来得及修。
