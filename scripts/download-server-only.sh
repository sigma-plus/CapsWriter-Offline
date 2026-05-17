#!/usr/bin/env bash
# 服务端离线依赖下载脚本（仅 x86_64 CUDA）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/offline-packages"
PY_VER="312"

echo "===== 下载 CapsWriter-Offline 服务端 x86_64 CUDA 依赖 ====="

# 服务端 x86_64 (CUDA)
echo ""
echo "[1/3] 下载服务端 x86_64 依赖 — 平台相关包 (CUDA)..."
mkdir -p "$OUT/server-x86_64"

pip3 download \
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

echo "  补充下载纯 Python 包..."
pip3 download \
    --only-binary=:all: \
    -r "$ROOT/requirements-server-linux-cuda.txt" \
    -d "$OUT/server-x86_64/" \
    2>&1 | tail -5 || true

echo "  服务端包数量: $(ls "$OUT/server-x86_64/" | wc -l)"

# llama.cpp 源码
echo ""
echo "[2/3] 下载 llama.cpp 源码..."
LLAMA_DIR="$OUT/llama.cpp-src"
if [ -d "$LLAMA_DIR" ]; then
    echo "  已存在，跳过 (如需更新请删除 $LLAMA_DIR)"
else
    git clone --depth 1 --branch b7798 \
        https://github.com/ggml-org/llama.cpp.git \
        "$LLAMA_DIR"
fi

echo ""
echo "[3/3] 汇总"
echo "===== 下载完成 ====="
echo "服务端 x86_64:  $(du -sh "$OUT/server-x86_64" | cut -f1)  $(ls "$OUT/server-x86_64/" | wc -l) 个包"
echo "llama.cpp 源码: $(du -sh "$LLAMA_DIR" | cut -f1)"
echo ""
echo "输出目录: $OUT"
