#!/usr/bin/env bash
# 离线依赖下载脚本
# 运行环境：能上网的 Linux (x86_64) 或 macOS
# 用法：bash scripts/download-wheels.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/offline-packages"

PY_VER="312"

echo "===== 下载 CapsWriter-Offline 离线依赖包 ====="

# --------------------------------------------------
# 1. 服务端 x86_64 (CUDA)
# --------------------------------------------------
echo ""
echo "[1/4] 下载服务端 x86_64 依赖 — 平台相关包 (CUDA)..."
mkdir -p "$OUT/server-x86_64"

# 1a: 带 --platform 下载平台相关 wheel
pip download \
    --platform manylinux_2_17_x86_64 \
    --platform manylinux_2_28_x86_64 \
    --platform manylinux2014_x86_64 \
    --python-version "$PY_VER" \
    --implementation cp \
    --abi cp312 \
    --only-binary=:all: \
    -r "$ROOT/requirements-server-linux-cuda.txt" \
    -d "$OUT/server-x86_64/" \
    2>&1 | tail -5 || true

# 1b: 不带 --platform 补下纯 Python 包（已存在的会自动跳过）
echo "  补充下载纯 Python 包..."
pip download \
    --only-binary=:all: \
    -r "$ROOT/requirements-server-linux-cuda.txt" \
    -d "$OUT/server-x86_64/" \
    2>&1 | tail -5 || true

echo "  服务端包数量: $(ls "$OUT/server-x86_64/" | wc -l)"

# --------------------------------------------------
# 2. 客户端 aarch64 (ARM64)
# --------------------------------------------------
echo ""
echo "[2/4] 下载客户端 aarch64 依赖 — 平台相关包 (ARM64)..."
mkdir -p "$OUT/client-aarch64"

# 2a: 带 --platform 下载 aarch64 平台相关 wheel
pip download \
    --platform manylinux2014_aarch64 \
    --platform manylinux_2_17_aarch64 \
    --platform manylinux_2_28_aarch64 \
    --python-version "$PY_VER" \
    --implementation cp \
    --abi cp312 \
    --only-binary=:all: \
    -r "$ROOT/requirements-client-linux-arm64.txt" \
    -d "$OUT/client-aarch64/" \
    2>&1 | tail -5 || true

# 2b: 不带 --platform 补下纯 Python 包（py3-none-any 兼容所有平台）
echo "  补充下载纯 Python 包..."
pip download \
    --only-binary=:all: \
    -r "$ROOT/requirements-client-linux-arm64.txt" \
    -d "$OUT/client-aarch64/" \
    2>&1 | tail -5 || true

echo "  客户端包数量: $(ls "$OUT/client-aarch64/" | wc -l)"

# --------------------------------------------------
# 3. llama.cpp 源码
# --------------------------------------------------
echo ""
echo "[3/4] 下载 llama.cpp 源码..."
LLAMA_DIR="$OUT/llama.cpp-src"
if [ -d "$LLAMA_DIR" ]; then
    echo "  已存在，跳过 (如需更新请删除 $LLAMA_DIR)"
else
    git clone --depth 1 --branch b7798 \
        https://github.com/ggml-org/llama.cpp.git \
        "$LLAMA_DIR"
fi

# --------------------------------------------------
# 汇总
# --------------------------------------------------
echo ""
echo "===== 下载完成 ====="
echo "服务端 x86_64:  $(du -sh "$OUT/server-x86_64" | cut -f1)  $(ls "$OUT/server-x86_64/" | wc -l) 个包"
echo "客户端 aarch64: $(du -sh "$OUT/client-aarch64" | cut -f1)  $(ls "$OUT/client-aarch64/" | wc -l) 个包"
echo "llama.cpp 源码: $(du -sh "$LLAMA_DIR" | cut -f1)"
echo ""
echo "输出目录: $OUT"
