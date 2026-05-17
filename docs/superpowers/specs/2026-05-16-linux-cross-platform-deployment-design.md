# CapsWriter-Offline 跨平台部署设计

> 日期：2026-05-16
> 基于：PR #359（Linux 支持）+ 当前 master 分支
> 状态：设计已批准，待实施

## 1. 目标

- **服务端**：在 Ubuntu 24.04 x86_64（2x4090D, CUDA 13.0）上运行，利用 CUDA 加速 Qwen3-ASR
- **客户端**：在麒麟V10 桌面版（飞腾2000, ARM64）上运行，通过局域网 WebSocket 连接服务端
- **约束**：仅 Windows x64 开发机能上网；Ubuntu 服务器和麒麟机器均为仅内网

## 2. 整体架构

```
┌─────────────────────────────┐       WebSocket        ┌──────────────────────────────────┐
│   客户端 - 麒麟V10 ARM64    │◄──────────────────────►│   服务端 - Ubuntu 24.04 x86_64    │
│   (飞腾2000, 仅内网)        │      (局域网直连)       │   (2x4090D, CUDA 13.0, 仅内网)   │
│                             │                        │                                  │
│  · pynput 快捷键            │                        │  · Qwen3-ASR (CUDA 加速)         │
│  · sounddevice 录音         │                        │  · onnxruntime-gpu               │
│  · PySide6 托盘             │                        │  · llama.cpp (CUDA 13.0)         │
│  · 热词 RAG (numpy/pypinyin)│                        │  · 标点模型 (CPU)                │
│  · LLM API → vLLM          │                        │  · Qwen3-ForcedAligner-0.6B      │
│  · Toast/对话框 (Tkinter)   │                        │  · vLLM + Qwen3.6 27B (已部署)   │
└─────────────────────────────┘                        └──────────────────────────────────┘
```

## 3. 已有资源

### 模型（无需额外下载）
- `models/Qwen3-ASR/Qwen3-ASR-1.7B/` — GGUF 模型 + ONNX 编码器
- `models/Qwen3-ForcedAligner-0.6B/` — 对齐器

### 服务器已部署
- vLLM + Qwen3.6 27B 推理服务（OpenAI 兼容 API）
- NVIDIA Driver 580.126.09, CUDA 13.0, nvidia-ctk 1.18.2

### 客户端 LLM
- 所有 LLM 角色调用走服务端 vLLM 端点，客户端无需本地 LLM
- 配置示例：`api_base = "http://<服务端IP>:8000/v1"`, `model = "Qwen3.6-27B"`

## 4. 方案：基于 PR #359 适配

合入 PR #359 已有的 Linux 平台路由代码（快捷键、托盘、字体 fallback），在其基础上：
- 服务端增加 CUDA 支持
- 客户端准备 ARM64 离线安装包

### 4.1 服务端依赖变更

| 项目 | Windows 原版 | Linux 服务端 |
|------|-------------|-------------|
| onnxruntime | onnxruntime-directml | **onnxruntime-gpu** |
| llama.cpp | win-vulkan-x64 预编译 | **本机编译 CUDA 13.0** |
| sherpa-onnx | pip install | pip install（离线） |
| 标点/对齐模型 | 不变 | 不变 |

### 4.2 客户端

PR #359 的客户端代码无需改动——`platform.system() == 'Linux'` 检查不区分架构，ARM64 Linux 自动走 Linux 分支。

客户端是纯 Python，无原生编译依赖。所有依赖均有 aarch64 manylinux wheel。

## 5. 硬件资源与分工

| 设备 | 联网 | 角色 |
|------|------|------|
| Windows x64 开发机 | ✅ 能上网 | 代码开发 |
| 云服务器 x86_64 (无GPU) | ✅ 能上网 | 下载服务端离线包、打包 |
| **云服务器 ARM64** | ✅ 能上网 | **客户端原生打包（推荐）** |
| Ubuntu 24.04 服务器 (2x4090D) | ❌ 仅内网 | 服务端运行、编译 llama.cpp |
| 麒麟V10 ARM64 (飞腾2000) | ❌ 仅内网 | 客户端运行 |

### 客户端打包优先级

**客户端部署易用性是重要指标。** 目标是让最终用户（麒麟 V10）做到"解压即运行"，无需手动安装 Python、pip 或配置环境变量。

**推荐方案**：使用 ARM64 云服务器原生打包（PyInstaller 目录模式）。

| 方案 | 客户端操作步骤 | 易用性 | 可靠性 |
|------|-------------|--------|--------|
| ARM64 云服务器 PyInstaller 打包 | 解压 → 配置 IP → 运行 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| x86_64 云服务器 pip download wheel | 安装 Python → apt 安装 → pip install → 配置 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Docker+QEMU 模拟打包 | 解压 → 配置 IP → 运行 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐（glibc 风险） |

如果有 ARM64 云服务器，优先使用方案 A；否则退回到方案 B（wheel 离线安装）。

## 6. 离线部署策略

### 6.0 客户端打包（ARM64 云服务器，推荐）

> **核心目标：客户端"解压即运行"，用户无需安装 Python 或任何 Python 包。**

**前提**：有一台能上网的 ARM64 云服务器，系统选择 Debian 11 Bullseye（glibc 2.31，兼容麒麟 V10）。

```bash
# 1. 安装依赖
sudo apt update && sudo apt install -y python3.12 python3.12-venv python3-pip \
    portaudio19-dev python3-tk xclip ffmpeg

# 2. 克隆代码
git clone https://github.com/HaujetZhao/CapsWriter-Offline.git
cd CapsWriter-Offline
git checkout feature/linux-cross-platform

# 3. 创建虚拟环境并安装依赖
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-client-linux-arm64.txt
pip install pyinstaller

# 4. PyInstaller 打包（目录模式）
pyinstaller start_client.py \
    --name CapsWriter-Client \
    --noconfirm \
    --collect-all pynput \
    --collect-all sounddevice \
    --collect-all PySide6 \
    --collect-all pypinyin \
    --hidden-import _tkinter

# 5. 补充配置文件到产物目录
cp -r core/ config_client.py hot*.txt hot-rule.txt LLM/ dist/CapsWriter-Client/

# 6. 打包
tar -czf client-offline.tar.gz -C dist CapsWriter-Client/
```

**客户端部署（麒麟 V10）**：

```bash
tar xzf client-offline.tar.gz
cd CapsWriter-Client
# 编辑服务端 IP
vim config_client.py
# 启动
./CapsWriter-Client
```

**关键约束**：
- 云服务器系统必须是 **Debian 11**（glibc 2.31）或 **Ubuntu 20.04**，不能更高，否则产物在麒麟 V10 上无法运行
- 系统级共享库（libportaudio、libtk 等）已随 PyInstaller 打包，麒麟 V10 上可能仍需 `apt install` 少量运行时库

### 6.1 云服务器上的下载工作（备选方案）

> 无 ARM64 云服务器时，使用 x86_64 云服务器下载 wheel 包，在麒麟 V10 上手动安装。

```bash
# 服务端 x86_64 wheel
pip download \
  --platform manylinux_2_17_x86_64 \
  --python-version 312 \
  --only-binary=:all: \
  -r requirements-server-linux-cuda.txt \
  -d ./wheels-x86_64/

# 客户端 aarch64 wheel
pip download \
  --platform manylinux2014_aarch64 \
  --python-version 312 \
  --only-binary=:all: \
  -r requirements-client-linux.txt \
  -d ./wheels-aarch64/

# llama.cpp 源码（用于服务器本机编译）
git clone https://github.com/ggml-org/llama.cpp.git --depth 1 --branch b7798
```

### 6.2 服务器离线安装（两种方案共用）

```bash
pip install --no-index --find-links=./wheels-x86_64 \
  -r requirements-server-linux-cuda.txt

# llama.cpp 本机编译（CUDA 13.0）
cd llama.cpp && mkdir build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### 6.3 麒麟客户端离线安装（备选方案，需手动）

> 仅在无 ARM64 云服务器时使用此方案。需要用户手动安装 Python 和系统依赖。

```bash
# 系统包（需确认麒麟本地 APT 源或 ISO）
sudo apt install portaudio19-dev python3-tk xclip ffmpeg

# Python 依赖
pip install --no-index --find-links=./wheels-aarch64 \
  -r requirements-client-linux.txt
```

### 6.4 麒麟系统包离线风险

## 7. CUDA 13.0 兼容性风险

| 组件 | 风险 | 对策 |
|------|------|------|
| onnxruntime-gpu | 最新版可能仅支持到 CUDA 12.x | 确认最新版本；不兼容则从源码编译 |
| llama.cpp 预编译 | 无 CUDA 13.0 构建 | 直接从源码编译（推荐） |
| NVIDIA 驱动 580.x | ✅ 无问题 | — |

## 8. 实施阶段

```
阶段 1：代码准备（Windows 开发机）
├── 合入 PR #359 Linux 支持代码
├── 新建 requirements-server-linux-cuda.txt
├── 调整 config_server.py 引擎配置
├── 编写离线下载脚本
└── WSL2 验证客户端启动流程

阶段 2A：客户端打包（ARM64 云服务器，推荐）
├── 选择 Debian 11 (glibc 2.31) 系统
├── 安装 Python 3.12 + 依赖 + PyInstaller
├── PyInstaller 目录模式打包
├── 补充配置文件（core/、config、hot*.txt、LLM/）
├── 打包为 client-offline.tar.gz
│
阶段 2B：服务端离线包（x86_64 云服务器或本地 VMware）
├── pip download x86_64 服务端依赖
├── 下载 llama.cpp 源码
├── 打包：server-offline.tar.gz

阶段 3：服务端部署（Ubuntu 服务器，离线）
├── pip install --no-index 安装服务端依赖
├── 本机编译 llama.cpp (CUDA 13.0)
├── 部署模型文件
├── 配置 Qwen3-ASR + CUDA
├── 启动服务端，验证 ASR 推理正常

阶段 4：客户端部署（麒麟V10，离线）
├── 解压 client-offline.tar.gz
├── 编辑 config_client.py（服务端 IP）
├── 编辑 LLM 角色文件（vLLM 端点）
└── ./CapsWriter-Client 启动，实测：快捷键 → 录音 → 识别 → 上屏
```

## 9. 工作量估计

| 阶段 | 预计耗时 | 风险 |
|------|---------|------|
| 阶段 1：代码准备 | 1-2 天 | 低 |
| 阶段 2A：客户端打包（ARM64） | 0.5 天 | 低（原生打包，无模拟） |
| 阶段 2B：服务端离线包 | 0.5 天 | 低 |
| 阶段 3：服务端部署 | 1 天 | 中（CUDA 13.0 兼容性） |
| 阶段 4：客户端部署 | **0.5 天** | 低（解压即运行） |
| **总计** | **3-5 天** | |
