# CapsWriter-Offline Linux 跨平台部署指南

本文档描述如何将 CapsWriter-Offline 部署到以下环境：

- **服务端**：Ubuntu 24.04 x86_64，双 4090D，CUDA 13.0，仅内网
- **客户端**：麒麟 V10 ARM64，飞腾 2000，仅内网
- **离线包准备**：云服务器（Ubuntu 24.04 x86_64，无 GPU，能上网）

整体流程分为四个阶段，按顺序执行。

---

## 阶段一：代码准备（Windows 开发机）

### 1.1 拉取代码

从 GitHub 拉取代码（如果已合并到主分支，直接克隆即可；否则切换到功能分支）：

```bash
git clone https://github.com/HaujetZhao/CapsWriter-Offline.git
cd CapsWriter-Offline
# 如果已合并到 master，无需切换分支
# git checkout feature/linux-cross-platform  # 功能分支（合并前使用）
```

### 1.2 代码结构说明

该分支相比主分支新增了以下跨平台部署相关文件：

| 文件 | 说明 |
|------|------|
| `requirements-server-linux-cuda.txt` | 服务端 CUDA 依赖清单（x86_64） |
| `requirements-client-linux-arm64.txt` | 客户端 ARM64 依赖清单（aarch64） |
| `scripts/download-wheels.sh` | 云服务器下载脚本，自动下载所有 wheel 包和 llama.cpp 源码 |
| `scripts/package-offline.sh` | 打包脚本，将下载内容打包为离线安装包 |

将整个仓库目录（或压缩包）拷贝至云服务器，用于阶段二的离线包准备。

---

## 阶段二：离线包准备（云服务器，能上网）

### 2.1 环境要求

- **系统**：Ubuntu 24.04 x86_64
- **GPU**：无需 GPU
- **网络**：能访问 PyPI 和 GitHub
- **工具**：git, bash, python3

### 2.2 克隆仓库并切换分支

```bash
git clone https://github.com/HaujetZhao/CapsWriter-Offline.git
cd CapsWriter-Offline
# git checkout feature/linux-cross-platform  # 功能分支（合并前使用）
```

### 2.3 下载依赖包

运行下载脚本，自动完成以下工作：

```bash
bash scripts/download-wheels.sh
```

脚本会下载：

- **服务端 x86_64 CUDA 依赖**：onnxruntime-gpu、numpy、fastapi 等
- **客户端 aarch64 ARM64 依赖**：onnxruntime、pynput、sounddevice 等（通过 `--platform aarch64` 交叉下载）
- **llama.cpp 源码**：tag b7798，用于目标机器上源码编译

> 下载时间取决于网络速度，预计 10-30 分钟。

### 2.4 打包离线安装包

```bash
bash scripts/package-offline.sh
```

脚本会生成：

- `offline-release/server-offline.tar.gz` — 服务端离线安装包（含 wheel 包 + llama.cpp 源码 + install.sh）
- `offline-release/client-offline.tar.gz` — 客户端离线安装包（含 wheel 包 + install.sh）

### 2.5 传输到目标机器

通过 U 盘或内网文件传输，将以下文件拷贝到目标机器：

1. `offline-release/server-offline.tar.gz` — 拷贝到服务端
2. `offline-release/client-offline.tar.gz` — 拷贝到客户端
3. 整个源码仓库 — 分别拷贝到服务端和客户端
4. 模型文件 — 拷贝到服务端（见阶段三）

---

## 阶段三：服务端部署（Ubuntu 24.04 x86_64, 2x4090D, CUDA 13.0, 仅内网）

### 3.1 传输文件

将以下内容传输到服务端：

- 源码仓库（整个 `CapsWriter-Offline` 目录）
- `server-offline.tar.gz`
- 模型文件（ASR 模型、标点模型等）

### 3.2 安装 Python 3.12

如果系统尚未安装 Python 3.12：

```bash
# 如果有本地源或能联网
sudo apt update
sudo apt install python3.12 python3.12-venv python3-pip

# 如果完全离线，需要提前准备 Python 3.12 的 deb 包
```

确认版本：

```bash
python3.12 --version
# 应输出 Python 3.12.x
```

### 3.3 解压并安装离线依赖

```bash
tar -xzf server-offline.tar.gz
cd server-offline && bash install.sh
```

`install.sh` 会使用 `pip install --no-index --find-links` 从本地 wheel 包安装所有依赖。

### 3.4 编译 llama.cpp（CUDA 13.0）

由于 llama.cpp 没有预编译的 CUDA 13.0 构建，需要从源码编译：

```bash
cd llama.cpp
mkdir -p build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

编译前置条件：

- cmake >= 3.14
- gcc >= 11
- CUDA Toolkit 13.0 已安装并配置好环境变量

验证编译结果：

```bash
./bin/llama-server --help
# 应正常输出帮助信息
```

### 3.5 修改服务端配置

编辑 `config_server.py`，确认以下配置：

```python
# 在 Qwen3ASRGGUFArgs 类中，找到 onnx_provider 设置
onnx_provider = 'CUDA'  # 确保使用 CUDA 加速
```

其他需要根据实际情况调整的配置项：

- `model_dir` — 模型文件目录路径
- `engine_type` — ASR 引擎类型（如 `fun_asr_nano`、`qwen_asr` 等）
- `host` / `port` — 服务监听地址和端口（默认 `0.0.0.0:6016`）

### 3.6 部署模型文件

将模型文件放入 `models/` 目录，确保目录结构正确：

```
models/
├── asr/           # ASR 模型
├── punc/          # 标点模型
└── ...
```

具体模型文件名和结构取决于 `config_server.py` 中的配置。

### 3.7 启动服务端

```bash
cd /path/to/CapsWriter-Offline
python3.12 start_server.py
```

### 3.8 验证部署

启动后观察日志输出，确认：

- 日志中出现 `CUDAExecutionProvider` 加载成功
- 日志中出现模型加载完成
- WebSocket 服务在 `0.0.0.0:6016` 上监听

如遇到问题，查看 `logs/server_latest.log` 排查。

---

## 阶段四：客户端部署（麒麟V10 ARM64, 飞腾2000, 仅内网）

### 4.1 传输文件

将以下内容传输到客户端：

- 源码仓库（整个 `CapsWriter-Offline` 目录）
- `client-offline.tar.gz`

### 4.2 安装系统依赖

> 注意：麒麟 V10 的包名称可能与 Ubuntu 不同，请根据实际系统调整。可能需要从 ISO 挂载本地 APT 源。

```bash
sudo apt install portaudio19-dev python3-tk xclip ffmpeg
```

如果 `apt install` 报找不到包，尝试以下替代方案：

```bash
# 可能的替代包名
sudo apt install libportaudio2 portaudio19-dev
sudo apt install python3-tk
sudo apt install xclip xsel
sudo apt install ffmpeg
```

### 4.3 安装 Python 依赖

```bash
tar -xzf client-offline.tar.gz
cd client-offline && bash install.sh
```

### 4.4 修改客户端配置

编辑 `config_client.py`：

```python
# 服务端地址（改为 Ubuntu 服务器的内网 IP）
addr = '192.168.x.x'  # 替换为实际服务端 IP
port = '6016'
```

### 4.5 配置 LLM 角色

根据需要编辑 `LLM/` 目录下的角色文件，例如 `LLM/翻译.py`：

```python
# 指向服务端 vLLM 服务
api_base = "http://192.168.x.x:8000/v1"  # 替换为实际服务端 IP
model = "Qwen3.6-27B"
```

其他角色文件（`LLM/高级翻译.py`、`LLM/大助理.py`、`LLM/小助理.py`）按同样方式修改 `api_base` 和 `model`。

### 4.6 启动客户端

```bash
# no_proxy 确保不经过代理访问内网服务端
no_proxy='*' python3 start_client.py
```

### 4.7 端到端测试

1. 确认客户端日志显示 WebSocket 连接成功
2. 按住 CapsLock 键
3. 对麦克风说一句话
4. 松开 CapsLock 键
5. 确认识别文字正确上屏到当前光标位置

如遇到问题，查看 `logs/client_latest.log` 排查。

---

## CUDA 13.0 兼容性排查

| 组件 | 风险 | 对策 |
|------|------|------|
| onnxruntime-gpu | 最新版可能仅支持到 CUDA 12.x | 确认版本对应关系；不兼容则指定兼容版本号（如 `onnxruntime-gpu==1.20.x`） |
| llama.cpp 预编译 | 无 CUDA 13.0 构建 | 从源码编译（推荐方案，见阶段三 3.4） |
| NVIDIA 驱动 580.x | 无问题 | 无需额外处理 |

### onnxruntime-gpu 版本与 CUDA 对应关系

| onnxruntime-gpu | CUDA | 备注 |
|-----------------|------|------|
| 1.19.x | 12.x | 稳定版本 |
| 1.20.x | 12.x / 13.x（待确认） | 需实测验证 |
| 1.21.x+ | 可能支持 13.x | 关注官方 Release Notes |

如果 onnxruntime-gpu 与 CUDA 13.0 不兼容，可考虑：

1. 降级 CUDA 到 12.x（如果驱动允许）
2. 等待 onnxruntime-gpu 更新支持 CUDA 13.0
3. 使用 CPU 模式作为临时方案（修改 `onnx_provider = 'CPU'`）

---

## 麒麟V10 注意事项

### 系统包差异

- 包名称可能与 Ubuntu 不同（`portaudio19-dev` 等），需要查询麒麟软件源确认
- 可能需要从 ISO 挂载本地 APT 源：

```bash
# 挂载 ISO 作为本地源
sudo mount -o loop Kylin-10.iso /mnt
sudo tee /etc/apt/sources.list.d/local.list << 'EOF'
deb [trusted=yes] file:///mnt kylin main
EOF
sudo apt update
```

### glibc 兼容性

- 麒麟 V10 的 glibc 版本需确认（通常为 2.31+）
- 部分预编译 wheel 可能要求更高 glibc 版本
- 如遇 glibc 不兼容，需从源码编译对应 Python 包

### PySide6 / UI 兼容性

- PySide6 在 ARM64 上的行为可能有差异
- Toast 窗口使用 Tkinter，通常兼容性较好
- 如 PySide6 有问题，客户端可使用纯 Tkinter 模式

### X11 / 显示环境

- 确认 X11 环境正常运行
- 检查 `DISPLAY` 环境变量：

```bash
echo $DISPLAY
# 应输出类似 :0 或 :1
```

- 如在 SSH 远程运行客户端，需要 X11 转发：

```bash
ssh -X user@client-host
```

---

## 常见问题 FAQ

### Q1: onnxruntime-gpu 报 CUDA 版本不兼容？

**A**: 检查 onnxruntime-gpu 版本与 CUDA 版本的对应关系：

```bash
# 查看当前 CUDA 版本
nvcc --version

# 查看 onnxruntime-gpu 版本
pip show onnxruntime-gpu
```

可能需要指定特定版本：

```bash
pip install onnxruntime-gpu==1.20.0
```

如果确实不兼容 CUDA 13.0，临时方案是使用 CPU 模式：在 `config_server.py` 中设置 `onnx_provider = 'CPU'`。

### Q2: llama.cpp 编译失败？

**A**: 检查编译前置条件：

```bash
# cmake 版本
cmake --version  # 需要 >= 3.14

# gcc 版本
gcc --version    # 需要 >= 11

# CUDA Toolkit
nvcc --version   # 确认已安装
```

常见编译问题：

- **cmake 找不到 CUDA**：确认 `CUDA_PATH` 环境变量已设置
- **gcc 版本过低**：升级 gcc 或安装新版 `gcc-11`/`gcc-12`
- **内存不足**：减少编译线程数，使用 `make -j4` 替代 `make -j$(nproc)`

### Q3: 客户端连接不上服务端？

**A**: 逐步排查：

1. 确认服务端正在运行：`ss -tlnp | grep 6016`
2. 确认防火墙规则：`sudo iptables -L -n | grep 6016`
3. 确认客户端配置的 IP 和端口正确
4. 从客户端 ping 服务端 IP：`ping 192.168.x.x`
5. 从客户端测试端口连通性：`nc -zv 192.168.x.x 6016`

### Q4: 麒麟上 pynput 不工作？

**A**: pynput 依赖 X11 环境：

1. 确认 X11 正在运行：`echo $DISPLAY`
2. 如果为空，设置：`export DISPLAY=:0`
3. 确认用户有 X11 访问权限
4. 如果是 Wayland 环境，尝试切换到 X11 会话

### Q5: Toast 不显示中文？

**A**: 安装中文字体包：

```bash
sudo apt install fonts-noto-cjk
# 或者
sudo apt install fonts-wqy-zenhei
```

安装后可能需要重启客户端应用。

### Q6: 下载脚本在云服务器上运行失败？

**A**: 检查以下问题：

1. 确认能访问 PyPI：`curl -I https://pypi.org/simple/`
2. 确认能访问 GitHub：`curl -I https://github.com`
3. 如果有代理，设置环境变量：`export https_proxy=...`
4. 检查磁盘空间：`df -h`（至少需要 10GB 空闲空间）

---

## 部署检查清单

### 服务端

- [ ] Python 3.12 已安装
- [ ] server-offline.tar.gz 已解压并安装
- [ ] llama.cpp 已编译（CUDA 支持）
- [ ] config_server.py 已配置（onnx_provider、模型路径等）
- [ ] 模型文件已部署到 models/ 目录
- [ ] start_server.py 启动正常
- [ ] 日志显示 CUDAExecutionProvider 加载成功
- [ ] 端口 6016 可访问

### 客户端

- [ ] 系统依赖已安装（portaudio19-dev、python3-tk、xclip、ffmpeg）
- [ ] client-offline.tar.gz 已解压并安装
- [ ] config_client.py 已配置（服务端 IP、端口）
- [ ] LLM 角色已配置（api_base、model）
- [ ] start_client.py 启动正常
- [ ] WebSocket 连接成功
- [ ] 端到端语音识别测试通过
