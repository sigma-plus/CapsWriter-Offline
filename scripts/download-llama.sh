#!/usr/bin/env bash
# 单独下载 llama.cpp 源码（使用 zip 方式，避免 git clone 网络问题）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/offline-packages"
LLAMA_DIR="$OUT/llama.cpp-src"
LLAMA_TAG="b7798"

if [ -d "$LLAMA_DIR" ]; then
    echo "llama.cpp 源码已存在，跳过"
    exit 0
fi

echo "===== 下载 llama.cpp 源码 (tag: $LLAMA_TAG) ====="

TMP_ZIP="$OUT/llama.cpp-b7798.zip"

# 尝试多个源
URLS=(
    "https://github.com/ggml-org/llama.cpp/archive/refs/tags/b7798.tar.gz"
    "https://ghfast.top/https://github.com/ggml-org/llama.cpp/archive/refs/tags/b7798.tar.gz"
    "https://ghproxy.net/https://github.com/ggml-org/llama.cpp/archive/refs/tags/b7798.tar.gz"
)

DOWNLOADED=0
for URL in "${URLS[@]}"; do
    echo "  尝试: $URL"
    if curl -LfS --connect-timeout 15 --max-time 300 -o "$TMP_ZIP" "$URL"; then
        DOWNLOADED=1
        echo "  下载成功"
        break
    fi
    echo "  失败，尝试下一个源..."
    rm -f "$TMP_ZIP"
done

if [ "$DOWNLOADED" -eq 0 ]; then
    echo "ERROR: 所有源均下载失败，请手动下载 llama.cpp tag b7798"
    exit 1
fi

# 解压
mkdir -p "$LLAMA_DIR"
tar -xzf "$TMP_ZIP" -C "$OUT"
mv "$OUT/llama.cpp-b7798" "$LLAMA_DIR"
rm -f "$TMP_ZIP"

echo "  llama.cpp 源码: $(du -sh "$LLAMA_DIR" | cut -f1)"
echo "===== 下载完成 ====="
