#!/usr/bin/env bash
# 离线依赖下载脚本
# 运行环境：能上网的 Linux (x86_64)
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
echo "[1/3] 下载服务端 x86_64 依赖 (CUDA)..."
mkdir -p "$OUT/server-x86_64"

pip download \
    --platform manylinux_2_17_x86_64 \
    --python-version "$PY_VER" \
    --only-binary=:all: \
    -r "$ROOT/requirements-server-linux-cuda.txt" \
    -d "$OUT/server-x86_64/" \
    2>&1 | tail -5

echo "  服务端包数量: $(ls "$OUT/server-x86_64/" | wc -l)"

# --------------------------------------------------
# 2. 客户端 aarch64 (ARM64)
# --------------------------------------------------
echo ""
echo "[2/3] 下载客户端 aarch64 依赖 (ARM64)..."
mkdir -p "$OUT/client-aarch64"

pip download \
    --platform manylinux2014_aarch64 \
    --python-version "$PY_VER" \
    --only-binary=:all: \
    -r "$ROOT/requirements-client-linux-arm64.txt" \
    -d "$OUT/client-aarch64/" \
    2>&1 | tail -5

echo "  客户端包数量: $(ls "$OUT/client-aarch64/" | wc -l)"

# --------------------------------------------------
# 3. llama.cpp 源码
# --------------------------------------------------
echo ""
echo "[3/3] 下载 llama.cpp 源码..."
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
