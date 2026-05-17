#!/usr/bin/env bash
# 服务端完整离线包打包脚本（含 deb + wheel + llama.cpp + systemd 服务）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OFFLINE="$ROOT/offline-packages"
DIST="$ROOT/offline-release"

mkdir -p "$DIST"

# 预检查
for d in "$OFFLINE/server-x86_64" "$OFFLINE/llama.cpp-src"; do
    if [ ! -d "$d" ]; then
        echo "ERROR: 未找到 $d，请先运行下载脚本"
        exit 1
    fi
done

echo "===== 打包服务端完整离线安装包 ====="
SERVER_DIR="$DIST/server-offline"
rm -rf "$SERVER_DIR"
mkdir -p "$SERVER_DIR"

# Python wheels
cp "$OFFLINE/server-x86_64/"*.whl "$SERVER_DIR/"
echo "  wheel 包: $(ls "$SERVER_DIR/"*.whl | wc -l) 个"

# llama.cpp 源码
cp -r "$OFFLINE/llama.cpp-src" "$SERVER_DIR/llama.cpp"
echo "  llama.cpp: $(du -sh "$SERVER_DIR/llama.cpp" | cut -f1)"

# 系统 deb 包
if [ -d "$OFFLINE/server-debs" ] && ls "$OFFLINE/server-debs/"*.deb 1>/dev/null 2>&1; then
    cp -r "$OFFLINE/server-debs" "$SERVER_DIR/server-debs"
    echo "  deb 包: $(ls "$SERVER_DIR/server-debs/"*.deb | wc -l) 个"
fi

# 配置文件
cp "$ROOT/requirements-server-linux-cuda.txt" "$SERVER_DIR/"

# systemd 服务文件
cp "$ROOT/scripts/capswriter-server.service" "$SERVER_DIR/"

# 部署脚本
cp "$ROOT/scripts/deploy-server.sh" "$SERVER_DIR/"
chmod +x "$SERVER_DIR/deploy-server.sh"

# 打包
cd "$DIST"
tar -czf server-offline.tar.gz server-offline/
echo ""
echo "  产物大小: $(du -sh server-offline.tar.gz | cut -f1)"
echo "===== 打包完成 ====="
ls -lh "$DIST"/*.tar.gz
