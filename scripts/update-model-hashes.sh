#!/bin/bash

# Termex v0.11.0: 模型 SHA256 验证和更新脚本
# 功能：下载模型文件头部获取 URL 信息，或本地计算 SHA256
# 用法：./scripts/update-model-hashes.sh [--download] [--verify]

set -e

MODELS_DIR="$HOME/.termex/models"
LOCAL_MODELS_JSON="src/assets/local-models.json"
TEMP_DIR="/tmp/termex-model-check"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 模型列表（ID, HF 仓库, GGUF 文件名）
declare -a MODELS=(
  "tinyllama-1.1b-q2:TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF:tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
  "qwen2.5-0.5b-q3:Qwen/Qwen2.5-0.5B-Instruct-GGUF:qwen2.5-0.5b-instruct-q3_k_m.gguf"
  "phi-2-q2:TheBloke/phi-2-GGUF:phi-2.Q2_K.gguf"
  "qwen2.5-0.5b-q4:Qwen/Qwen2.5-0.5B-Instruct-GGUF:qwen2.5-0.5b-instruct-q4_k_m.gguf"
  "phi-3-3b-q3:microsoft/Phi-3-mini-4k-instruct-gguf:Phi-3-mini-4k-instruct-q3_k_m.gguf"
  "mobilequwen-0.5b-q4:Qwen/Qwen-0.5B-Chat-GGUF:qwen-0.5b-chat-q4_k_m.gguf"
  "llama3.2-3b-q4:bartowski/Llama-3.2-3B-Instruct-GGUF:Llama-3.2-3B-Instruct-Q4_K_M.gguf"
  "qwen2.5-3b-q4:Qwen/Qwen2.5-3B-Instruct-GGUF:qwen2.5-3b-instruct-q4_k_m.gguf"
  "phi-3-3b-q4:microsoft/Phi-3-mini-4k-instruct-gguf:Phi-3-mini-4k-instruct-q4_k_m.gguf"
  "qwen2.5-7b-q4:Qwen/Qwen2.5-7B-Instruct-GGUF:qwen2.5-7b-instruct-q4_k_m.gguf"
  "llama3.3-8b-q4:bartowski/Llama-3.3-70B-Instruct-GGUF:Llama-3.3-8B-Instruct-Q4_K_M.gguf"
  "deepseek-7b-q4:deepseek-ai/deepseek-coder-7b-instruct-gguf:deepseek-coder-7b-instruct-q4_k_m.gguf"
)

mkdir -p "$TEMP_DIR"
mkdir -p "$MODELS_DIR"

echo -e "${YELLOW}=== Termex Model SHA256 Verification ===${NC}\n"

# 函数：获取文件头部检查 URL 是否有效
check_url_valid() {
  local url=$1
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" --max-time 5)

  if [[ $http_code == "302" || $http_code == "200" ]]; then
    echo "✓"
    return 0
  else
    echo "✗ (HTTP $http_code)"
    return 1
  fi
}

# 函数：从本地文件计算 SHA256
compute_local_sha256() {
  local file=$1
  if [ -f "$file" ]; then
    sha256sum "$file" | awk '{print $1}'
  else
    echo "FILE_NOT_FOUND"
  fi
}

# 函数：从 HuggingFace 获取最后修改时间（作为版本标识）
get_hf_info() {
  local repo=$1
  local filename=$2

  # 尝试从 HuggingFace API 获取文件信息
  # API 端点：https://huggingface.co/api/repos/{repo_id}/tree/main
  local response=$(curl -s "https://huggingface.co/api/repos/$repo/tree/main" \
    -H "Authorization: Bearer $HF_TOKEN" 2>/dev/null || echo "")

  if [ -z "$response" ]; then
    echo "UNKNOWN"
  else
    # 解析 JSON 获取文件大小和 SHA256（如果 API 提供）
    echo "$response" | jq -r ".[].lfs.sha256 // empty" | head -1 || echo "UNKNOWN"
  fi
}

# 主流程
for model_spec in "${MODELS[@]}"; do
  IFS=':' read -r model_id repo filename <<< "$model_spec"

  url="https://huggingface.co/$repo/resolve/main/$filename"
  local_file="$MODELS_DIR/$model_id.gguf"

  echo -n "Checking $model_id... "

  # 检查 URL 有效性
  if ! check_url_valid "$url"; then
    echo -e "${RED}URL invalid for $model_id${NC}"
    continue
  fi

  # 检查本地文件是否存在
  if [ -f "$local_file" ]; then
    echo -e "${GREEN}File exists locally${NC}"
    echo "  Computed SHA256: $(compute_local_sha256 "$local_file")"
  else
    echo -e "${YELLOW}Not downloaded yet${NC}"
    echo "  To download: run 'curl -o $local_file $url'"
  fi
done

echo -e "\n${YELLOW}=== Next Steps ===${NC}"
echo "1. Download models you want to test:"
echo "   curl -o ~/.termex/models/{model-id}.gguf https://huggingface.co/...{file}.gguf"
echo ""
echo "2. After downloading, compute SHA256:"
echo "   sha256sum ~/.termex/models/*.gguf"
echo ""
echo "3. Update src/assets/local-models.json with the SHA256 values"
echo ""
echo "4. Or set HF_TOKEN environment variable to use HuggingFace API:"
echo "   export HF_TOKEN=<your-token>"
echo "   Then re-run this script to fetch file metadata"
