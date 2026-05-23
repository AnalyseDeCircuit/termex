# Termex 架构总览

> 本文档解释 Termex monorepo 的目录结构与双栈共存现状，作为新成员/AI 助手的快速入门参考。
>
> ⚠️ **退役进行中**（v0.69+ 启动）：Tauri/Vue 桌面老栈进入退役计划，4 阶段 24 个月内（→ v0.80）物理删除。新功能开发**仅在 Flutter 栈**进行；老栈仅接 critical security PR。详见 [Tauri 退役计划 v0.70.0](iterations/v0.70.0-pc-tauri-retirement.md)。

## 一句话定位

**Termex 是 Tauri/Vue（老栈，退役中）与 Flutter（新栈，生产主推）双栈并存的桌面 + 移动 SSH 客户端**，业务逻辑统一沉淀到 Rust workspace，通过 Tauri IPC 与 flutter_rust_bridge 双通道分发。功能对齐已于 v0.68.0 完成（59+ parity 项 + i18n 结构补齐）；v0.69+ 进入老栈退役 4 阶段。

## 顶层目录映射

```
termex/
│
├── ─── 业务核心层（双栈共享，唯一权威）─────────────────────────
├── crates/
│   ├── termex-core/             # 全部业务逻辑：ssh/sftp/crypto/storage/ai/team/monitor/recording
│   └── termex-flutter-bridge/   # flutter_rust_bridge v2 绑定层（不写业务，只暴露 API）
│
├── ─── 平台壳：Tauri 老栈（生产，将逐步淘汰）──────────────────
├── src-tauri/                   # Rust：Tauri v2 后端 + IPC commands
│   └── src/commands/            # 薄适配层：参数校验 → termex-core → 返回
├── src/                         # TypeScript：Vue 3 + Vite + Pinia 前端
│
├── ─── 平台壳：Flutter 新栈（迁移目标）────────────────────────
├── app/                         # Dart：Flutter 3.24+ 应用
│   ├── lib/
│   │   ├── features/            # 业务模块（server_list/ai/sftp/team/cloud/recording...）
│   │   ├── mobile/              # 移动端独有（push/wakelock/keychain bridge...）
│   │   ├── terminal/            # 自绘 VT100/xterm 终端
│   │   ├── widgets/             # Termex 设计系统组件（self-drawn）
│   │   ├── design/              # Token / Theme
│   │   ├── layout/              # AdaptiveLayout（iPad sidebar / iPhone bottombar）
│   │   ├── platform/            # Haptics / Permissions
│   │   └── system/              # 启动 / 引导 / sentinel_flag
│   ├── ios/    android/         # 平台原生壳（Xcode 工程 / Gradle 工程）
│   ├── test/   integration_test/
│   └── fastlane/                # iOS + Android 上架自动化（v0.61.0）
│
├── ─── 工程辅助 ───────────────────────────────────────────────
├── docs/                        # 设计文档 + 迭代记录（docs/iterations/* 在 .gitignore）
├── scripts/                     # frb-codegen.sh / bump-version.mjs
├── images/  CHANGELOG.md  LICENSE  README.md
├── Cargo.toml                   # Rust workspace 根：[src-tauri, crates/*]
├── package.json                 # pnpm 根（仅服务 src/ 老栈前端）
├── flutter_rust_bridge.yaml     # FRB codegen 配置
└── CLAUDE.md  CLAUDE.local.md   # AI 助手指令
```

## 两条数据通路

```
                    ┌──────────────────────────────┐
                    │  crates/termex-core (Rust)   │
                    │  业务逻辑 / 加密 / 存储 / SSH  │
                    └─────────────┬────────────────┘
                                  │
              ┌───────────────────┴──────────────────┐
              │                                      │
              ▼                                      ▼
   ┌─────────────────────┐            ┌──────────────────────────────┐
   │   src-tauri/        │            │  crates/termex-flutter-bridge │
   │   Tauri v2 IPC      │            │  flutter_rust_bridge v2 FFI   │
   └──────────┬──────────┘            └──────────────┬────────────────┘
              │                                       │
              ▼                                       ▼
   ┌─────────────────────┐            ┌──────────────────────────────┐
   │   src/ (Vue 3)      │            │       app/lib/ (Dart)        │
   │   桌面端老栈         │            │   桌面 + iOS + Android 新栈   │
   └─────────────────────┘            └──────────────────────────────┘
```

## 为什么是这样

| 问题 | 当前方案 | 为什么不重排 |
|---|---|---|
| `src/` `src-tauri/` 占位根目录最优位置但属于将淘汰栈 | 加 README 标注 deprecated | Migration 长跑期，重排会让所有 PR / 文档相对路径失效 |
| `crates/` 与 `app/` 命名风格不一致 | 不动 | Rust workspace 约定 + Flutter 约定差异，跨语言无完美解 |
| `fastlane/` 原本在根 | 已挪到 `app/fastlane/` | 它只服务 Flutter，归位后职责清晰 |

完整重排计划留到老栈废弃后（参考 [migration/flutter-migration-roadmap.md](migration/flutter-migration-roadmap.md)）。

## 核心约定（CLAUDE.md 摘要）

- **任何 `crates/termex-core/src/api/*.rs` 改动**必须运行 `./scripts/frb-codegen.sh` 同步 Dart 绑定
- **业务逻辑只能写在 [../crates/termex-core/](../crates/termex-core/)**，src-tauri/commands/* 与 app/lib/* 都是适配层
- **单文件 ≤ 800 行**，超过必须拆分
- **测试与实现同步提交**，禁止后补
- **Rust 测试放 `src-tauri/tests/` / `crates/*/tests/`**，禁止内嵌 `#[cfg(test)] mod tests`
- **Keychain 启动最多弹 1 次**（详见 CLAUDE.md "Keychain Single-Prompt Rule"）

## 何时该读哪个文档

| 想了解 | 读 |
|---|---|
| 项目愿景 / 商业定位 | [../README.md](../README.md) |
| 双栈现状 / 命令惯例 / 安全规则 | [../CLAUDE.md](../CLAUDE.md) |
| 迁移路线 | [migration/flutter-migration-roadmap.md](migration/flutter-migration-roadmap.md) |
| 当前迭代 | [iterations/](iterations/)（在 `.gitignore` 中，仅本地） |
| 历史决策与债务 | [tech-debt.md](tech-debt.md) / [MIGRATION.md](MIGRATION.md) |
| Sentinel/反 AI | [../CLAUDE.local.md](../CLAUDE.local.md) |
