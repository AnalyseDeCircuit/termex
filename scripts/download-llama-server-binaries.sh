#!/bin/bash

# Termex v0.11.0: llama-server 二进制下载脚本
# 用法：./scripts/download-llama-server-binaries.sh

set -e

RELEASE_TAG="b8575"  # 最新稳定版本，2026-03-28
BASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/$RELEASE_TAG"
BIN_DIR="src-tauri/resources/bin"

# 二进制列表
BINARIES=(
  "llama-server-macos-arm64:macOS Apple Silicon"
  "llama-server-macos-x64:macOS Intel"
  "llama-server-windows-x64.exe:Windows x64"
  "llama-server-linux-x64:Linux x64"
  "llama-server-linux-aarch64:Linux ARM64"
)

echo "=================================================="
echo "  Termex v0.11.0 - llama-server 二进制下载工具"
echo "=================================================="
echo ""
echo "Release: $RELEASE_TAG (Latest Stable)"
echo "目标目录: $BIN_DIR"
echo ""

# 创建目录
mkdir -p "$BIN_DIR"

# 下载函数
download_binary() {
  local filename=$1
  local description=$2
  local url="$BASE_URL/$filename"

  echo -n "下载 $description ($filename)... "

  if curl -L -f -o "$BIN_DIR/$filename" "$url" 2>/dev/null; then
    # 设置执行权限（非 Windows）
    if [[ ! "$filename" == *.exe ]]; then
      chmod +x "$BIN_DIR/$filename"
    fi
    size=$(du -h "$BIN_DIR/$filename" | awk '{print $1}')
    echo "✓ ($size)"
  else
    echo "✗ 下载失败"
    return 1
  fi
}

# 下载所有二进制
failed=0
for item in "${BINARIES[@]}"; do
  IFS=':' read -r binary description <<< "$item"
  if ! download_binary "$binary" "$description"; then
    ((failed++))
  fi
done

echo ""
echo "=================================================="

if [ $failed -eq 0 ]; then
  echo "✓ 所有文件下载成功！"
  echo ""
  echo "已安装的二进制："
  ls -lh "$BIN_DIR/" | tail -n +2
  echo ""
  echo "下一步："
  echo "  1. 运行: pnpm tauri dev"
  echo "  2. 在应用中下载模型"
  echo "  3. 使用本地 AI 功能"
else
  echo "✗ 有 $failed 个文件下载失败"
  echo ""
  echo "可能的原因："
  echo "  - 网络连接问题"
  echo "  - GitHub 访问限制"
  echo ""
  echo "解决方案："
  echo "  1. 检查网络连接"
  echo "  2. 使用 VPN（如在国内）"
  echo "  3. 或从浏览器手动下载："
  echo "     $BASE_URL"
  echo "     然后放入 $BIN_DIR/ 目录"
  exit 1
fi

echo "=================================================="
