#!/usr/bin/env bash
# CapsWriter-Offline 服务端离线部署脚本
# 在目标服务器上运行（air-gapped，无需网络）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== CapsWriter-Offline 服务端部署 ====="

# 1. 安装系统 deb 包（如已安装会自动跳过）
DEB_DIR="$SCRIPT_DIR/server-debs"
if [ -d "$DEB_DIR" ] && ls "$DEB_DIR"/*.deb 1>/dev/null 2>&1; then
    echo ""
    echo "[1/4] 安装系统依赖 deb 包..."
    sudo dpkg -i "$DEB_DIR"/*.deb 2>/dev/null || true
    sudo apt-get install -f -y 2>/dev/null || true
    echo "  完成"
else
    echo "[1/4] 未找到 server-debs/ 目录，跳过系统包安装"
fi

# 2. 安装 Python 依赖
echo ""
echo "[2/4] 安装 Python 依赖（离线）..."
pip3 install --no-index --find-links="$SCRIPT_DIR" \
    -r "$SCRIPT_DIR/requirements-server-linux-cuda.txt"
echo "  完成"

# 3. 编译 llama.cpp
echo ""
echo "[3/4] 编译 llama.cpp..."
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
if [ -f "$LLAMA_DIR/build/bin/llama-server" ]; then
    echo "  已编译，跳过"
else
    cd "$LLAMA_DIR"
    mkdir -p build && cd build
    cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
    make -j$(nproc)
    echo "  编译完成"
fi

# 4. 安装 systemd 服务（可选）
echo ""
echo "[4/4] 安装 systemd 服务（可选）..."
SERVICE_FILE="/etc/systemd/system/capsriter-server.service"
if [ -f "$SCRIPT_DIR/capsriter-server.service" ]; then
    sudo cp "$SCRIPT_DIR/capsriter-server.service" "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable capsriter-server
    echo "  服务已安装并启用开机自启"
    echo ""
    echo "  启动服务:  sudo systemctl start capsriter-server"
    echo "  查看状态:  sudo systemctl status capsriter-server"
    echo "  查看日志:  journalctl -u capsriter-server -f"
else
    echo "  未找到 capsriter-server.service，跳过"
fi

echo ""
echo "===== 部署完成 ====="
echo "请确认 config_server.py 中 onnx_provider = 'CUDA'，然后启动服务"
