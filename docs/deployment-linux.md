# CapsWriter-Offline Linux 跨平台部署指南

本文档描述如何将 CapsWriter-Offline 部署到以下环境：

- **服务端**：Ubuntu 24.04 x86_64，双 4090D，CUDA 13.0，仅内网（air-gapped）
- **客户端**：麒麟 V10 ARM64，飞腾 2000，仅内网（待实施）
- **离线包准备**：腾讯云服务器（Ubuntu 24.04 x86_64，无 GPU，能上网）

---

## 阶段一：离线包准备（腾讯云服务器）

### 1.1 云服务器信息

| 项目 | 值 |
|------|------|
| IP | 124.220.226.171 |
| 用户 | ubuntu |
| SSH 密钥 | `D:\tmp\tx_ubuntu.pem` |
| 系统 | Ubuntu 24.04 x86_64 |
| pip 镜像 | 已配置腾讯云内网镜像 `mirrors.tencentyun.com` |

### 1.2 环境准备

云服务器已具备：
- Python 3.12.3、git 2.43、gcc 13.2、bash 5.2、venv
- pip 已安装（`sudo apt install python3-pip`）
- PyPI 内网镜像、GitHub 需代理加速（ghfast.top）

### 1.3 打包脚本说明

| 脚本 | 用途 | 运行环境 |
|------|------|----------|
| `scripts/download-server-only.sh` | 下载服务端 Python wheel 包（x86_64 CUDA） | 云服务器 |
| `scripts/download-llama.sh` | 下载 llama.cpp 源码（zip 方式，带 GitHub 代理回退） | 云服务器 |
| `scripts/download-server-debs.sh` | 下载系统 deb 包（cmake、libsndfile1 等） | 云服务器 |
| `scripts/package-server-final.sh` | 打包为 `server-offline.tar.gz` 完整离线包 | 云服务器 |
| `scripts/deploy-server.sh` | 目标服务器一键部署（安装 deb + wheel + 编译 llama.cpp + 注册服务） | 目标服务器 |
| `scripts/capswriter-server.service` | systemd 服务文件（开机自启 + 崩溃自动重启） | 目标服务器 |

### 1.4 打包步骤（已执行完成）

```bash
cd ~/CapsWriter-Offline

# 1. 下载 Python wheel 包（30 个，483MB）
bash scripts/download-server-only.sh

# 2. 下载 llama.cpp 源码（tag b7798，129MB）
bash scripts/download-llama.sh

# 3. 下载系统 deb 包（18 个，17MB）
bash scripts/download-server-debs.sh

# 4. 打包为完整离线包（524MB）
bash scripts/package-server-final.sh
```

### 1.5 离线包内容

产物：`offline-release/server-offline.tar.gz`（524MB）

| 内容 | 数量/大小 | 用途 |
|------|----------|------|
| Python wheel 包 | 30 个 | sherpa-onnx、onnxruntime-gpu、numpy、PySide6-Essentials 等运行时依赖 |
| llama.cpp 源码 | 129MB | 目标机器上源码编译 CUDA 版本 |
| 系统 deb 包 | 18 个 / 17MB | cmake、libsndfile1、python3-pip、python3-venv 等 |
| `requirements-server-linux-cuda.txt` | — | Python 依赖清单 |
| `capswriter-server.service` | — | systemd 服务文件 |
| `deploy-server.sh` | — | 一键部署脚本 |

---

## 阶段二：服务端部署（目标服务器，air-gapped）

### 2.1 目标服务器环境

| 项目 | 值 |
|------|------|
| 系统 | Ubuntu 24.04 x86_64 |
| GPU | 双 NVIDIA 4090D |
| CUDA | 13.0（Docker 提供） |
| 网络 | 仅内网，无外网访问 |

### 2.2 传输文件到目标服务器

通过 U 盘或内网文件传输：

1. `server-offline.tar.gz`（524MB）— 离线安装包
2. 源码仓库（整个 `CapsWriter-Offline` 目录）
3. 模型文件 → 放入 `models/` 目录

模型目录结构（根据 `config_server.py` 中 `ModelPaths` 配置）：

```
models/
├── Qwen3-ASR/Qwen3-ASR-1.7B/
│   ├── qwen3_asr_encoder_frontend.onnx
│   ├── qwen3_asr_encoder_backend.onnx
│   └── qwen3_asr_llm.gguf
├── Punct-CT-Transformer/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12/
│   └── model.onnx
└── Qwen3-ForcedAligner/Qwen3-ForcedAligner-0.6B/
    ├── qwen3_aligner_encoder_frontend.int4.onnx
    ├── qwen3_aligner_encoder_backend.int4.onnx
    └── qwen3_aligner_llm.q5_k.gguf
```

### 2.3 一键部署

```bash
tar -xzf server-offline.tar.gz
cd server-offline && bash deploy-server.sh
```

脚本自动完成：安装系统 deb → 安装 Python wheel → 编译 llama.cpp（CUDA）→ 注册 systemd 服务。

### 2.4 修改 systemd 服务文件

编辑 `/etc/systemd/system/capswriter-server.service`，根据实际情况修改：

```ini
[Service]
User=<实际运行用户>
Group=<实际运行用户组>
WorkingDirectory=<源码仓库实际路径>    # 如 /opt/CapsWriter-Offline
ExecStart=<python 实际路径> start_server.py  # 如 /usr/bin/python3.12
```

修改后执行：

```bash
sudo systemctl daemon-reload
```

### 2.5 修改服务端配置

编辑源码仓库中的 `config_server.py`：

```python
# 所有引擎参数类中的 onnx_provider 改为 CUDA
onnx_provider = 'CUDA'

# 确认模型路径正确（默认相对于仓库根目录）
model_dir = Path() / 'models'

# 确认监听地址和端口
addr = '0.0.0.0'
port = '6016'
```

### 2.6 启动并验证

```bash
# 启动服务
sudo systemctl start capsriter-server

# 查看状态
sudo systemctl status capsriter-server

# 实时查看日志
journalctl -u capsriter-server -f
```

确认日志中：
- `CUDAExecutionProvider` 加载成功
- 模型加载完成
- WebSocket 服务在 `0.0.0.0:6016` 上监听

### 2.7 systemd 服务说明

| 配置项 | 值 | 说明 |
|--------|------|------|
| `Restart` | `on-failure` | 进程异常退出时自动重启 |
| `RestartSec` | 5 秒 | 重启间隔 |
| `StartLimitBurst` | 3 次 | 60 秒内最多重启 3 次，防止死循环 |
| `LimitNOFILE` | 65536 | 文件描述符上限 |

常用操作：

```bash
sudo systemctl start capsriter-server      # 启动
sudo systemctl stop capsriter-server       # 停止
sudo systemctl restart capsriter-server    # 重启
sudo systemctl status capsriter-server     # 状态
sudo systemctl enable capsriter-server     # 开机自启（deploy.sh 已执行）
sudo systemctl disable capsriter-server    # 取消自启
journalctl -u capsriter-server -f          # 实时日志
journalctl -u capsriter-server --since today  # 今日日志
```

### 2.8 端到端验证

1. 确认端口监听：`ss -tlnp | grep 6016`
2. 从客户端机器测试连通性：`nc -zv <服务端IP> 6016`
3. 配合客户端进行语音识别测试

---

## 阶段三：客户端部署（麒麟 V10 ARM64，待实施）

> **部署原则：客户端易用性优先。** 最终用户无需安装 Python、pip 或手动配置环境变量，做到"解压即运行"。

### 方案 A：ARM64 云服务器预打包（推荐）

通过 ARM64 云服务器上的 PyInstaller 预打包，客户端只需解压和配置 IP。

#### 3.A.1 选择云服务器

**glibc 匹配原则**：构建环境的 glibc 版本必须 ≤ 目标机器的 glibc 版本。

先在麒麟 V10 上确认 glibc 版本：

```bash
ldd --version
# 麒麟 V10 输出：Ubuntu GLIBC 2.31-0kylin9.1k20.8
```

| 云服务器 OS | glibc | 适配 glibc 2.31 目标 | Python 3.12 安装 |
|---|---|---|---|
| **Debian 11（推荐）** | 2.31 | ✅ 精确匹配 | 源码编译 |
| Ubuntu 20.04 | 2.31 | ✅ 精确匹配 | deadsnakes PPA |
| Debian 10 | 2.28 | ✅ 更低，兼容 | 源码编译 |
| Ubuntu 22.04+ | 2.35+ | ❌ 产物无法运行 | 原生 |

> Debian 11 的 backports 源可能已归档（404），需注释掉：`sed -i 's/^deb.*bullseye-backports/#&/' /etc/apt/sources.list`

**CPU 选择**：优先 Ampere（标准 ARMv8.2），与飞腾2000 完全兼容。

**推荐配置**：Debian 11 + Ampere CPU + 2核 / 8GB RAM / 40GB 磁盘。

#### 3.A.2 编译安装 Python 3.12

Debian 11 默认 Python 为 3.9（不满足 `requires-python >= 3.10`），需源码编译安装。

**关键：必须加 `--enable-shared`，否则 PyInstaller 报错。** 不要加 `--enable-optimizations`（ARM64 上 PGO 编译会失败）。

```bash
# 安装编译依赖
apt update && apt install -y build-essential zlib1g-dev libffi-dev libssl-dev \
    libbz2-dev libreadline-dev libsqlite3-dev liblzma-dev

# 下载源码（华为镜像，国内快）
curl -L -o /root/Python-3.12.10.tgz \
    https://mirrors.huaweicloud.com/python/3.12.10/Python-3.12.10.tgz
tar xzf Python-3.12.10.tgz && cd Python-3.12.10

# 编译（不加 --enable-optimizations，ARM64 上 PGO 会失败）
./configure --enable-shared --prefix=/usr/local/python3.12 \
    LDFLAGS='-Wl,-rpath,/usr/local/python3.12/lib'
make -j$(nproc) && make altinstall

# 验证
/usr/local/python3.12/bin/python3.12 --version  # Python 3.12.10
ls /usr/local/python3.12/lib/libpython3.12.so    # 确认 shared lib 存在
```

#### 3.A.3 安装系统依赖

```bash
apt install -y portaudio19-dev tk-dev xclip ffmpeg libespeak1 git
```

#### 3.A.4 上传客户端代码

在 Windows 开发机上打包（只打包客户端相关文件）：

```bash
tar czf capsclient.tar.gz \
  start_client.py config_client.py build_hook.py pyproject.toml \
  requirements-client-linux-arm64.txt \
  core/__init__.py core/client/ core/tools/ core/ui/ core/protocol.py \
  hot.txt hot-server.txt hot-rule.txt LLM/ assets/icon.ico
```

上传到 ARM64 云服务器并解压。

#### 3.A.5 安装依赖并打包

```bash
/usr/local/python3.12/bin/python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
pip install -r requirements-client-linux-arm64.txt pyinstaller \
    -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com

pyinstaller start_client.py \
    --name CapsWriter-Client --noconfirm \
    --collect-all pynput --collect-all sounddevice --collect-all PySide6 \
    --collect-all pypinyin \
    --hidden-import _tkinter --hidden-import websockets --hidden-import rich \
    --hidden-import keyboard --hidden-import watchdog --hidden-import numpy \
    --hidden-import rapidfuzz --hidden-import pyclip --hidden-import typer \
    --hidden-import srt --hidden-import markdown --hidden-import tkhtmlview \
    --hidden-import openai --hidden-import ollama --hidden-import httpx

# 补充配置文件到产物
cd dist/CapsWriter-Client/
cp /path/to/source/{config_client.py,hot.txt,hot-server.txt,hot-rule.txt} .
cp -r /path/to/source/{core,LLM,assets} .
cd .. && tar czf CapsWriter-Client-arm64.tar.gz CapsWriter-Client/
```

#### 3.A.6 客户端部署（3 步）

```bash
tar xzf CapsWriter-Client-arm64.tar.gz
cd CapsWriter-Client
vim config_client.py  # 修改 addr = '<服务端IP>'
./CapsWriter-Client
```

### 方案 B：wheel 离线安装（备选）

无 ARM64 云服务器时使用。需手动安装 Python 和系统依赖。

#### 3.B.1 安装系统依赖

```bash
sudo apt install portaudio19-dev python3-tk xclip ffmpeg
```

#### 3.B.2 安装 Python 依赖

```bash
tar -xzf client-offline.tar.gz
cd client-offline && bash install.sh
```

#### 3.B.3 配置并启动

```bash
# 修改 config_client.py 中 addr 为服务端 IP
no_proxy='*' python3 start_client.py
```

---

## 常见问题 FAQ

### Q1: onnxruntime-gpu 报 CUDA 版本不兼容？

```bash
nvcc --version           # 查看 CUDA 版本
pip3 show onnxruntime-gpu  # 查看 onnxruntime 版本
```

临时方案：`config_server.py` 中设置 `onnx_provider = 'CPU'`。

### Q2: llama.cpp 编译失败？

检查前置条件：

```bash
cmake --version  # >= 3.14
gcc --version    # >= 11
nvcc --version   # CUDA Toolkit
```

常见问题：cmake 找不到 CUDA → 确认 `CUDA_PATH` 环境变量；内存不足 → `make -j4`。

### Q3: 客户端连接不上服务端？

1. 确认服务端运行：`ss -tlnp | grep 6016`
2. 确认防火墙：`sudo iptables -L -n | grep 6016`
3. 从客户端测试：`nc -zv <服务端IP> 6016`

### Q4: GitHub 下载超时？

使用代理加速（已在 `download-llama.sh` 中内置多源回退）：

```bash
# 可用代理
https://ghfast.top/
https://ghproxy.net/
```

---

## 部署检查清单

### 服务端

- [ ] `server-offline.tar.gz` 已传输到目标服务器
- [ ] 源码仓库已传输
- [ ] 模型文件已部署到 `models/` 目录
- [ ] `deploy-server.sh` 执行成功
- [ ] `capswriter-server.service` 中路径和用户已修改
- [ ] `config_server.py` 中 `onnx_provider = 'CUDA'`
- [ ] `sudo systemctl start capsriter-server` 启动正常
- [ ] 日志显示 CUDAExecutionProvider 加载成功
- [ ] 端口 6016 可访问
- [ ] 端到端语音识别测试通过

### 客户端

- [ ] 方案已确定（A: PyInstaller 预打包 / B: wheel 离线安装）
- [ ] 客户端可启动并连接服务端
- [ ] 端到端语音识别测试通过
