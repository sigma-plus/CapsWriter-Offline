# CapsWriter-Offline 服务端离线部署指南（Air-Gapped）

目标：在**无外网**的服务器上部署 CapsWriter-Offline 服务端，使用 CUDA GPU 加速。

**目标服务器环境**：Ubuntu 22.04 x86_64 / CUDA 13.0 / glibc 2.35 / 双 NVIDIA 4090D

---

## 1. 传输物清单

在能联网的机器上准备以下文件，通过 U 盘或内网传输到目标服务器。

| # | 文件 | 大小 | 来源 | 说明 |
|---|------|------|------|------|
| 1 | `CapsWriter-Offline-Linux-x86_64.tar.gz` | ~364MB | 阿里云构建服务器 `/opt/CapsWriter-Offline-Linux-x86_64.tar.gz` | PyInstaller 打包产物（含 Python 运行时 + 所有依赖） |
| 2 | `models/` 目录 | ~2.8GB | 开发机 `D:\github\CapsWriter-Offline\models\` | AI 模型文件（见下方目录结构） |
| 3 | CUDA Toolkit 安装包 | ~3GB | NVIDIA 官网离线 runfile | CUDA 13.0 runtime（如目标已安装则不需要） |

### 1.1 模型目录结构

```
models/
├── Qwen3-ASR/Qwen3-ASR-1.7B/
│   ├── qwen3_asr_encoder_frontend.onnx
│   ├── qwen3_asr_encoder_backend.onnx
│   └── qwen3_asr_llm.gguf
├── Punct-CT-Transformer/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12/
│   └── model.onnx
├── Qwen3-ForcedAligner/Qwen3-ForcedAligner-0.6B/
│   ├── qwen3_aligner_encoder_frontend.int4.onnx
│   ├── qwen3_aligner_encoder_backend.int4.onnx
│   └── qwen3_aligner_llm.q5_k.gguf
├── Paraformer/...          （可选）
├── SenseVoice-Small/...    （可选）
└── Fun-ASR-Nano/...        （可选）
```

> 最少只需 `Qwen3-ASR` + `Punct-CT-Transformer` 即可启动服务。

---

## 2. 目标服务器环境要求

### 2.1 硬件

| 项目 | 要求 |
|------|------|
| CPU | x86_64 |
| GPU | NVIDIA GPU，计算能力 ≥ 7.0（如 4090、A100 等） |
| 内存 | ≥ 8GB（推荐 16GB） |
| 磁盘 | ≥ 10GB 可用空间 |

### 2.2 操作系统

| 项目 | 要求 | 检查命令 |
|------|------|----------|
| 系统 | Ubuntu 22.04 LTS x86_64 | `cat /etc/os-release` |
| glibc | ≥ 2.35 | `ldd --version` |
| GPU 驱动 | NVIDIA 驱动已安装 | `nvidia-smi` |

### 2.3 CUDA 版本要求

目标服务器已安装 CUDA 13.0。onnxruntime-gpu 1.23.x 需要以下 CUDA 库：

| CUDA 库 | 要求版本 | 检查命令 |
|---------|---------|----------|
| libcublas | ≥ 12 | `ls /usr/local/cuda/lib64/libcublas.so.*` |
| libcublasLt | ≥ 12 | `ls /usr/local/cuda/lib64/libcublasLt.so.*` |
| libcufft | ≥ 11 | `ls /usr/local/cuda/lib64/libcufft.so.*` |
| libcurand | ≥ 10 | `ls /usr/local/cuda/lib64/libcurand.so.*` |
| libcudart | ≥ 12 | `ls /usr/local/cuda/lib64/libcudart.so.*` |
| libcudnn | ≥ 9 | `ls /usr/local/cuda/lib64/libcudnn.so.*` |

> CUDA 13.0 向下兼容这些库版本，通常已包含。运行 `nvidia-smi` 和 `nvcc --version` 确认。

---

## 3. 部署步骤

### 3.1 解压程序

```bash
# 创建安装目录
sudo mkdir -p /opt/CapsWriter-Offline

# 解压 PyInstaller 产物
cd /opt
sudo tar -xzf CapsWriter-Offline-Linux-x86_64.tar.gz

# 复制模型文件（从 U 盘或内网拷贝）
sudo cp -r /path/to/models /opt/CapsWriter-Offline/models/
```

### 3.2 验证目录结构

```bash
ls /opt/CapsWriter-Offline/
```

应看到：

```
assets/     config_client.py  config_server.py  core/
hot*.txt    internal/         LICENSE           LLM/
models/     readme.md         start_client      start_server
```

### 3.3 修改服务端配置

```bash
vim /opt/CapsWriter-Offline/config_server.py
```

需要修改的关键配置：

```python
# 1. 所有引擎的 onnx_provider 改为 CUDA（共 4 处，搜索 onnx_provider）
onnx_provider = 'CUDA'       # 原值为 'CPU'

# 2. 确认监听地址（默认已是 0.0.0.0）
addr = '0.0.0.0'
port = '6016'

# 3. 确认模型路径（默认相对于程序目录，无需修改）
model_dir = Path() / 'models'
```

> 也可按需选择引擎（默认 Qwen3-ASR）和调整线程数等参数。

### 3.4 赋予执行权限

```bash
sudo chmod +x /opt/CapsWriter-Offline/start_server
sudo chmod +x /opt/CapsWriter-Offline/start_client
```

### 3.5 测试启动

```bash
cd /opt/CapsWriter-Offline
./start_server
```

确认日志中出现：

```
✓ 模型加载完成
✓ WebSocket 服务监听在 0.0.0.0:6016
✓ CUDAExecutionProvider 可用
```

按 `Ctrl+C` 停止测试。

---

## 4. 注册为系统服务（可选，推荐）

### 4.1 创建 systemd 服务文件

```bash
sudo tee /etc/systemd/system/capswriter-server.service << 'EOF'
[Unit]
Description=CapsWriter-Offline Server
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/CapsWriter-Offline
ExecStart=/opt/CapsWriter-Offline/start_server
Restart=on-failure
RestartSec=5
StartLimitBurst=3
StartLimitIntervalSec=60
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

> 如果使用非 root 用户运行，修改 `User` 和 `Group` 字段。

### 4.2 启用并启动

```bash
sudo systemctl daemon-reload
sudo systemctl enable capswriter-server    # 开机自启
sudo systemctl start capswriter-server     # 立即启动
```

### 4.3 常用管理命令

```bash
sudo systemctl status capswriter-server         # 查看状态
sudo systemctl restart capswriter-server        # 重启
sudo systemctl stop capswriter-server           # 停止
journalctl -u capswriter-server -f              # 实时日志
journalctl -u capswriter-server --since today   # 今日日志
```

---

## 5. 验证

### 5.1 本机验证

```bash
# 确认端口监听
ss -tlnp | grep 6016

# 确认 GPU 使用
nvidia-smi
```

### 5.2 客户端连通性

从客户端机器测试：

```bash
# 网络连通
nc -zv <服务端IP> 6016

# 修改客户端配置
vim config_client.py
# 设置 addr = '<服务端IP>'
```

然后启动客户端进行语音识别测试。

---

## 6. 防火墙配置

如需开放端口：

```bash
# iptables
sudo iptables -A INPUT -p tcp --dport 6016 -j ACCEPT

# 或 firewalld
sudo firewall-cmd --permanent --add-port=6016/tcp
sudo firewall-cmd --reload

# 或 ufw
sudo ufw allow 6016/tcp
```

---

## 7. 故障排查

### Q1: 启动报 CUDA 相关错误

```
libcublas.so.12: cannot open shared object file
```

**原因**：CUDA Toolkit 未安装或版本不匹配。

**排查**：

```bash
ls /usr/local/cuda/lib64/libcublas.so.12   # 应存在
nvcc --version                              # 查看 CUDA 版本
```

临时方案：在 `config_server.py` 中改回 `onnx_provider = 'CPU'`。

### Q2: 端口已被占用

```bash
sudo lsof -i :6016
# 修改 config_server.py 中 port 为其他值
```

### Q3: 权限不足

```bash
# 确保运行用户对目录有读写权限
sudo chown -R <user>:<group> /opt/CapsWriter-Offline
```

### Q4: 模型文件找不到

确认 `models/` 目录在 `start_server` 同级，且子目录名称与 `config_server.py` 中 `ModelPaths` 定义一致。

---

## 8. 文件清单汇总

部署完成后，目标服务器 `/opt/CapsWriter-Offline/` 目录应包含：

```
/opt/CapsWriter-Offline/
├── start_server              # 服务端可执行文件（PyInstaller）
├── start_client              # 客户端可执行文件（PyInstaller）
├── internal/                 # Python 运行时 + 第三方库（无需额外安装 Python）
├── core/                     # 项目核心源码
├── LLM/                      # LLM 角色配置
├── assets/                   # 图标等资源
├── config_server.py          # 服务端配置（需修改 onnx_provider='CUDA'）
├── config_client.py          # 客户端配置（需修改 addr）
├── hot.txt                   # 热词
├── hot-server.txt            # 服务端热词
├── hot-rule.txt              # 热词替换规则
├── models/                   # AI 模型文件（~2.8GB，单独拷贝）
├── readme.md
└── LICENSE
```

**构建信息**：
- 构建环境：Ubuntu 22.04 x86_64, Python 3.10.12, PyInstaller 6.20.0, glibc 2.35
- 目标兼容：glibc ≥ 2.35, CUDA 13.0
- 构建时间：2026-05-17
- 产物大小：~364MB（不含 models）
