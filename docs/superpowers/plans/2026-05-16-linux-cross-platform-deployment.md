# Linux 跨平台部署 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使 CapsWriter-Offline 服务端运行在 Ubuntu 24.04 x86_64 (2x4090D, CUDA 13.0)，客户端运行在麒麟V10 ARM64 (飞腾2000)，通过局域网 WebSocket 通信。

**Architecture:** 基于 PR #359 的 Linux 平台路由代码，服务端使用 onnxruntime-gpu + CUDA 加速 Qwen3-ASR，客户端为纯 Python 通过离线 wheel 安装。三机协作：Windows 开发机（代码）→ 云服务器（下载打包）→ 内网目标机（部署）。

**Tech Stack:** Python 3.12, onnxruntime-gpu, llama.cpp (CUDA), PySide6 (Linux 托盘), pynput (Linux 快捷键)

---

## File Structure

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `requirements-server-linux-cuda.txt` | 服务端 Linux CUDA 依赖 |
| Create | `requirements-client-linux-arm64.txt` | 客户端 Linux ARM64 依赖 |
| Create | `scripts/download-wheels.sh` | 云服务器上的离线包下载脚本 |
| Create | `scripts/package-offline.sh` | 离线安装包打包脚本 |
| Modify | `config_server.py:139` | onnx_provider 改为 CUDA |
| Modify | `config_client.py:13` | 服务端地址配置说明 |
| Modify | `docs/superpowers/specs/2026-05-16-linux-cross-platform-deployment-design.md` | 设计文档（已存在） |
| Merge | PR #359 | Linux 平台路由代码（快捷键、托盘、字体、构建） |

---

### Task 1: 创建功能分支

**Files:**
- 操作: git branch

- [ ] **Step 1: 从 master 创建功能分支**

```bash
git checkout master
git pull origin master
git checkout -b feature/linux-cross-platform
git push -u origin feature/linux-cross-platform
```

Run: `git branch`
Expected: 当前在 `feature/linux-cross-platform` 分支

---

### Task 2: 合入 PR #359 的 Linux 支持代码

PR #359 提交了 990 行新增代码，包含 Linux 快捷键管理器、托盘、字体 fallback、构建脚本等。

**Files:**
- 新增: `util/client/shortcut/linux_key_mapper.py`
- 新增: `util/client/shortcut/linux_shortcut_manager.py`
- 修改: `util/client/shortcut/__init__.py` (平台路由)
- 修改: `util/ui/tray.py` (Linux 托盘 PySide6)
- 修改: `util/ui/toast_constants.py` (Linux 字体 fallback)
- 修改: `util/ui/dialogs.py`, `context_dialog.py`, `hotword_dialog.py`, `rectify_dialog.py` (字体适配)
- 修改: `core_client.py` (重连退避)
- 修改: `core_server.py` (托盘初始化顺序)
- 修改: `util/server/cleanup.py` (Linux 日志查看)
- 新增: `build-linux.sh`, `build-linux.spec`, `strip_pyside6.py`, `build-icon.py`
- 新增: `requirements-client-linux.txt`, `requirements-server-linux.txt`
- 修改: `.gitignore`

- [ ] **Step 1: 从 PR #359 的 fork 仓库拉取代码**

```bash
# 添加 PR 作者的仓库为临时远端
git remote add pr359 https://github.com/JazerJu/CapsWriter-Offline.git
git fetch pr359
```

Run: `git remote -v`
Expected: 能看到 pr359 远端

- [ ] **Step 2: 查看 PR #359 的分支名和提交历史**

```bash
git branch -r | grep pr359
git log pr359/main --oneline -20
```

Expected: 找到包含 Linux 支持的分支和提交

- [ ] **Step 3: 合并 PR #359 的 Linux 支持代码**

```bash
# 使用 merge 保留完整提交历史
git merge pr359/<linux-branch> --no-edit
```

如果出现冲突，优先保留我们 master 的 `config_server.py` 和 `config_client.py`（我们后续会改），其余以 PR #359 为准。

Run: `git log --oneline -10`
Expected: 看到 PR #359 的提交已合入

- [ ] **Step 4: 验证合入后的代码结构**

```bash
# 检查关键文件是否存在
ls util/client/shortcut/linux_key_mapper.py
ls util/client/shortcut/linux_shortcut_manager.py
ls requirements-client-linux.txt
ls requirements-server-linux.txt
ls build-linux.sh
```

Expected: 所有文件都存在

- [ ] **Step 5: 验证 Windows 端未受影响**

```bash
# 确认 Windows 版的快捷键和托盘文件未丢失
ls util/client/shortcut/key_mapper.py
ls util/client/shortcut/shortcut_manager.py
```

Expected: Windows 文件仍在

- [ ] **Step 6: 提交合并结果（如有冲突解决）**

```bash
git add -A
git commit -m "merge: 合入 PR #359 Linux 服务端/客户端完整支持"
```

Run: `git status`
Expected: clean working tree

---

### Task 3: 创建服务端 Linux CUDA 依赖文件

**Files:**
- Create: `requirements-server-linux-cuda.txt`

- [ ] **Step 1: 创建依赖文件**

基于 PR #359 的 `requirements-server-linux.txt`，将 `onnxruntime` 替换为 `onnxruntime-gpu`：

```
# Linux 服务端依赖 (CUDA 加速版)
# 目标：Ubuntu 24.04 x86_64 + CUDA 13.0

# ASR core
sherpa-onnx
numpy
onnxruntime-gpu

# basic
rich
websockets
watchdog
pypinyin

# tray (Linux uses PySide6, not pystray)
PySide6-Essentials
shiboken6
Pillow

markdown
tkhtmlview
```

- [ ] **Step 2: 提交**

```bash
git add requirements-server-linux-cuda.txt
git commit -m "feat: 添加服务端 Linux CUDA 依赖文件"
```

---

### Task 4: 创建客户端 Linux ARM64 依赖文件

**Files:**
- Create: `requirements-client-linux-arm64.txt`

- [ ] **Step 1: 创建依赖文件**

基于 PR #359 的 `requirements-client-linux.txt`，移除 `numba`（ARM64 上安装复杂且非必需，热词系统有 fallback），增加说明注释：

```
# Linux 客户端依赖 (ARM64 / 飞腾2000 / 麒麟V10)
# 所有包均有 aarch64 manylinux 预编译 wheel
# 注意：numba 已移除，热词系统使用 numpy fallback

# basic and cli
rich
typer
colorama
markdown

# system, input, hardware
pynput
sounddevice
watchdog

# network and api
websockets
openai
ollama
httpx

# data process
numpy
pypinyin
srt
rapidfuzz

# tray (Linux uses PySide6, not pystray)
PySide6-Essentials
shiboken6
Pillow
tkhtmlview

# clipboard
pyclip
```

注意：需要验证 `numba` 在 ARM64 上的可用性。如果麒麟V10 上 `numba` 有 aarch64 wheel，则应加回。检查命令：

```bash
pip download --platform manylinux2014_aarch64 --python-version 312 --only-binary=:all: numba
```

如果下载成功，在文件中加入 `numba`。

- [ ] **Step 2: 提交**

```bash
git add requirements-client-linux-arm64.txt
git commit -m "feat: 添加客户端 Linux ARM64 依赖文件"
```

---

### Task 5: 调整 config_server.py 支持 CUDA

**Files:**
- Modify: `config_server.py:139`

- [ ] **Step 1: 修改 Qwen3ASRGGUFArgs 的 onnx_provider 默认值和注释**

将 `config_server.py` 第 139 行：

```python
    onnx_provider = 'CPU'       # ONNX 推理后端 (CPU, DML)
```

改为：

```python
    onnx_provider = 'CUDA'     # ONNX 推理后端 (CPU, CUDA, DML)
```

注意：这是用户本地配置文件，改默认值可能影响 Windows 用户。更好的做法是**不修改默认值**，而是在部署文档中说明 Linux 服务器上需改为 `CUDA`。

**决定**：不改默认值。在 `config_server.py` 中添加注释说明即可：

```python
    onnx_provider = 'CPU'       # ONNX 推理后端 (CPU, CUDA, DML)
                                # Linux + NVIDIA GPU 时改为 'CUDA'
```

- [ ] **Step 2: 提交**

```bash
git add config_server.py
git commit -m "docs: config_server 添加 CUDA provider 说明"
```

---

### Task 6: 创建离线下载脚本

**Files:**
- Create: `scripts/download-wheels.sh`

此脚本在云服务器（能上网的 Ubuntu 24.04 x86_64）上运行，下载所有离线 wheel 包。

- [ ] **Step 1: 创建脚本目录**

```bash
mkdir -p scripts
```

- [ ] **Step 2: 编写下载脚本**

```bash
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
```

- [ ] **Step 3: 提交**

```bash
git add scripts/download-wheels.sh
git commit -m "feat: 添加离线依赖下载脚本（云服务器用）"
```

---

### Task 7: 创建离线安装包打包脚本

**Files:**
- Create: `scripts/package-offline.sh`

- [ ] **Step 1: 编写打包脚本**

```bash
#!/usr/bin/env bash
# 离线安装包打包脚本
# 运行环境：云服务器（download-wheels.sh 执行完成后）
# 输出：server-offline.tar.gz + client-offline.tar.gz

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OFFLINE="$ROOT/offline-packages"
DIST="$ROOT/offline-release"

mkdir -p "$DIST"

# --------------------------------------------------
# 服务端离线包
# --------------------------------------------------
echo "===== 打包服务端离线安装包 ====="
SERVER_DIR="$DIST/server-offline"
mkdir -p "$SERVER_DIR"

# Python wheels
cp -r "$OFFLINE/server-x86_64/"*.whl "$SERVER_DIR/" 2>/dev/null || true

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
mkdir -p "$CLIENT_DIR"

# Python wheels
cp -r "$OFFLINE/client-aarch64/"*.whl "$CLIENT_DIR/" 2>/dev/null || true

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
```

- [ ] **Step 2: 提交**

```bash
git add scripts/package-offline.sh
git commit -m "feat: 添加离线安装包打包脚本"
```

---

### Task 8: 创建部署文档

**Files:**
- Create: `docs/deployment-linux.md`

- [ ] **Step 1: 编写部署文档**

文档内容包含四个阶段：代码准备 → 离线包准备 → 服务端部署 → 客户端部署。覆盖：
- 每个阶段的操作步骤和命令
- config_server.py 中 `onnx_provider = 'CUDA'` 的修改
- config_client.py 中 `addr` 改为服务端 IP
- LLM 角色配置指向 vLLM 端点 (`http://<服务端IP>:8000/v1`)
- 麒麟V10 系统包安装注意事项
- CUDA 13.0 兼容性排查指南
- 常见问题 FAQ

- [ ] **Step 2: 提交**

```bash
git add docs/deployment-linux.md
git commit -m "docs: 添加 Linux 跨平台部署文档"
```

---

### Task 9: 推送代码并同步到云服务器

- [ ] **Step 1: 推送功能分支到远端**

```bash
git push origin feature/linux-cross-platform
```

- [ ] **Step 2: 在云服务器上克隆仓库**

```bash
# 在云服务器上执行
git clone https://github.com/sigma-plus/CapsWriter-Offline.git
cd CapsWriter-Offline
git checkout feature/linux-cross-platform
```

- [ ] **Step 3: 执行离线包下载**

```bash
# 在云服务器上执行
bash scripts/download-wheels.sh
bash scripts/package-offline.sh
```

Expected: 生成 `offline-release/server-offline.tar.gz` 和 `offline-release/client-offline.tar.gz`

- [ ] **Step 4: 传输离线包到内网目标机**

通过 U 盘或内网传输：
- `server-offline.tar.gz` → Ubuntu 服务器
- `client-offline.tar.gz` → 麒麟V10
- 源码仓库（`git archive` 或直接 `.git` 目录）→ 两台机器

---

### Task 10: 服务端部署验证（Ubuntu 24.04 + 2x4090D）

- [ ] **Step 1: 解压离线包并安装 Python 依赖**

```bash
tar -xzf server-offline.tar.gz
cd server-offline
bash install.sh
```

- [ ] **Step 2: 编译 llama.cpp**

```bash
cd llama.cpp/build
make -j$(nproc)
# 复制产物到 util/llama/bin/
cp libllama.so libggml.so libggml-base.so /path/to/CapsWriter-Offline/util/llama/bin/
```

- [ ] **Step 3: 修改 config_server.py**

```python
# config_server.py 第 139 行
onnx_provider = 'CUDA'     # 改为 CUDA
```

- [ ] **Step 4: 启动服务端**

```bash
python start_server.py
```

Expected: 日志显示 `CUDAExecutionProvider` 加载成功，Qwen3-ASR 模型加载完成

- [ ] **Step 5: 验证 CUDA 加速**

观察日志中的 `process_time` 和 `RTF`，确认 GPU 被使用。用 Ctrl+C 停止。

---

### Task 11: 客户端部署验证（麒麟V10 ARM64）

- [ ] **Step 1: 安装系统依赖**

```bash
sudo apt install portaudio19-dev python3-tk xclip ffmpeg
```

如果麒麟无本地源，需提前准备对应 .deb 包。

- [ ] **Step 2: 解压离线包并安装 Python 依赖**

```bash
tar -xzf client-offline.tar.gz
cd client-offline
bash install.sh
```

- [ ] **Step 3: 修改 config_client.py**

```python
# config_client.py 第 13-14 行
addr = '<服务端IP>'    # 改为 Ubuntu 服务器的内网 IP
port = '6016'
```

- [ ] **Step 4: 配置 LLM 角色**

修改 `LLM/default.py`（或其他角色）的 API 配置，指向服务端 vLLM：

```python
api_base = "http://<服务端IP>:8000/v1"
model = "Qwen3.6-27B"
```

- [ ] **Step 5: 启动客户端**

```bash
no_proxy='*' python start_client.py
```

Expected: 日志显示 WebSocket 连接成功，快捷键监听器启动

- [ ] **Step 6: 端到端测试**

1. 按住 CapsLock 说一句话，松开
2. 确认文字上屏正常
3. 测试 Toast 显示
4. 测试 LLM 角色（如翻译）

---

### Task 12: 最终提交和合并

- [ ] **Step 1: 合并到 master**

```bash
git checkout master
git merge feature/linux-cross-platform
git push origin master
```

- [ ] **Step 2: 打 tag**

```bash
git tag -a v2.5-linux-cuda -m "Linux 跨平台部署支持 (服务端 CUDA + 客户端 ARM64)"
git push origin v2.5-linux-cuda
```
