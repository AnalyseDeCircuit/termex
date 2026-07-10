# 用旧手机 + Termex 构建个人 SSH 文件柜

> 把闲置的旧手机变成 Termex 可直接访问的个人文件存储节点。
> 零代码、零额外硬件、零云服务费 — 充分利用 Termex 内置的 SFTP 浏览器。

---

## 适用场景

- 家里有闲置 Android 手机（128G / 256G 内置存储未利用）
- 希望随身手机 / 笔记本能像访问云盘一样浏览旧手机里的文件
- 不想搭独立 NAS、不想付月费云存储
- 已经在用 Termex（移动版 / 桌面版均可）

## 工作原理

旧手机端跑 **Termux + OpenSSH server**，把内置存储暴露成 SSH/SFTP 服务；
Termex 把这台旧手机当成一台普通 SSH 服务器添加进列表，**SFTP 浏览器即时
可用**（上传 / 下载 / 续传 / 双面板拖拽 全部复用现有能力）。

```
┌──────────────────┐   LAN (Wi-Fi)    ┌──────────────────────┐
│  随身手机 / 笔记本  │  ──────────────► │  旧手机                │
│  Termex           │  SSH/SFTP        │  Termux + sshd        │
│  └ SFTP 浏览器     │                  │  └ /sdcard/...        │
└──────────────────┘                  └──────────────────────┘
```

---

## 旧手机端配置

### 1. 安装 Termux

从 [F-Droid](https://f-droid.org/packages/com.termux/) 安装最新版（**不要**用 Google
Play 的旧版本，已停止更新）。

### 2. 启动 sshd

```bash
# 首次启动会自动初始化
pkg update -y
pkg install -y openssh

# 设置 Termux 用户密码（强密码 12+ 位）
passwd

# 允许 Termux 读 /sdcard
termux-setup-storage

# 启动 sshd（监听 8022 端口）
sshd

# 查看 Termux 当前用户名（通常类似 u0_a123）
whoami
```

### 3. 查看 LAN IP

```bash
ifconfig wlan0 | grep "inet "
# 例：inet 192.168.1.42
```

### 4. 保持后台运行（关键）

旧手机系统会定期杀掉后台进程。为了让 sshd 持续可达：

| 设置 | 路径 |
|---|---|
| 关闭电池优化（针对 Termux） | 设置 → 应用 → Termux → 电池 → 不优化 |
| 关闭"睡眠时关闭 Wi-Fi"        | 设置 → Wi-Fi → 高级 → Wi-Fi 睡眠策略 → 始终 |
| 锁屏不限制后台                | 各厂商「保活白名单」/「自启」/「关联启动」勾上 Termux |
| 插电 + 关闭自动锁屏（可选）   | 减少 Doze 模式触发 |

国产厂商保活提示：
- **小米**：设置 → 应用设置 → 应用管理 → Termux → 省电策略 → 无限制
- **华为/荣耀**：设置 → 电池 → 启动管理 → Termux → 手动管理（三项全开）
- **OPPO/OnePlus**：设置 → 电池 → 高耗电应用 → Termux → 允许后台运行
- **vivo**：i 管家 → 应用管理 → 自启动 / 后台耗电管理 → 允许 Termux

### 5. 自启（可选但推荐）

安装 **Termux:Boot**（F-Droid 上同名 app），在 `~/.termux/boot/start-sshd`
里写：

```bash
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
```

`chmod +x` 后，开机即自动起 sshd 并锁住 wakelock。

### 6. 加固（强烈建议）

```bash
# 关闭密码登录，仅允许公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# 把 Termex 端的公钥贴进 authorized_keys
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 修改 sshd 配置
nano $PREFIX/etc/ssh/sshd_config
# 设置：
#   PasswordAuthentication no
#   PermitEmptyPasswords no
#   Port 8022     （或改个别的端口）
```

重启 sshd：`pkill sshd && sshd`。

---

## Termex 端添加

1. 打开 Termex → 服务器列表 → 添加服务器
2. 填表：

   | 字段 | 值 |
   |---|---|
   | 名称 | 例如 "家里-红米 Note 10" |
   | 主机 | 第 3 步查到的 LAN IP（例：`192.168.1.42`）|
   | 端口 | `8022` |
   | 用户 | 第 2 步 `whoami` 的输出（例：`u0_a123`）|
   | 认证 | 公钥（推荐）或密码 |

3. 保存 → 测试连接 → 打开 SFTP 浏览器

### 常用目录

| 路径 | 内容 |
|---|---|
| `/sdcard/` 或 `/storage/emulated/0/` | 主存储（相册、下载、文档）|
| `/sdcard/DCIM/Camera/` | 相机相册 |
| `/sdcard/Download/` | 下载目录 |
| `/sdcard/Pictures/` | 截图 / 其他图片 |
| `/data/data/com.termux/files/home/` | Termux 自家目录 |

---

## 局限性与安全提示

- **仅限 LAN**：本指南假设旧手机和访问端在同一 Wi-Fi。出门访问可叠加
  [Tailscale](https://tailscale.com)（免费组网，零配置 NAT 穿透）。
- **断电 / 断网就掉线**：手机不是 7×24 服务器，掉线是常态。重要资料**仍**
  应另有备份（云盘、电脑硬盘等），不要只依赖这台旧手机。
- **不开公网端口**：千万不要把 8022 端口直接转发到公网，会瞬间被扫到。
  需要外网访问就用 Tailscale / WireGuard / Cloudflare Tunnel。
- **公钥认证优先**：密码哪怕再强，公网/局域网都不如禁用密码、只允许公钥
  来得安全。
- **存储空间≠云盘**：手机内置 eMMC/UFS 长期高负载读写寿命远低于 SSD/HDD；
  不建议跑高频写入工作流（数据库、日志服务等）。

---

## 为什么不要装 WebDAV / NAS 软件？

社区里也有 WebDAV Server / KSWEB 等方案。本文坚持用 SSH/SFTP 的原因：

1. **零额外学习成本** — 你已经在用 Termex，Termex 已经会 SFTP
2. **同源协议** — SSH 是 OpenSSH 项目几十年安全实践，鉴权 / 加密 /
   完整性都是默认强项
3. **通杀客户端** — macOS Finder（`cmd+K` → `sftp://`）/ Windows
   WinSCP / Linux GVFS / 手机端各家文件管理器都原生支持 SFTP
4. **可叠加端口转发** — Termex 自带 SSH Tunnel 能力，旧手机里跑别的
   服务（HTTP / 数据库测试实例）也能反向打通

---

## 验证清单

- [ ] 旧手机 `sshd` 启动成功（`ps -ef | grep sshd` 看到进程）
- [ ] 同 Wi-Fi 下 `ssh -p 8022 u0_a???@192.168.1.42` 能登录
- [ ] Termex SFTP 浏览器能列出 `/sdcard/DCIM/Camera`
- [ ] 上传一张测试图片到 `/sdcard/Download/` 成功
- [ ] 从 `/sdcard/Pictures/` 下载一张图片成功
- [ ] 锁屏 10 分钟后重新连接仍然可用（验证保活配置生效）

完成以上 6 条，这台旧手机就正式变成你的「Termex 个人 SSH 文件柜」了。
