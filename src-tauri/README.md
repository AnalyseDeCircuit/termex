# src-tauri/ — Tauri v2 后端（**退役进行中**）

> 🪦 **退役进行中**（v0.69+ 启动）：此目录将按 [Tauri 退役计划 v0.70.0](../docs/iterations/v0.70.0-pc-tauri-retirement.md) 在 4 阶段 24 个月内（→ v0.80）物理删除：
> - **Phase 1**（v0.69）：Deprecation 通知 + in-app banner
> - **Phase 2**（v0.70）：默认安装切换到 Flutter；本目录不再随 release 推送
> - **Phase 3**（v0.75）：CI 工作流删除；`bump-version.mjs` 移除此目录
> - **Phase 4**（v0.80）：物理删除本目录
>
> ⚠️ **新业务逻辑必须写到 [../packages/termex_shared/](../packages/termex_shared/) 或 [../crates/termex-core/](../crates/termex-core/)**；本目录仅接受 critical security PR。

## 双栈职责划分

| 模块类型 | 位置 | 备注 |
|---|---|---|
| **业务核心**（SSH/SFTP/Crypto/Storage/AI/Team/Monitor/Recording） | [../crates/termex-core/](../crates/termex-core/) | 双栈共享，权威来源 |
| **Tauri IPC commands** | [src/commands/](src/commands/) | 薄适配层：参数校验 → 调 termex-core → 返回 |
| **Tauri shell**（生命周期、托盘、菜单） | [src/lib.rs](src/lib.rs) [src/main.rs](src/main.rs) | Tauri 独有，无需迁移 |
| **未迁出的旧实现** | `src/ssh/` `src/sftp/` `src/monitor/` `src/local_ai/` | 应逐步迁到 termex-core |

## 命令惯例

- 命名：`module_action`（如 `ssh_connect` / `sftp_list`）
- 入参：JSON object，使用 `#[tauri::command]` 自动反序列化
- 返回：`Result<T, String>`（错误转字符串避免序列化问题）
- 事件：`module://event/{id}` 模式，详见 [../CLAUDE.md](../CLAUDE.md)

## 何时整目录清理

- **触发条件**：Flutter 栈完成桌面端覆盖 + 老栈淘汰窗口期结束
- **保留方式**：可能将 Tauri shell 拆为独立 crate `crates/termex-tauri/`，commands 全部薄化为 termex-core 调用

## 当前迁移状态

见 [../docs/iterations/v0.51.0-remediation.md](../docs/iterations/v0.51.0-remediation.md) 与 [../docs/migration/flutter-migration-roadmap.md](../docs/migration/flutter-migration-roadmap.md)。

## 协作约定

- 修改 commands 前先确认 [../crates/termex-flutter-bridge/src/api/](../crates/termex-flutter-bridge/src/api/) 中是否有对应能力，避免双实现漂移
- 任何 `crates/termex-core/src/api/*.rs` 改动后必须运行 `./scripts/frb-codegen.sh`
