# Termex Mobile — 战略定位（Strategic Positioning）

> 状态：现行（v0.71.0 起；v2 修订 2026-05-23）
> 适用范围：`termex-mobile/` 仓库 + 与之相关的 `termex_shared` / `termex_shared_pro` / `termex-core` / `termex-core-private` 子模块
> 上位文档：[`docs/requirements.md`](requirements.md) §1.2 核心价值（桌面 + 移动通用部分）
> 下位执行：`docs/iterations/v0.70.5-core-*.md` 起的所有迭代

---

## 1. 核心定位

> **Termex 移动端是 "AI 长跑任务的移动监控 + 反馈"控制台** — 让远程 AI CLI 的长跑任务可以从办公桌解耦，**在任何场景下被监控、被反馈、被快速决策**。

这一定位有意**收窄**于原版"任意时间任意地点完成交付"的宽泛叙事。真实成立的市场需求是：

- 跑测试套件 / 编译大型项目 / 模型训练 / 长批数据处理 / AI 自动重构 / 自动 PR 评审 —— **任务本身耗时 5 分钟到数小时**
- 用户在办公桌起的任务，不希望被绑在桌前
- 任务结束时**通知到位 + 摘要清晰 + 关键决策（重试 / 否决 / 接受 / 接手深度操作）能立刻完成**
- 任务过程中**关键节点（错误 / 等待输入 / 高风险动作）能介入**

**重新表达的核心价值**：

| 维度 | 价值主张 |
|---|---|
| **不在桌前也不漏** | 长跑任务结束、出错、卡住的瞬间都能立刻知道 |
| **摘要先于原文** | 手机上看 AI 工作结果，看结构化产出（"改了 4 个文件 / 测试 2 失败"）而不是 raw stdout |
| **敢于派完就走** | 高风险操作有护栏，AI 不会在用户不知情时干危险事 |
| **网络身份连贯** | 同一台 bastion 出口，PC 与手机在公司审计里是同一个会话来源 |
| **多端无缝** | PC 起任务，手机接进度；手机里批准/否决，PC 接手深度操作 |

### 关键叙事调整（vs v1）

| v1 表述 | v2 调整 | 理由 |
|---|---|---|
| "任意时间任意地点完成交付" | "AI 长跑任务的移动监控 + 反馈" | 真实场景是监控+决策，不是高频派遣 |
| "通勤路上发起重构" | 删除 | 手机敲长 prompt + 读长输出物理上劝退；GitHub mobile + Cursor mobile 已在做的事 Termex 没差异化 |
| "餐厅等位审 PR" | 删除 | GitHub mobile app 已覆盖 |
| "夜间床头跟踪长跑任务" | **强化为核心** | 真实存在、痛点真实、目前无好解 |
| "出差现场快响应" | **强化为核心** | DevOps/SRE 真实工作流 |
| "派完 → 收 → 再派" 高频循环 | "派 → 长跑 → 通知 → 决策" 低频高价值 | 单 DAU 1–3 次循环更现实，单次价值更高 |

---

## 2. 三大支柱

### 支柱 A · 持久通讯链路（Persistent Channel）— **优先级最高**

**核心约束：通讯链路本身是产品的命脉。任务还没结束、用户还在关注，连接绝不能断。**

实现层次（按优先级）：

| 层 | 用途 | 状态 |
|---|---|---|
| **WebSocket 长连接** | app 在前台时主力，到 termexd 的全双工流 | 主力 |
| **反向 SSH 隧道** | 跨 NAT / 防火墙时，远端 termexd 拉一条隧道回手机方向接入点 | 主力（备用） |
| **本地通知 + 屏幕常亮** | app 前台时屏幕保持常亮（用户可关），保证连接活跃 | OSS 基础 |
| **FCM / APNs** | app 后台 / 锁屏时唤起接收完成 / 关键事件 | Pro |
| **国内厂商推送**（极光 / 小米 / 华为 / OPPO / vivo） | 国内 Android 国行环境 FCM 不可用 | Pro，分批接入（推迟到 v0.75+） |

**重要**：WS / 反向 SSH 是**主力链路**，FCM/APNs **只是后台兜底**。这与 v1 把 FCM 视为主推送的设计完全不同 —— 它让产品**不依赖 Google 服务也能完整可用**（OSS 用户、国内用户、自托管用户）。

### 支柱 B · 结构化任务反馈（Structured Outcome）

**核心约束：手机屏小，stdout 不是给人看的格式，AI 的工作产出必须先被产品化。**

- 任务**默认视图 = 结构化摘要卡片**（修改文件 / 测试结果 / 错误 / token 消耗）
- 原始 terminal 输出降为"高级展开"次级入口
- AI 边跑边生成结构化产出（diff / 文件树变更 / 测试报告 / 摘要要点）
- 错误 / 等待输入 / 高风险动作触发**结构化 prompt**，要求用户在 mobile 上一键决策

### 支柱 C · 任务可信运行（Trustworthy Execution）

**核心约束：用户敢"派完就走"的前提是相信 AI 不会瞎搞。**

- **PendingConfirmation 状态**：派遣后、执行前，AI 给出"将做什么"摘要 + risk score
- 高风险（`rm -rf` / `DROP TABLE` / `kill -9` / sudo / 跨集群操作）必须二次确认（生物识别 / PIN）
- 可配置策略：「生产环境必审批」「DEV 自动通过」「单任务 cost cap」
- 任务运行中**关键决策点**（如 AI 想执行高风险命令）暂停 + 推送给用户

### 支柱 D · 网络路径一致性（Network Path Parity）

**核心约束：手机与 PC 通过同一条 bastion 链访问同一台远端机器，让公司审计 / Bastion ACL 看到一致的客户端来源 IP。**

⚠ **重要边界澄清**（v1 设计混淆，v2 修正）：

| 概念 | 控制范围 | EgressProfile 是否影响 |
|---|---|---|
| **客户端来源 IP**（手机 / PC 进 bastion 时被记录的 IP） | 走的 chain hop 序列 + proxy | ✅ 是 |
| **AI 出公网 IP**（AI CLI 调 GitHub / API 时对端看到的 IP） | AI 主机自身的网络环境 | ❌ 否 |

EgressProfile 只解决 (1)，不解决 (2)。如果用户真要 (2)，需要把 AI worker **跑在桌面端**（桌面端跑 worker，手机派任务给桌面端），那是另一种产品架构。本路线不做。

---

## 3. AI CLI 适配矩阵

| CLI | 优先适配方式 | Fallback | 优先级 |
|---|---|---|---|
| **Claude Code** | MCP (Model Context Protocol) 协议 | stdout heuristic（`Done` 标记 + tool-result 收束） | P0 |
| **Codex / OpenAI Codex CLI** | MCP（若开启） | stdout heuristic（JSON 完成事件 + exit） | P0 |
| **Aider** | stdout heuristic（`> ` prompt 重现 + exit） | — | P1 |
| **通用 PTY** | `IdleAndExitDetector`（idle + exit 双信号） | — | P0（兜底） |

**关键决策**：能用 MCP 就走 MCP — MCP 给出结构化的 tool call / progress / completion / 等待输入事件，比 stdout 启发式可靠十倍。stdout adapter 退为兜底。

适配器位于 `crates/termex-core/src/task/adapter/`，trait 抽象，可插拔。

---

## 4. 桌面端（路线 A）与移动端（路线 B）的明确分工

> **重要**：v1 设计把桌面 + 移动当作同一产品形态，错。本节明确 **PC 主走路线 A，移动主走路线 B；移动保留路线 A 的底座作为"高级展开"**。

| 维度 | PC 桌面端（路线 A · Terminal-first） | 移动端（路线 B · Operator Console） |
|---|---|---|
| **主战场** | 深度操作 — 写代码、长会话、调试、SSH 多 tab | 监控 + 反馈 — 看任务进度、收通知、做决策、必要时接手 |
| **主要 UI** | 多 tab xterm + AI 侧栏 + 服务器树 | 任务 dashboard + 结构化摘要卡片 + 推送通知 |
| **Terminal 视图** | 一等公民，主屏幕 | 二等公民，"高级展开"入口，用于排障 |
| **会话时长** | 数小时连续操作 | 数秒到数分钟交互 + 长时间后台保活 |
| **输入方式** | 物理键盘为主 | **语音为主** + 触屏 + 软键盘上方功能条 |
| **底座能力** | terminal + chain + proxy + forward 全套编辑 | terminal 仅 view，chain/proxy/forward **不编辑** 仅 sync consume |
| **典型动作** | "打开 terminal 干活" | "看一眼任务，三秒做决策" |

**底座保留原则**：移动端保留路线 A 的 terminal view 能力 — 用户在排查问题时可以下钻到完整 xterm —— 但它不是主屏，主屏是结构化的任务监控。

---

## 5. OSS / Pro 边界（修订）

| 模块 | 归属 | 修订说明 |
|---|---|---|
| `termexd` 远端守护进程 | **OSS** (`crates/termex-core/src/daemon/` + 独立 `termexd` binary) | 整个架构的底座，必须开源 |
| Task 模型 / Detector / Adapter | **OSS** (`termex-core/src/task/`) | 通用，开源价值高 |
| Task Bridge API + Dart UI | **OSS** (`termex_shared`) | 用户接触面 |
| **WebSocket 长连接 + 反向 SSH 隧道** | **OSS** | 主力通讯链路必须开源，避免 Pro 锁定 |
| **本地通知 + 屏幕常亮** | **OSS** | 基础能力 |
| **FCM 推送** | **Pro** (`termex-core-private/src/push/`) | 跨云后台推送服务 |
| 国内厂商推送（极光 / Xiaomi / Huawei / OPPO / vivo） | **Pro**（推迟到 v0.75+） | 商业服务 |
| 语音转文本 | OSS（用平台原生 API） | iOS Dictation / Android speech-to-text |
| Siri Shortcuts / App Intents | OSS | 平台 API |
| EgressProfile DTO + storage | **OSS** (`termex-core/src/egress/`) | 数据基础设施 |
| EgressProfile sync 合并逻辑 | **Pro** (`termex-core-private/src/sync/`) | 多端协作 |
| Cross-device WorkSession 接手 | **Pro** | 多端协作 |
| 成本透明面板 | **OSS** | 用户安全感的基础 |

**核心修订**：v1 把推送整体进 Pro 导致 OSS 用户失去通知能力，错。v2 让 **WS + 反向 SSH + 本地通知** 进 OSS 作为主力，**FCM 仅作为 app 后台 / 锁屏时的可选增强** 进 Pro。

---

## 6. 路线图（执行依据）

| 迭代 | 主题 | 目标 |
|---|---|---|
| **v0.70.5** | [termexd 远端守护进程](iterations/v0.70.5-core-termexd-daemon.md) | **架构底座** — 在远端持久化任务状态、暴露 WS API、MCP-aware、反向 SSH 隧道支持 |
| **v0.71** | [任务监控 MVP](iterations/v0.71-mobile-task-delivery-loop.md) | 任务模型 + 4 个 adapter + **语音输入** + **安全护栏** + **结构化摘要主视图** + WS 主推送 |
| **v0.72** | [实时反馈 + 移动 AI 面板](iterations/v0.72-mobile-terminal-and-ai-panel.md) | 结构化摘要为主、terminal view 为辅、多 tab + AI 抽屉 |
| **v0.73** | [网络路径同步 + 成本透明](iterations/v0.73-mobile-network-path-parity.md) | EgressProfile sync（**砍编辑器**） + 成本面板 + Cross-device handoff 基础 |
| **v0.74** | [后台保活 + 可靠性](iterations/v0.74-mobile-background-and-reliability.md) | Android Foreground Service + iOS BGTask + 网络抗抖 + handoff 完成 + 通知冷启动恢复 |
| **v0.75+** | （后续）国内推送 + 语音深化 + Live Activity | 极光/小米/华为/OPPO/vivo 厂商推送适配；Siri Shortcuts；语音摘要播报；iOS Live Activity |

**关键变化 vs v1**：
- 新增 v0.70.5 termexd daemon 作为前置
- v0.73 砍掉 chain/proxy/forward 编辑器，加入成本透明面板 + handoff
- 国内推送 / Live Activity 推迟到 v0.75+（避免 v0.71-v0.74 范围爆炸）

---

## 7. 衡量成功的指标（修订）

| 维度 | 指标 | 目标值 |
|---|---|---|
| **持久链路存活率** | WS 长连接在 app 前台时存活率 | ≥ 99.5% |
| **反馈延迟** | 远端事件 → app 收到（WS 路径） | P95 < 1s |
| **反馈延迟（推送 fallback）** | 远端事件 → 推送到达（app 后台 / 锁屏） | P95 < 5s |
| **结构化摘要覆盖率** | 任务完成时有结构化摘要的比例（非纯 raw output） | ≥ 90% |
| **高风险拦截率** | 高 risk 动作被 PendingConfirmation 拦截的比例 | 100%（强制） |
| **网络一致性** | EgressProfile 绑定后客户端来源 IP（PC vs Mobile） | 100% 相同 |
| **后台保活** | Android Foreground Service 1 小时电量消耗 | ≤ 5% |
| **冷启动恢复** | 收到通知 → 点击 → 进入任务详情耗时 | P95 < 3s |
| **语音输入采用率**（产品成熟后） | 派遣任务用语音 vs 键盘的比例 | ≥ 30% |
| **任务完成识别准确率** | adapter 不误识别 / 不漏识别完成的比例 | ≥ 98% |

**修订**：删除 "DAU 中 ≥ 3 次循环" 的高频派遣指标（场景叙事调整后不再合理），加入摘要覆盖率 + 高风险拦截率 + 语音采用率。

---

## 8. 维护约定

- 此战略定位是 mobile 迭代的**最上位依据**，每个 mobile 迭代文档必须明确指向本文件中的某一支柱或场景
- 与本定位冲突的需求（如"把桌面端所有功能完整搬到手机"或"手机做复杂网络配置编辑"）应**主动拒绝**
- 重大调整（如本次 v1→v2）需更新本文件版本头并在迭代文档中标注变更影响范围

---

## 附 A · 相关文档

- [`README.md`](../README.md) — 项目总览，含移动端入口指引
- [`CLAUDE.md`](../CLAUDE.md) — 代码协作规则
- [`docs/requirements.md`](requirements.md) — 桌面 + 移动通用产品需求
- [`docs/iterations/`](iterations/) — 全部迭代历史
- [`CLAUDE.local.md`](../CLAUDE.local.md) — 闭源拆分背景（仅本地）
