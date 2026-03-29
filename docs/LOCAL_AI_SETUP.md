# Termex v0.11.0 本地 AI 模型 - 安装和配置指南

> 本文档指导开发者和用户完成 llama-server 二进制、模型文件的获取和配置

---

## 快速开始（开发者）

### 1. 获取 llama-server 二进制

```bash
# 创建资源目录
mkdir -p src-tauri/resources/bin

# 从 llama.cpp Release 下载（选择最新版本，如 b3217）
# macOS arm64 (Apple Silicon)
curl -L -o src-tauri/resources/bin/llama-server-macos-arm64 \
  "https://github.com/ggerganov/llama.cpp/releases/download/b3217/llama-server-macos-arm64"
chmod +x src-tauri/resources/bin/llama-server-macos-arm64

# macOS x86_64 (Intel Mac) - 可选，用于跨平台兼容性
curl -L -o src-tauri/resources/bin/llama-server-macos-x64 \
  "https://github.com/ggerganov/llama.cpp/releases/download/b3217/llama-server-macos-x64"
chmod +x src-tauri/resources/bin/llama-server-macos-x64

# Windows x64
curl -L -o src-tauri/resources/bin/llama-server-windows-x64.exe \
  "https://github.com/ggerganov/llama.cpp/releases/download/b3217/llama-server-windows-x64.exe"

# Linux x64
curl -L -o src-tauri/resources/bin/llama-server-linux-x64 \
  "https://github.com/ggerganov/llama.cpp/releases/download/b3217/llama-server-linux-x64"
chmod +x src-tauri/resources/bin/llama-server-linux-x64

# Linux aarch64 (ARM)
curl -L -o src-tauri/resources/bin/llama-server-linux-aarch64 \
  "https://github.com/ggerganov/llama.cpp/releases/download/b3217/llama-server-linux-aarch64"
chmod +x src-tauri/resources/bin/llama-server-linux-aarch64
```

**验证二进制**：
```bash
# 检查文件存在
ls -lh src-tauri/resources/bin/llama-server-*

# 测试能否执行（macOS/Linux）
./src-tauri/resources/bin/llama-server-macos-arm64 --help
```

### 2. 验证 Tauri 配置

打开 `src-tauri/tauri.conf.json`，确保有以下配置：

```json
{
  "build": {
    "resources": [
      "resources/bin"
    ]
  }
}
```

### 3. 测试开发构建

```bash
# 完整开发构建（包含 llama-server 资源）
pnpm tauri dev

# 或者仅前端
pnpm dev

# 启用详细日志
RUST_LOG=debug pnpm tauri dev
```

### 4. 获取模型 SHA256（可选但推荐）

运行辅助脚本验证模型 URL 和计算 SHA256：

```bash
# 使生成脚本可执行
chmod +x scripts/update-model-hashes.sh

# 运行脚本
./scripts/update-model-hashes.sh

# 输出示例：
# Checking tinyllama-1.1b-q2... ✓
# Checking qwen2.5-7b-q4... ✓
# ...
```

如果要下载所有模型并计算 SHA256：

```bash
#!/bin/bash
# 创建模型目录
mkdir -p ~/.termex/models

# 下载微型模型（快速测试）
echo "Downloading TinyLlama 1.1B Q2..."
curl -o ~/.termex/models/tinyllama-1.1b-q2.gguf \
  "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"

# 计算 SHA256
sha256sum ~/.termex/models/tinyllama-1.1b-q2.gguf

# 更新 src/assets/local-models.json 中对应模型的 sha256 字段
```

---

## 用户使用指南

### 首次使用

1. **启动应用** → 前往"设置" > "AI 配置"
2. **查看本机离线模型** → 展开"本机离线模型"面板
3. **选择模型下载** → 根据硬件配置选择合适的模型梯度：
   - **微型**（< 200MB）：2GB RAM 最低，极限低配
   - **小型**（200MB-1GB）：4GB RAM，日常轻量使用
   - **中型**（1GB-5GB）：8GB RAM，平衡性能和质量
   - **大型**（> 5GB）：16GB RAM，推荐，最佳质量 ⭐

### 下载模型

1. 点击任意模型的"下载"按钮
2. 应用会：
   - 检查磁盘可用空间（需 >= 模型大小 × 1.2）
   - 通过 HTTP Range 请求下载（支持断点续传）
   - 验证 SHA256 哈希
   - 自动保存到 `~/.termex/models/`

3. 进度条显示实时下载进度，可随时"取消"

### 使用模型

1. 下载完成后，点击"用作 AI 提供商"
2. 应用自动：
   - 启动 llama-server 子进程
   - 加载选定的模型
   - 创建对应的 AI provider（可在 AI 配置中管理）

3. 在 AI 面板中使用该模型解释命令、转换自然语言命令等

### 切换模型

1. 选择另一个已下载的模型，点击"用作 AI 提供商"
2. 旧模型自动卸载，新模型加载（大约 2-3 秒）

### 删除模型

1. 点击已下载模型的"删除"按钮
2. 确认删除后，文件从 `~/.termex/models/` 移除
3. 磁盘空间释放

---

## 模型详细信息

### Micro Tier（微型）

| 模型 | 大小 | 推荐配置 | 用途 |
|------|------|--------|------|
| **TinyLlama 1.1B Q2** | 180 MB | 2GB RAM | 最小化资源使用，基础命令理解 |
| **Qwen2.5 0.5B Q3** | 150 MB | 2GB RAM | 轻量双语模型，中文支持 |
| **Phi-2 2.7B Q2** | 160 MB | 2GB RAM | 微软轻量模型，性能不错 |

**何时使用**：老旧笔记本、树莓派、资源受限的远程机器

### Small Tier（小型）

| 模型 | 大小 | 推荐配置 | 用途 |
|------|------|--------|------|
| **Qwen2.5 0.5B Q4** | 400 MB | 4GB RAM | 更好的中文支持，Q4 更精准 |
| **Phi-3 3B Q3** | 640 MB | 4GB RAM | 微软 3B 模型，性能平衡 |
| **MobileQwen 0.5B Q4** | 350 MB | 4GB RAM | 移动优化，双语支持 |

**何时使用**：标准笔记本、轻量级使用、日常开发

### Medium Tier（中型）

| 模型 | 大小 | 推荐配置 | 用途 |
|------|------|--------|------|
| **Llama 3.2 3B** | 2.0 GB | 8GB RAM | Meta Llama，通用能力强 |
| **Qwen2.5 3B** | 2.0 GB | 8GB RAM | 阿里通义，中文优化 |
| **Phi-3 3B Q4** | 2.0 GB | 8GB RAM | 微软高精度，英文优势 |

**何时使用**：大多数开发者的最佳选择，平衡推理速度和精度

### Large Tier（大型）

| 模型 | 大小 | 推荐配置 | 用途 |
|------|------|--------|------|
| **Qwen2.5 7B** ⭐ | 4.7 GB | 16GB RAM | **推荐**，中英文都优秀 |
| **Llama 3.3 8B** | 5.2 GB | 16GB RAM | Meta 旗舰，通用能力最强 |
| **DeepSeek-Coder 7B** | 4.7 GB | 16GB RAM | 代码专门优化，编程最佳 |

**何时使用**：高端机器、高质量要求、编程任务、生产环境

---

## 常见问题

### Q: 下载速度慢怎么办？

**A**: HuggingFace 由于各国网络差异可能较慢。可尝试：

1. 使用代理（如 hf-mirror.com）
2. 设置国内镜像（Linux 用户可配置 huggingface 环境变量）
3. 在网络条件好的时段下载
4. 大文件可分多次下载（断点续传支持）

### Q: 模型存在哪里？

**A**: `~/.termex/models/` 目录：
- macOS: `$HOME/.termex/models/`
- Linux: `$HOME/.termex/models/`
- Windows: `%APPDATA%\termex\models\`

### Q: 可以手动放入模型吗？

**A**: 可以。直接将 `.gguf` 文件放入上述目录，重启应用即可识别。

### Q: 如何离线使用？

**A**:
1. 联网时下载好模型
2. 离线后，应用仍可加载已下载的模型
3. llama-server 100% 离线推理，无需任何网络连接

### Q: 可以用自定义模型吗？

**A**: v0.11.0 不支持，但可手动放入 `.gguf` 文件后修改 UI。计划 v1.0 支持用户自定义模型列表。

### Q: 推理速度多快？

**A**: 取决于硬件和模型：
- **首 token（首个推理结果）**：2-5 秒
- **每个后续 token**：0.1-0.5 秒
- **GPU 加速**：如果硬件支持 GPU（Metal/CUDA/Vulkan），速度快 5-20 倍

### Q: 显存占用多少？

**A**: 大约 VRAM 占用 = 模型大小 + ~200MB 开销
- TinyLlama: ~400 MB
- Qwen2.5 7B: ~5 GB
- 确保系统可用 VRAM > 模型大小

---

## 故障排除

### 问题：下载失败，显示"网络错误"

**解决方案**：
```bash
# 1. 检查网络
ping huggingface.co

# 2. 清除已下载的不完整文件（.tmp）
rm ~/.termex/models/*.tmp

# 3. 重试下载（应会从断点续传）
```

### 问题：模型加载失败，引擎显示"停止"

**解决方案**：
```bash
# 1. 检查 llama-server 二进制是否存在
ls -la ~/.termex/bin/llama-server-*

# 2. 手动测试二进制
~/.termex/bin/llama-server-macos-arm64 --help

# 3. 查看应用日志
# macOS: System Preferences → Privacy & Security → Files and Folders
# Linux: journalctl -u termex -f
# Windows: Event Viewer → Windows Logs → Application
```

### 问题：推理超时，AI 面板无响应

**解决方案**：
```bash
# 1. 检查 llama-server 是否运行
ps aux | grep llama-server

# 2. 测试 API 连接（先确定端口，见下文）
lsof -i :8000  # 查找占用的端口

# 3. 手动测试
curl http://localhost:8043/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"Hello"}]}'
```

### 问题：SHA256 验证失败

**解决方案**：
```bash
# 1. 手动计算本地文件的 SHA256
sha256sum ~/.termex/models/qwen2.5-7b-instruct-q4_k_m.gguf

# 2. 与 local-models.json 中的值对比
# 如果不匹配，可能是：
#   a) 源文件已更新（需更新 JSON 中的 SHA256）
#   b) 下载过程被篡改（请重新下载）
```

---

## 开发者参考

### 获取最新 llama-server

查看 [llama.cpp Releases](https://github.com/ggerganov/llama.cpp/releases) 找最新版本号（如 `b3217`），然后：

```bash
BASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/b3217"

# 下载所有平台
curl -L -o llama-server-macos-arm64 "$BASE_URL/llama-server-macos-arm64"
curl -L -o llama-server-macos-x64 "$BASE_URL/llama-server-macos-x64"
curl -L -o llama-server-windows-x64.exe "$BASE_URL/llama-server-windows-x64.exe"
curl -L -o llama-server-linux-x64 "$BASE_URL/llama-server-linux-x64"
curl -L -o llama-server-linux-aarch64 "$BASE_URL/llama-server-linux-aarch64"
```

### 更新模型列表

编辑 `src/assets/local-models.json`：
- 添加或删除模型
- 更新 `downloadUrl`（HuggingFace resolve 链接）
- 更新 `sha256`（下载后计算）
- 更新 `catalogVersion`（与版本号同步）

### 国际化

添加新模型时，在 i18n 文件中添加对应的标签（如需要特殊描述）：

```typescript
// src/i18n/locales/en-US.ts
localAi: {
  // 已有的
  // ...
}
```

---

## 相关文档

- [v0.11.0 迭代计划](./iterations/v0.11.0-local-ai-models.md)
- [测试与部署指南](./iterations/v0.11.0-testing-deployment.md)
- [llama.cpp 服务器 API](https://github.com/ggerganov/llama.cpp/tree/master/examples/server)
