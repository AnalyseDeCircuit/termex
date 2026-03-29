# llama-server 二进制获取 - 详细指南

> 无法自动下载时的手动获取方案

---

## 问题诊断

自动下载脚本失败的可能原因：

1. **网络限制**（国内用户常见）
   - GitHub 访问速度慢
   - 防火墙拦截
   - ISP 限制

2. **速率限制**（Rate Limit）
   - GitHub API 限制
   - 同时多个下载请求

3. **二进制不存在**
   - Release 标签错误
   - 文件重命名

---

## 方案 A：手动下载（推荐）

### 步骤 1：访问 Release 页面

打开浏览器访问：
```
https://github.com/ggerganov/llama.cpp/releases/latest
```

或直接访问最新版本（b8575）：
```
https://github.com/ggerganov/llama.cpp/releases/tag/b8575
```

### 步骤 2：下载对应平台的二进制

在页面底部找到 "Assets" 部分，下载以下文件：

| 平台 | 文件名 | 用途 |
|------|--------|------|
| **macOS arm64** | `llama-server-macos-arm64` | Apple Silicon (M1/M2/M3) |
| **macOS x64** | `llama-server-macos-x64` | Intel Mac |
| **Windows** | `llama-server-windows-x64.exe` | Windows 64-bit |
| **Linux x64** | `llama-server-linux-x64` | Linux 64-bit |
| **Linux ARM** | `llama-server-linux-aarch64` | 树莓派/ARM 服务器 |

**注意**：如果找不到这些确切的名称，寻找类似的名称，如：
- `llama-server` + 平台标识
- 版本号可能不同（如 `b8574` 而非 `b8575`）

### 步骤 3：放置文件到正确位置

下载后，将文件放入应用资源目录：

**macOS / Linux**：
```bash
mkdir -p src-tauri/resources/bin
cp ~/Downloads/llama-server-macos-arm64 src-tauri/resources/bin/
chmod +x src-tauri/resources/bin/llama-server-*
```

**Windows**（PowerShell）：
```powershell
New-Item -ItemType Directory -Path "src-tauri\resources\bin" -Force
Copy-Item "$env:USERPROFILE\Downloads\llama-server-windows-x64.exe" -Destination "src-tauri\resources\bin\"
```

### 步骤 4：验证

```bash
ls -la src-tauri/resources/bin/
# 应显示所有已下载的二进制文件
```

---

## 方案 B：从源代码编译

如果无法从 Release 下载，可以自己编译：

### 前置条件

```bash
# macOS
brew install cmake

# Ubuntu/Debian
sudo apt-get install build-essential cmake

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install cmake
```

### 编译步骤

```bash
# 1. 克隆 llama.cpp 仓库
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# 2. 编译（使用 make）
make -j $(nproc)

# 或使用 CMake
mkdir build && cd build
cmake ..
cmake --build . --config Release -j $(nproc)
cd ..

# 3. 找到编译好的二进制
ls -la llama-server

# 4. 复制到资源目录
cp llama-server ../termex/src-tauri/resources/bin/llama-server-macos-arm64
# （根据您的平台重命名）
```

**编译时间**：5-15 分钟（取决于硬件）

---

## 方案 C：使用国内镜像（中国用户）

### Gitee 镜像

```bash
# 克隆 Gitee 镜像
git clone https://gitee.com/ggerganov/llama.cpp.git
cd llama.cpp

# 编译
make -j $(nproc)

# 复制到 Termex
cp llama-server ../termex/src-tauri/resources/bin/
```

### 镜像列表

- Gitee: https://gitee.com/ggerganov/llama.cpp
- 其他国内镜像：搜索"llama.cpp 镜像"

---

## 方案 D：使用 Docker 编译

如果本地无合适的编译环境：

```bash
# 1. 使用 docker 编译
docker run -v $(pwd):/workspace -w /workspace \
  ubuntu:22.04 bash -c "
    apt-get update && \
    apt-get install -y build-essential cmake git && \
    git clone https://github.com/ggerganov/llama.cpp.git && \
    cd llama.cpp && \
    make -j $(nproc)
  "

# 2. 二进制会在 llama.cpp/llama-server
```

---

## 方案 E：CI/CD 预构建

如果您运行 Termex 的 GitHub Actions（未来版本），可以自动构建：

```yaml
# .github/workflows/build-binaries.yml
name: Build llama-server Binaries

on: [push]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - run: |
          git clone https://github.com/ggerganov/llama.cpp.git
          cd llama.cpp && make -j 4
          cp llama-server ../src-tauri/resources/bin/llama-server-macos-arm64
      - uses: actions/upload-artifact@v3
        with:
          name: binaries
          path: src-tauri/resources/bin/
```

---

## 故障排除

### 问题：找不到二进制文件

**检查**：
1. Release 页面是否正确
   ```bash
   curl -I "https://github.com/ggerganov/llama.cpp/releases/tag/b8575"
   ```

2. 文件是否已上传（Release 有时还在处理）
   - 等待 1-2 小时，重新检查

3. 版本号是否正确
   - 查看最新的 Release（可能已有新版本）

### 问题：编译失败

**常见原因和解决**：

```bash
# 错误：cmake: command not found
sudo apt-get install cmake

# 错误：gcc/clang: command not found
# macOS
xcode-select --install

# Linux
sudo apt-get install build-essential

# 错误：python3: command not found
sudo apt-get install python3
```

### 问题：二进制无法执行

```bash
# 检查权限
ls -la src-tauri/resources/bin/llama-server-*

# 添加执行权限
chmod +x src-tauri/resources/bin/llama-server-*

# 检查依赖（macOS）
otool -L src-tauri/resources/bin/llama-server-macos-arm64

# 检查依赖（Linux）
ldd src-tauri/resources/bin/llama-server-linux-x64
```

---

## 验证二进制完整性

下载/编译完成后，验证二进制：

```bash
# 检查文件大小（应 > 20MB）
ls -lh src-tauri/resources/bin/llama-server-*

# 测试能否执行
src-tauri/resources/bin/llama-server-macos-arm64 --help

# 预期输出：usage: llama-server [options] ...
```

---

## 下一步

完成二进制部署后：

1. 运行开发环境
   ```bash
   pnpm tauri dev
   ```

2. 应用启动时应正确加载 llama-server
   - 日志中出现："llama-server binary found"

3. 在 LocalAiPanel 中下载模型并测试

---

## 技术支持

如在二进制获取中遇到问题：

1. 检查 [llama.cpp GitHub Issues](https://github.com/ggerganov/llama.cpp/issues)
2. 在 Termex [GitHub Discussions](https://github.com/termex/termex/discussions) 提问
3. 参考 [llama.cpp 文档](https://github.com/ggerganov/llama.cpp#building)
