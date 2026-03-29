#!/bin/bash
set -e

BASE_URL="https://github.com/ggerganov/llama.cpp/releases/download/b8575"
BINARIES=(
  "llama-server-macos-arm64"
  "llama-server-macos-x64"
  "llama-server-windows-x64.exe"
  "llama-server-linux-x64"
  "llama-server-linux-aarch64"
)

for binary in "${BINARIES[@]}"; do
  echo "下载 $binary..."
  curl -L -o "$binary" "$BASE_URL/$binary" 2>/dev/null &
  sleep 1  # 错开请求
done

wait
echo "所有下载完成"
ls -lh llama-server-*
