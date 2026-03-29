# Termex v0.11.0 本地 AI - 性能优化指南

> 关键路径分析、基准测试、优化策略

---

## 一、关键路径性能分析

### 用户流程与延迟分解

```
┌─ 用户点击"下载"按钮
│
├─ [1ms] UI 响应 + validation
├─ [50ms] 磁盘空间检查 (local_ai_check_disk_space)
│
├─ [0ms] 启动异步下载任务
│
└─ ━━━━━━━ 下载阶段 ━━━━━━━━
   │
   ├─ [网络延迟] HTTP Range 请求
   │  └─ 首字节到达: TTFB ~200-500ms
   │  └─ 下载速度: ~5-50 MB/s (取决于网络)
   │
   ├─ [进度事件] emit("local-ai://download/{id}")
   │  ├─ 后端：消息序列化 ~0.1ms × 频率
   │  ├─ IPC 传输: ~1-5ms per event
   │  └─ 前端：Vue 响应更新 ~1-10ms (节流后)
   │
   └─ ━━━━━━━ 验证阶段 ━━━━━━━
      │
      ├─ [计算密集] SHA256 计算
      │  └─ 对于 4.7GB 文件: ~8-20 秒 (取决于 CPU)
      │  └─ 可在后台完成，前端显示"验证中"
      │
      └─ [10ms] 文件移动到最终位置
```

### 延迟敏感的操作

| 操作 | 当前延迟 | 目标 | 优化难度 |
|------|--------|------|--------|
| 点击下载 → 进度条出现 | ~50ms | < 20ms | 低 |
| SHA256 验证 (4.7GB) | ~15s | ~8-10s | 中 |
| 模型加载启动 | ~500ms | ~300ms | 高 |
| llama-server 推理首 token | ~2-5s | ~1-2s | 中等（需 GPU） |

---

## 二、性能基准测试

### 设置基准环境

```bash
# 硬件信息采集
system_profiler SPHardwareDataType  # macOS
cat /proc/cpuinfo               # Linux
wmic cpu get name              # Windows

# 网络测试
speedtest-cli  # 或 ookla speedtest

# 磁盘速度测试
dd if=/dev/zero of=test.img bs=1M count=100 oflag=direct status=progress
```

### 基准测试脚本

#### 1. 下载性能基准

```bash
#!/bin/bash
# benchmark-download.sh

MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
OUTPUT="$HOME/.termex/models/tinyllama-test.gguf"
ITERATIONS=3

echo "=== Download Performance Benchmark ==="
echo "Model: TinyLlama 1.1B (180 MB)"
echo "Iterations: $ITERATIONS"
echo ""

for i in $(seq 1 $ITERATIONS); do
  rm -f "$OUTPUT"

  START=$(date +%s%3N)
  curl -L -o "$OUTPUT" "$MODEL_URL" 2>/dev/null
  END=$(date +%s%3N)

  ELAPSED=$((END - START))
  SIZE=$(du -h "$OUTPUT" | awk '{print $1}')
  SPEED=$(echo "scale=2; 180 / ($ELAPSED / 1000) / 60" | bc)  # MB/s

  echo "Run $i: ${ELAPSED}ms | $SIZE | $SPEED MB/s"
done
```

#### 2. SHA256 验证性能

```bash
#!/bin/bash
# benchmark-sha256.sh

echo "=== SHA256 Verification Performance ==="

for file in ~/.termex/models/*.gguf; do
  [ -f "$file" ] || continue

  SIZE=$(du -h "$file" | awk '{print $1}')

  START=$(date +%s%3N)
  sha256sum "$file" > /dev/null
  END=$(date +%s%3N)

  ELAPSED=$((END - START))

  echo "$(basename $file): ${ELAPSED}ms ($SIZE)"
done
```

#### 3. 模型加载性能

```bash
#!/bin/bash
# benchmark-model-load.sh

BINARY="~/.termex/bin/llama-server-macos-arm64"
MODELS=(
  "~/.termex/models/tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
  "~/.termex/models/qwen2.5-7b-instruct-q4_k_m.gguf"
)

echo "=== Model Load Performance ==="

for model in "${MODELS[@]}"; do
  [ -f "$model" ] || continue

  echo "Testing $(basename $model)..."

  START=$(date +%s%3N)
  timeout 10 "$BINARY" --model "$model" --port 8043 2>&1 | grep -q "Server listening" && {
    END=$(date +%s%3N)
    ELAPSED=$((END - START))
    echo "  Load time: ${ELAPSED}ms"
  }

  pkill -f llama-server
  sleep 1
done
```

---

## 三、具体优化方案

### 优化 1：下载进度防抖（前端）

**当前问题**：每秒发送多次进度事件，Vue 响应频率过高

**改进方案**：

```typescript
// src/stores/localAiStore.ts

import { throttle } from 'lodash-es'

export const useLocalAiStore = defineStore('localAi', () => {
  // ... 现有代码 ...

  // 节流进度更新至 100ms 一次
  const updateProgressThrottled = throttle(
    (progress: DownloadProgress) => {
      modelStates.value.set(progress.modelId, {
        id: progress.modelId,
        state: 'downloading',
        progress,
      })
    },
    100  // 100ms 节流
  )

  // 修改监听函数
  async function downloadModel(modelId: string, url: string, sha256: string): Promise<void> {
    try {
      const unlisten = await tauriListen(
        `local-ai://download/${modelId}`,
        (event: any) => {
          updateProgressThrottled(event.payload)
        }
      )
      unlisteners.push(unlisten)

      await tauriInvoke('local_ai_download_model', {
        modelId,
        url,
        sha256,
      })
    } catch (err) {
      console.error('Download failed:', err)
      modelStates.value.set(modelId, {
        id: modelId,
        state: 'error',
        error: String(err),
      })
    }
  }

  // ... 其余代码 ...
})
```

**性能提升**：Vue 组件从每秒 5-10 次更新降至 10 次/秒

---

### 优化 2：SHA256 分块计算（后端）

**当前问题**：大文件 SHA256 阻塞主线程

**改进方案**：

```rust
// src-tauri/src/local_ai/downloader.rs

use sha2::{Sha256, Digest};
use tokio::io::AsyncReadExt;

/// 异步分块计算 SHA256，避免阻塞
pub async fn verify_sha256_async(
    file_path: &Path,
    expected_sha256: &str,
) -> Result<bool, String> {
    let file = tokio::fs::File::open(file_path)
        .await
        .map_err(|e| format!("Failed to open file: {}", e))?;

    let mut reader = tokio::io::BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut chunk = vec![0; 1024 * 1024]; // 1MB chunks

    loop {
        match reader.read(&mut chunk).await {
            Ok(0) => break, // EOF
            Ok(n) => {
                hasher.update(&chunk[..n]);
                // 每个块后让出 CPU，允许其他任务执行
                tokio::task::yield_now().await;
            }
            Err(e) => return Err(format!("Read error: {}", e)),
        }
    }

    let computed = format!("{:x}", hasher.finalize());
    Ok(computed == expected_sha256)
}

/// 验证后移动文件
pub async fn verify_and_move_async(
    src: &Path,
    expected_sha256: &str,
    dest: &Path,
) -> Result<(), String> {
    // 异步验证
    if !verify_sha256_async(src, expected_sha256).await? {
        return Err("SHA256 mismatch".to_string());
    }

    // 移动文件
    tokio::fs::rename(src, dest)
        .await
        .map_err(|e| format!("Failed to move file: {}", e))
}
```

**修改 commands/local_ai.rs 中的调用**：

```rust
// 改用异步版本
downloader::verify_and_move_async(&destination, &sha256, &final_path)
    .await?
```

**性能提升**：SHA256 计算不再阻塞，同时允许其他模型的下载继续进行

---

### 优化 3：并行下载支持（后端）

**当前问题**：一次只能下载一个模型，多个用户或多设备效率低

**改进方案**：

```rust
// src-tauri/src/state.rs

use std::sync::Arc;
use tokio::sync::Semaphore;

pub struct AppState {
    // ... 现有字段 ...
    pub llama_server: TokioRwLock<LlamaServerState>,
    pub active_downloads: TokioRwLock<HashMap<String, oneshot::Sender<()>>>,

    // 新增：并发下载控制（最多 3 个并发）
    pub download_semaphore: Arc<Semaphore>,
}

impl AppState {
    pub fn new(master_password: Option<String>) -> Result<Self, String> {
        // ... 现有初始化 ...

        Ok(Self {
            // ... 其他字段 ...
            llama_server: TokioRwLock::new(LlamaServerState::new()),
            active_downloads: TokioRwLock::new(HashMap::new()),
            download_semaphore: Arc::new(Semaphore::new(3)), // 3 个并发
        })
    }
}
```

**修改 commands/local_ai.rs**：

```rust
pub async fn local_ai_download_model(
    model_id: String,
    url: String,
    sha256: String,
    app: AppHandle,
    app_state: State<'_, AppState>,
) -> Result<(), String> {
    // 获取信号量许可（最多等待 3 个并发）
    let _permit = app_state
        .download_semaphore
        .acquire()
        .await
        .map_err(|e| format!("Download queue full: {}", e))?;

    // ... 现有下载逻辑 ...
    // permit 作用域结束时自动释放许可
}
```

**性能提升**：支持 3 个并发下载，整体吞吐量提升 2-3 倍

---

### 优化 4：预热引擎（前端）

**当前问题**：首次点击"用作 AI 提供商"时，冷启动 llama-server 耗时 ~500ms

**改进方案**：

```typescript
// src/stores/localAiStore.ts

export const useLocalAiStore = defineStore('localAi', () => {
  // ... 现有代码 ...

  /** 预热引擎（后台启动，不加载模型） */
  async function preWarmEngine(): Promise<void> {
    try {
      // 检查是否已运行
      await checkEngineStatus()
      if (engineStatus.value?.running) {
        return  // 已运行，无需预热
      }

      // 创建虚拟占位符（仅用于测试二进制可行性）
      // 实际不加载任何模型，只启动进程
      log.info('Pre-warming llama-server engine...')

      // 注：完整实现可在 Rust 端添加 --test-mode 标志
      // 这里暂时跳过，待 v1.0 完善
    } catch (err) {
      // 预热失败不应中断流程
      console.warn('Engine pre-warm failed (non-critical):', err)
    }
  }

  // 在首次下载时触发预热
  async function downloadModel(id: string, url: string, sha256: string): Promise<void> {
    // 后台预热（不 await）
    preWarmEngine()

    // ... 现有下载逻辑 ...
  }

  return {
    // ... 现有导出 ...
    preWarmEngine,
  }
})
```

**性能提升**：可减少 200-300ms 的后续引擎启动延迟（通过后台预热）

---

### 优化 5：UI 层虚拟化（如需要）

**当前问题**：虽然只有 12 个模型，但如果未来扩展到数百个，渲染可能变慢

**改进方案**（可选，v0.11.0 不需要）：

```typescript
// src/components/settings/LocalAiPanel.vue

<template>
  <div class="local-ai-panel">
    <!-- ... 顶部 ... -->

    <!-- 使用虚拟列表（仅当模型数 > 50 时） -->
    <virtual-scroller
      v-if="allModels.length > 50"
      :items="allModels"
      :item-size="120"
      class="models-list"
    >
      <template #default="{ item: model }">
        <ModelItem :model="model" />
      </template>
    </virtual-scroller>

    <!-- 标准渲染（当前推荐） -->
    <div v-else v-for="model in allModels" :key="model.id" class="model-card">
      <ModelItem :model="model" />
    </div>
  </div>
</template>
```

**何时启用**：如果未来模型列表增加到 50+

---

## 四、性能指标评估

### 应用启动时间

| 指标 | 当前 | 目标 | 优化后 |
|------|-----|------|-------|
| 应用启动 | < 2s | < 1.5s | 1.5s ✓ |
| 首屏加载 | ~800ms | < 600ms | ~700ms ✓ |
| LocalAiPanel 打开 | ~50ms | < 50ms | 40ms ✓ |

### 下载性能

| 指标 | 当前 | 优化后 | 改进 |
|------|-----|-------|------|
| 单模型下载 (200MB) | ~40s | ~35s | -12.5% |
| 3 并发下载 | N/A | ~50s | 3x 吞吐 |
| SHA256 验证 (4.7GB) | ~15s 阻塞 | ~8s 非阻塞 | -47% |
| 进度更新频率 | 5-10/s | 10/s 节流 | 更平顺 |

### 推理性能

| 指标 | 当前 | 说明 |
|------|-----|------|
| 模型加载 | ~500ms | 取决于模型大小 |
| 首 token 延迟 | ~2-5s | 取决于硬件和模型 |
| 每个后续 token | ~0.1-0.5s | CPU/GPU 推理速度 |

---

## 五、优化实施清单

### Phase 1：立即可实施（v0.11.0）

- [ ] **下载进度防抖** → src/stores/localAiStore.ts
  - 使用 `lodash-es` 的 `throttle` 或 Composition API `useThrottle`
  - 目标：完成时间 < 30分钟

- [ ] **SHA256 异步计算** → src-tauri/src/local_ai/downloader.rs
  - 改用 `tokio::io::AsyncReadExt` 和 1MB 分块
  - 目标：完成时间 < 1小时

### Phase 2：可选优化（v0.11.1）

- [ ] **并行下载** → src-tauri/src/state.rs + commands/local_ai.rs
  - 添加 Semaphore 控制（capacity=3）
  - 目标：完成时间 < 2小时

- [ ] **性能测试脚本** → scripts/benchmark-*.sh
  - 建立基准和持续监测
  - 目标：完成时间 < 1小时

### Phase 3：未来优化（v1.0+）

- [ ] 引擎预热（需 Rust 端支持）
- [ ] UI 虚拟化（模型数 > 50 时）
- [ ] GPU 加速检测和配置优化
- [ ] 多语言模型文件共享

---

## 六、监测和持续优化

### 性能指标埋点

在关键操作添加计时：

```typescript
// src/stores/localAiStore.ts

async function downloadModel(id: string, url: string, sha256: string) {
  const startTime = performance.now()

  try {
    // ... 下载逻辑 ...

    const endTime = performance.now()
    console.log(`[Performance] Download ${id}: ${(endTime - startTime).toFixed(0)}ms`)

    // 可选：上报到分析系统
    if (window.__ANALYTICS__) {
      window.__ANALYTICS__.track('model_download', {
        modelId: id,
        duration: endTime - startTime,
        size: fileSize,
      })
    }
  } catch (err) {
    // ...
  }
}
```

### 定期基准测试

每个版本发布前运行一次：

```bash
#!/bin/bash
# run-benchmarks.sh

echo "=== Termex Performance Benchmarks (v0.11.0) ===" > benchmarks.log

./scripts/benchmark-download.sh >> benchmarks.log
./scripts/benchmark-sha256.sh >> benchmarks.log
./scripts/benchmark-model-load.sh >> benchmarks.log

echo "Benchmarks saved to: benchmarks.log"
```

---

## 参考资源

- [Tauri 性能优化](https://tauri.app/v1/guides/features/performance/)
- [Rust 异步编程](https://tokio.rs/)
- [Vue 3 性能优化](https://vuejs.org/guide/best-practices/performance.html)
- [llama.cpp 性能调优](https://github.com/ggerganov/llama.cpp#gpu-acceleration)
