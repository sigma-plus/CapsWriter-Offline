#!/usr/bin/env bash
# 服务端离线安装包打包脚本
# 运行环境：云服务器（download-server-only.sh + download-llama.sh 执行完成后）
# 输出：offline-release/server-offline.tar.gz
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OFFLINE="$ROOT/offline-packages"
DIST="$ROOT/offline-release"

mkdir -p "$DIST"

# 预检查
if [ ! -d "$OFFLINE/server-x86_64" ]; then
    echo "ERROR: 未找到 offline-packages/server-x86_64。请先运行 download-server-only.sh"
    exit 1
fi

if [ ! -d "$OFFLINE/llama.cpp-src" ]; then
    echo "ERROR: 未找到 offline-packages/llama.cpp-src。请先运行 download-llama.sh"
    exit 1
fi

echo "===== 打包服务端离线安装包 ====="
SERVER_DIR="$DIST/server-offline"
rm -rf "$SERVER_DIR"
mkdir -p "$SERVER_DIR"

# Python wheels
cp "$OFFLINE/server-x86_64/"*.whl "$SERVER_DIR/"
echo "  wheel 包: $(ls "$SERVER_DIR/"*.whl | wc -l) 个"

# llama.cpp 源码
cp -r "$OFFLINE/llama.cpp-src" "$SERVER_DIR/llama.cpp"
echo "  llama.cpp 源码: $(du -sh "$SERVER_DIR/llama.cpp" | cut -f1)"

# 依赖文件
cp "$ROOT/requirements-server-linux-cuda.txt" "$SERVER_DIR/"

# 安装脚本
cat > "$SERVER_DIR/install.sh" << 'INSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== 安装 CapsWriter-Offline 服务端依赖 ====="

# 1. 安装 Python 包
pip3 install --no-index --find-links="$SCRIPT_DIR" \
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
echo "  打包产物: $(du -sh server-offline.tar.gz | cut -f1)"
echo ""
echo "===== 打包完成 ====="
ls -lh "$DIST"/*.tar.gz
