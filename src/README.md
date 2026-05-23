# src/ — Tauri/Vue 老栈前端（**退役进行中**）

> 🪦 **退役进行中**（v0.69+ 启动）：此目录将按 [Tauri 退役计划 v0.70.0](../docs/iterations/v0.70.0-pc-tauri-retirement.md) 在 4 阶段 24 个月内（→ v0.80）物理删除。功能对齐已于 v0.68.0 完成（59+ 项 + i18n 结构），Flutter 栈（`packages/termex_shared/` + `app/`）为生产主推。
>
> ⚠️ **新功能开发请走 [../packages/termex_shared/](../packages/termex_shared/) + [../app/](../app/)（Flutter 栈）**；本目录仅接受 critical security PR。

## 现状

- 与 [../src-tauri/](../src-tauri/) 共同构成生产可用的 Tauri/Vue 应用
- 通过 Tauri v2 IPC 与 Rust 后端通信
- 计划状态见 [../docs/iterations/v0.51.0-remediation.md](../docs/iterations/v0.51.0-remediation.md)

## 目录速览

```
src/
├── components/   # Vue 组件
├── composables/  # Vue Composition API hooks
├── stores/       # Pinia 状态
├── types/        # TypeScript 类型定义
├── utils/        # 工具函数（含 Tauri IPC 封装 tauri.ts）
├── i18n/         # 国际化资源
└── main.ts       # 应用入口
```

## 何时清理

- **触发条件**：Flutter 栈在桌面端（macOS/Windows/Linux）发版稳定 ≥ 2 个版本
- **执行方式**：整目录删除 + 配套清理 [../src-tauri/](../src-tauri/) 中仅服务于此栈的 commands/IPC

## 协作约定

- 修改前务必同步评估对应功能在 [../app/](../app/) 中的覆盖情况
- 不要在此目录引入新依赖；如必须，请在 PR 描述中说明无法用 Flutter 实现的理由
