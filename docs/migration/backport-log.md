# Backport Log — main → feature (Flutter)

> 记录 v0.40–v0.49 期间，main 分支上所有带 `[backport-flutter]` 标签 commits 如何被应用到 feature 分支。

参照 v0.49.0 spec §8。在 feature 分支合并回 main 前，本文件需覆盖**所有** `git log main --grep="\[backport-flutter\]"` 的条目。

---

## 字段说明

| 字段 | 含义 |
|---|---|
| SHA | main 上的 commit SHA（前 8 位） |
| 类别 | `direct` / `remap` / `reimplement` |
| 状态 | `applied` / `skipped` / `blocked` |
| 目标路径 | feature 分支上对应的文件/目录 |
| 备注 | 冲突、重实现方式、skip 原因等 |

分类定义：
- **direct**: 文件路径未变，可直接 cherry-pick
- **remap**: 代码已搬到 `crates/termex-core/` 等新路径，需要手动映射
- **reimplement**: Vue 侧代码已在 Flutter 端完全重写，需要在新代码中修同一 bug

---

## 条目

| # | SHA | 类别 | 状态 | 目标路径 | 备注 |
|---|---|---|---|---|---|
| 1 | _待填_ | | | | |

---

## 验证

- [ ] `git log main --grep="\[backport-flutter\]" --format="%H" | wc -l` 与本文件 `applied` + `skipped` 合计相等
- [ ] 每一条 `reimplement` 都有对应的 Dart/Rust 测试覆盖同一场景
- [ ] 合并前 CI 全绿
