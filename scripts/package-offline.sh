#!/usr/bin/env bash
# 离线安装包打包脚本
# 运行环境：云服务器（download-wheels.sh 执行完成后）
# 输出：server-offline.tar.gz + client-offline.tar.gz

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OFFLINE="$ROOT/offline-packages"
DIST="$ROOT/offline-release"

mkdir -p "$DIST"

# 预检查：确认下载已完成
if [ ! -d "$OFFLINE" ]; then
    echo "ERROR: 未找到 offline-packages 目录。请先运行 download-wheels.sh"
    exit 1
fi

# --------------------------------------------------
# 服务端离线包
# --------------------------------------------------
echo "===== 打包服务端离线安装包 ====="
SERVER_DIR="$DIST/server-offline"
rm -rf "$SERVER_DIR"
mkdir -p "$SERVER_DIR"

# Python wheels
if [ -d "$OFFLINE/server-x86_64" ] && ls "$OFFLINE/server-x86_64/"*.whl 1>/dev/null 2>&1; then
    cp "$OFFLINE/server-x86_64/"*.whl "$SERVER_DIR/"
else
    echo "WARNING: 未找到服务端 wheel 包，请确认 download-wheels.sh 已成功执行"
fi

# llama.cpp 源码
cp -r "$OFFLINE/llama.cpp-src" "$SERVER_DIR/llama.cpp"

# 依赖文件
cp "$ROOT/requirements-server-linux-cuda.txt" "$SERVER_DIR/"

# 安装脚本
cat > "$SERVER_DIR/install.sh" << 'INSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== 安装 CapsWriter-Offline 服务端依赖 ====="

# 1. 安装 Python 包
pip install --no-index --find-links="$SCRIPT_DIR" \
    -r "$SCRIPT_DIR/requirements-server-linux-cuda.txt"

# 2. 编译 llama.cpp (需要 cmake, gcc, CUDA toolkit)
echo ""
echo "===== 编译 llama.cpp ====="
cd "$SCRIPT_DIR/llama.cpp"
mkdir -p build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

echo ""
echo "===== 编译完成 ====="
echo "请将编译产物 (libllama.so, libggml.so 等) 复制到 CapsWriter-Offline 的 util/llama/bin/ 目录"
echo "或参考 build-linux.sh 配置路径"
INSTALL_EOF
chmod +x "$SERVER_DIR/install.sh"

# 打包
cd "$DIST"
tar -czf server-offline.tar.gz server-offline/
echo "  服务端: $(du -sh server-offline.tar.gz | cut -f1)"

# --------------------------------------------------
# 客户端离线包
# --------------------------------------------------
echo "===== 打包客户端离线安装包 ====="
CLIENT_DIR="$DIST/client-offline"
rm -rf "$CLIENT_DIR"
mkdir -p "$CLIENT_DIR"

# Python wheels
if [ -d "$OFFLINE/client-aarch64" ] && ls "$OFFLINE/client-aarch64/"*.whl 1>/dev/null 2>&1; then
    cp "$OFFLINE/client-aarch64/"*.whl "$CLIENT_DIR/"
else
    echo "WARNING: 未找到客户端 wheel 包，请确认 download-wheels.sh 已成功执行"
fi

# 依赖文件
cp "$ROOT/requirements-client-linux-arm64.txt" "$CLIENT_DIR/"

# 安装脚本
cat > "$CLIENT_DIR/install.sh" << 'INSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== 安装 CapsWriter-Offline 客户端依赖 ====="

# 前置系统包（需要 root 权限，如果已有本地源可跳过）
echo "请确保已安装系统依赖："
echo "  sudo apt install portaudio19-dev python3-tk xclip ffmpeg"
echo ""

# 安装 Python 包
pip install --no-index --find-links="$SCRIPT_DIR" \
    -r "$SCRIPT_DIR/requirements-client-linux-arm64.txt"

echo ""
echo "===== 安装完成 ====="
echo "下一步：修改 config_client.py 中的 addr 为服务端 IP"
INSTALL_EOF
chmod +x "$CLIENT_DIR/install.sh"

# 打包
cd "$DIST"
tar -czf client-offline.tar.gz client-offline/
echo "  客户端: $(du -sh client-offline.tar.gz | cut -f1)"

echo ""
echo "===== 打包完成 ====="
echo "输出目录: $DIST"
ls -lh "$DIST"/*.tar.gz
