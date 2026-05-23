# Termex 隐私政策 / Privacy Policy

> 生效日期 / Effective Date: 2026-05-07

---

## 中文版

### 1. 概述

Termex 是一款开源的 SSH 客户端。我们非常重视您的隐私。**本应用不收集、不传输、不存储任何用户数据到 Termex 服务器**——因为 Termex 没有后端服务器。

### 2. 数据存储

所有数据（服务器配置、SSH 凭据、AI API 密钥）仅存储在您的设备本地：

| 数据类型 | 存储位置 | 加密方式 |
|---------|---------|---------|
| 服务器配置 | 本地 SQLite（SQLCipher 加密）| AES-256 |
| SSH 密码 / 私钥密码短语 | iOS Keychain / Android Keystore | 平台加密 |
| AI API 密钥 | iOS Keychain / Android Keystore | 平台加密 |
| 会话录制文件 | 本地文件系统 | 无（本地文件）|
| 监控历史数据 | 本地 SQLite（SQLCipher 加密）| AES-256 |

### 3. 网络连接

Termex 仅建立以下网络连接：

- **SSH 连接**：直连您指定的服务器，不经过任何 Termex 中间节点
- **AI 请求**：直连您配置的 AI 服务提供商（OpenAI、Anthropic 等），Termex 不作为代理
- **推送通知**：通过 APNs（iOS）/ FCM（Android）传递通知，仅包含服务器 ID 和事件类型，不包含命令输出内容
- **跨设备同步**（可选）：仅在同一局域网内的 Termex 设备之间直接通信，不经过云服务器

### 4. 第三方 SDK

| SDK | 用途 | 数据收集 |
|-----|------|---------|
| Firebase Cloud Messaging | 推送通知 | 设备令牌（存储在本地 Keychain，不上传到 Termex）|
| flutter_secure_storage | 凭据安全存储 | 无 |
| local_auth | 生物识别认证 | 无 |

Firebase 的隐私政策：https://firebase.google.com/support/privacy

### 5. 权限说明

| 权限 | 用途 |
|-----|------|
| 网络访问 | SSH 连接 |
| 相机 | 扫描二维码导入服务器配置 |
| 生物识别（Face ID / 指纹）| 解锁 Keychain 中的凭据 |
| 本地网络 | 发现同一 Wi-Fi 下的 Termex 设备（跨设备同步）|
| 通知 | SSH 事件推送（如命令执行完成）|

### 6. 联系方式

如有隐私相关问题，请通过以下方式联系：

- GitHub Issues: https://github.com/termex-app/termex/issues
- 邮件: karpenwon644@gmail.com

---

## English Version

### 1. Overview

Termex is an open-source SSH client. We take your privacy seriously. **This app does not collect, transmit, or store any user data to Termex servers** — because Termex has no backend server.

### 2. Data Storage

All data (server configs, SSH credentials, AI API keys) is stored locally on your device only:

| Data Type | Storage | Encryption |
|-----------|---------|------------|
| Server configurations | Local SQLite (SQLCipher) | AES-256 |
| SSH passwords / key passphrases | iOS Keychain / Android Keystore | Platform encryption |
| AI API keys | iOS Keychain / Android Keystore | Platform encryption |
| Session recordings | Local filesystem | None (local files) |
| Monitoring history | Local SQLite (SQLCipher) | AES-256 |

### 3. Network Connections

Termex only establishes these network connections:

- **SSH connections**: Direct to your specified servers. No Termex intermediary.
- **AI requests**: Direct to your configured AI provider (OpenAI, Anthropic, etc.). Termex does not proxy these requests.
- **Push notifications**: Delivered via APNs (iOS) / FCM (Android). Payloads contain server ID and event type only — no command output.
- **Cross-device sync** (optional): Direct peer-to-peer within the same LAN. No cloud server involved.

### 4. Third-party SDKs

| SDK | Purpose | Data Collected |
|-----|---------|----------------|
| Firebase Cloud Messaging | Push notifications | Device token (stored locally in Keychain, not uploaded to Termex) |
| flutter_secure_storage | Secure credential storage | None |
| local_auth | Biometric authentication | None |

Firebase Privacy Policy: https://firebase.google.com/support/privacy

### 5. Permissions

| Permission | Purpose |
|-----------|---------|
| Network access | SSH connections |
| Camera | Scan QR code to import server config |
| Biometrics (Face ID / Fingerprint) | Unlock Keychain credentials |
| Local network | Discover Termex devices on same Wi-Fi (cross-device sync) |
| Notifications | SSH event alerts (e.g. command completed) |

### 6. Contact

For privacy-related questions:

- GitHub Issues: https://github.com/termex-app/termex/issues
- Email: karpenwon644@gmail.com
