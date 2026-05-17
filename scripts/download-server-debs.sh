#!/usr/bin/env bash
# 下载服务端运行时 + 编译所需的系统 deb 包（离线安装用）
# 在云服务器上运行，产物会放入 offline-packages/server-debs/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEB_DIR="$ROOT/offline-packages/server-debs"
mkdir -p "$DEB_DIR"

echo "===== 下载服务端系统依赖 deb 包 ====="

# -- print-uris 只打印 URL，不实际安装
# 提取 URL 并用 curl 下载
apt-get --print-uris --yes install --reinstall \
    python3.12 \
    python3.12-minimal \
    python3.12-venv \
    python3.12-dev \
    libpython3.12t64 \
    libpython3.12-stdlib \
    libpython3.12-minimal \
    python3-pip \
    python3-venv \
    libsndfile1 \
    cmake \
    make \
    2>/dev/null \
    | grep -oP "'http://[^']+'" \
    | tr -d "'" \
    | while read -r url; do
        fname=$(basename "$url")
        if [ -f "$DEB_DIR/$fname" ]; then
            echo "  已存在: $fname"
        else
            echo "  下载: $fname"
            curl -LfS -o "$DEB_DIR/$fname" "$url"
        fi
    done

echo ""
echo "  deb 包数量: $(ls "$DEB_DIR/"*.deb 2>/dev/null | wc -l)"
echo "  deb 包大小: $(du -sh "$DEB_DIR" | cut -f1)"
echo "===== 下载完成 ====="
