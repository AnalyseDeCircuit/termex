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

---

## v0.69 起：从 Tauri 桌面切换到 Flutter 桌面

> 适用于：仍在使用 **Vue+Tauri** 版本（v0.34.x 及更早，包括从 v0.39 升到 v0.49+ 但仍走老栈的混合包）的用户。
>
> 完整退役计划见 [Tauri 退役计划 v0.70.0](iterations/v0.70.0-pc-tauri-retirement.md)。

### 退役时间表（4 阶段，24 个月）

| 版本 | 阶段 | 对你意味着 |
|---|---|---|
| v0.69 | **Deprecation 通知** | 老 Tauri 包仍可用；启动时弹一次 banner 建议切换 |
| v0.70 | **Default switch** | 新安装默认 Flutter；AppCast 触发一次 critical update 让老用户切换 |
| v0.75 | **CI 移除** | Tauri 不再随官方 release 发布；老栈源码仍在仓库 |
| v0.80 | **源码删除** | `src-tauri/` + `src/` (Vue) 物理删除；老栈成 git 历史 |

### 切换步骤（极简）

**好消息**：数据库与凭据完全共享，**无需 export/import**：

1. 下载 v0.69+ 的 Flutter 桌面包（DMG / MSIX / AppImage）
2. 退出现有 Tauri 版 Termex（确保完整关闭，不只是窗口最小化）
3. 替换 `.app` / `.exe` / AppImage 文件 — 与升级旧版同流程
4. 启动 Flutter 版，主密码与首次启动一致

完成后你的全部服务器、SSH 密钥、AI 配置、团队设置自动可见。

### 数据兼容性详情

| 数据类型 | 位置 | 是否需要迁移 |
|---|---|---|
| 服务器列表 + 设置 | SQLCipher `~/Library/Application Support/termex/termex.db`（同 Tauri） | ❌ 不需要 |
| SSH 密码 / 密钥口令 | OS Keychain（同前缀 `termex:ssh:...`） | ❌ 不需要 |
| AI API 密钥 | OS Keychain（同前缀 `termex:ai:apikey:...`） | ❌ 不需要 |
| 会话录制 | `~/Library/Application Support/termex/recordings/`（同 Tauri） | ❌ 不需要 |
| 配置文件 / Tab 状态 | `~/.config/termex/`（同 Tauri） | ❌ 不需要 |
| 主密码 | 仅内存，每次启动输入 | — |

**两栈可同时存在**：v0.69 期间可以并行装 Tauri + Flutter 两个版本，互相切换无副作用（但不要同时开两个实例 — SQLCipher 单文件锁会阻止）。

### 已知行为差异

由于 Flutter 自绘 widget 而非 Element Plus：
- **视觉略异**：按钮圆角、阴影、动画曲线与 Tauri 版有细微差异；功能等价
- **字体度量**：终端等宽字体在 Flutter Skia 渲染下 baseline 略有差异，行高可在「设置 → 终端」微调
- **快捷键**：Cmd+N（新窗口）暂未实现 — Tauri 版有；计划 v0.71+ 恢复
- **打印视图**：Tauri 版有；Flutter 版暂无（很少使用）

### 回滚

老栈在 v0.75 前都可下载：访问 https://termex.app/legacy 选择 v0.34.x 系列。**stable-legacy 通道保留至 2027-04**（与 v0.39→v0.49 同节奏）。

### 反馈

任何 Tauri → Flutter 切换问题：
- GitHub: 打 issue 加 `tauri-retirement` 标签
- 紧急 regression：邮件 feedback@termex.app 主题 `[v0.69]`

我们承诺每 minor 版本发版前列入「Flutter 与 Tauri 行为差异清单」，让你判断切换时机。
