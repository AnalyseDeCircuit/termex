#!/bin/bash

# Termex v0.11.0: 开发环境快速设置
# 用途：为开发和测试设置 llama-server 占位符和示例模型

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_ROOT/src-tauri/resources/bin"
MODELS_DIR="$HOME/.termex/models"

echo "=================================================="
echo "  Termex v0.11.0 - 开发环境设置"
echo "=================================================="
echo ""

# 1. 创建目录
echo "[1/4] 创建必要目录..."
mkdir -p "$BIN_DIR"
mkdir -p "$MODELS_DIR"
echo "  ✓ 目录已创建"

# 2. 创建模拟 llama-server 二进制（用于开发）
echo ""
echo "[2/4] 创建开发用占位符二进制..."

create_mock_binary() {
  local binary=$1
  local platform=$2

  cat > "$BIN_DIR/$binary" << 'EOF'
#!/bin/bash
# 模拟 llama-server（开发用）

PORT=8043
MODEL=""
GPU_LAYERS="99"

while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --n-gpu-layers)
      GPU_LAYERS="$2"
      shift 2
      ;;
    --help)
      echo "usage: llama-server [options]"
      echo ""
      echo "options:"
      echo "  --model <path>           model path"
      echo "  --port <port>            server port (default: 8000)"
      echo "  --n-gpu-layers <n>       GPU layers (default: 0)"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

echo "Mock llama-server starting..."
echo "Model: $MODEL"
echo "Port: $PORT"
echo "GPU Layers: $GPU_LAYERS"
echo ""
echo "Server listening on http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop"

# 模拟运行（保持进程活跃）
trap "echo 'Server stopped'" EXIT
while true; do
  sleep 10
done
EOF

  chmod +x "$BIN_DIR/$binary"
  echo "  ✓ $binary ($platform)"
}

create_mock_binary "llama-server-macos-arm64" "macOS arm64"
create_mock_binary "llama-server-macos-x64" "macOS x64"
create_mock_binary "llama-server-windows-x64.exe" "Windows x64"
create_mock_binary "llama-server-linux-x64" "Linux x64"
create_mock_binary "llama-server-linux-aarch64" "Linux ARM64"

# 3. 创建示例模型文件（用于测试下载逻辑）
echo ""
echo "[3/4] 创建示例模型文件..."

# 创建一个小的 GGUF 文件（仅用于测试）
create_sample_model() {
  local model_id=$1
  local size_kb=$2

  # 创建指定大小的虚拟文件
  dd if=/dev/zero bs=1024 count="$size_kb" 2>/dev/null | \
    base64 | head -c "$((size_kb * 1024))" > "$MODELS_DIR/$model_id.gguf"

  echo "  ✓ $model_id ($(du -h "$MODELS_DIR/$model_id.gguf" | awk '{print $1}'))"
}

# 创建几个示例模型（用于测试）
# create_sample_model "tinyllama-1.1b-q2.gguf" 180  # 180KB 而非 180MB
# 注：完整大小的模型需要实际下载

# 4. 打印配置信息
echo ""
echo "[4/4] 验证配置..."
echo ""
echo "已部署的二进制："
ls -lh "$BIN_DIR"/llama-server-* 2>/dev/null | while read line; do
  echo "  $line"
done

echo ""
echo "模型目录："
echo "  $MODELS_DIR"
ls -lh "$MODELS_DIR"/* 2>/dev/null || echo "  （暂无模型文件）"

echo ""
echo "=================================================="
echo "✓ 开发环境设置完成"
echo "=================================================="
echo ""
echo "下一步："
echo ""
echo "1. 启动开发服务器："
echo "   pnpm tauri dev"
echo ""
echo "2. 为了完整测试，下载实际模型："
echo "   - 参考 docs/BINARY_SETUP_GUIDE.md 获取 llama-server 二进制"
echo "   - 参考 docs/LOCAL_AI_SETUP.md 下载模型"
echo ""
echo "3. 当前的占位符二进制仅用于开发和 UI 测试"
echo ""
echo "其他命令："
echo "  - pnpm run build     # 前端生产构建"
echo "  - pnpm tauri build   # 完整应用构建"
echo "  - cd src-tauri && cargo test  # 运行 Rust 测试"
echo ""
