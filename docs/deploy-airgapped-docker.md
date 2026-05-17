# CapsWriter-Offline 服务端 Docker 离线部署指南

**目标服务器**：Ubuntu 22.04 x86_64 / glibc 2.35 / 双 NVIDIA 4090D / 驱动 580.126.09 (CUDA 13.0) / air-gapped

---

## 方案说明

**为什么用 CUDA 12 容器而不是 CUDA 13？**

ONNX Runtime 1.26.0 已同时发布 CUDA 12 和 CUDA 13 构建版本（CUDA 13 包名为 `onnxruntime-*-gpu_cuda13-*`），且 **CUDA 12 将在 1.27.0 中移除**。本方案仍选用 CUDA 12 容器，原因是 PyPI 默认 `onnxruntime-gpu` 包为 CUDA 12 构建，且 NVIDIA 驱动**向下兼容**：宿主机 CUDA 13 驱动可以运行 CUDA 12 容器内的程序，这是 NVIDIA Container Toolkit 的标准工作模式。升级到 1.27.0 后应切换至 CUDA 13 基础镜像和对应包。

| 组件 | 版本 | 说明 |
|------|------|------|
| 宿主机驱动 | 580.126.09 (CUDA 13) | 向下兼容 CUDA 12 容器 |
| 容器 CUDA 运行时 | 12.6.3 + cuDNN 9 | onnxruntime-gpu 官方兼容 |
| Python | 3.11（容器内） | onnxruntime-gpu 1.26.0 有 cp311 wheel |
| 容器内不需要 PyInstaller | — | 直接 `python3 start_server.py` |

---

## 1. 传输物清单

| # | 文件 | 大小 | 说明 |
|---|------|------|------|
| 1 | `capswriter-server.tar` | ~2GB | Docker 镜像 tar |
| 2 | `docker-compose.yml` | 1KB | 编排文件 |
| 3 | `models/` 目录 | ~2.8GB | AI 模型文件 |

### 1.1 模型目录结构

```
models/
├── Qwen3-ASR/Qwen3-ASR-1.7B/
│   ├── qwen3_asr_encoder_frontend.onnx
│   ├── qwen3_asr_encoder_backend.onnx
│   └── qwen3_asr_llm.gguf
├── Punct-CT-Transformer/sherpa-onnx-punct-ct-transformer-zh-en-vocab272727-2024-04-12/
│   └── model.onnx
├── Qwen3-ForcedAligner/Qwen3-ForcedAligner-0.6B/   （可选）
├── Paraformer/...                                    （可选）
├── SenseVoice-Small/...                              （可选）
└── Fun-ASR-Nano/...                                  （可选）
```

> 最少只需 `Qwen3-ASR` + `Punct-CT-Transformer` 即可启动。

---

## 2. 构建步骤（在有网络的机器上执行）

### 2.1 前提

- Docker 已安装
- 可访问 Docker Hub（拉取基础镜像）和 PyPI（安装 Python 包）
- 项目源码在当前目录

### 2.2 拉取基础镜像

```bash
docker pull nvidia/cuda:12.6.3-cudnn9-runtime-ubuntu22.04
```

> 如果网络受限，可从 NVIDIA 容器注册表拉取：`nvcr.io/nvidia/cuda:12.6.3-cudnn9-runtime-ubuntu22.04`

### 2.3 构建镜像

```bash
cd /path/to/CapsWriter-Offline
docker build -t capswriter-server:latest .
```

构建过程：
1. 基于 CUDA 12.6 + cuDNN 9 运行时镜像
2. 安装 Python 3.11（通过 deadsnakes PPA）
3. 安装 Python 依赖（`requirements-server-docker.txt`）
4. 复制项目源码（`core/`、`LLM/`、`assets/` 等）

### 2.4 导出镜像

```bash
docker save -o capswriter-server.tar capswriter-server:latest
```

产物 `capswriter-server.tar` 约 2GB，传输到目标服务器。

---

## 3. docker-compose.yml

```yaml
services:
  capswriter-server:
    image: capswriter-server:latest
    container_name: capswriter-server
    restart: unless-stopped
    ports:
      - "6016:6016"
    volumes:
      - ./models:/opt/CapsWriter-Offline/models
      - ./config_server.py:/opt/CapsWriter-Offline/config_server.py
      - ./hot.txt:/opt/CapsWriter-Offline/hot.txt
      - ./hot-server.txt:/opt/CapsWriter-Offline/hot-server.txt
      - ./hot-rule.txt:/opt/CapsWriter-Offline/hot-rule.txt
      - ./logs:/opt/CapsWriter-Offline/logs
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**挂载说明**：

| 挂载项 | 用途 | 是否必须 |
|--------|------|----------|
| `models/` | AI 模型文件 | 是 |
| `config_server.py` | 服务端配置 | 是 |
| `hot*.txt` | 热词文件 | 可选 |
| `logs/` | 日志持久化 | 可选 |

> 配置和热词通过 volume 挂载，修改后 `docker compose restart` 即可生效，无需重建镜像。

---

## 4. 目标服务器部署

### 4.1 环境检查

```bash
# Docker
docker --version

# NVIDIA Container Toolkit
nvidia-container-cli --version

# GPU 驱动
nvidia-smi
```

### 4.2 加载镜像

```bash
docker load -i capswriter-server.tar
```

### 4.3 准备目录

```bash
mkdir -p /opt/capswriter
cd /opt/capswriter

# 将以下文件放入此目录：
# - docker-compose.yml
# - config_server.py（从源码复制并修改）
# - hot.txt / hot-server.txt / hot-rule.txt（从源码复制）
# - models/ 目录（模型文件）
```

### 4.4 修改配置

```bash
vim config_server.py
```

关键修改（搜索 `onnx_provider`，共 4 处）：

```python
# 改为 CUDA
onnx_provider = 'CUDA'

# 监听地址（默认已是 0.0.0.0，无需修改）
addr = '0.0.0.0'
port = '6016'
```

### 4.5 启动

```bash
docker compose up -d
```

### 4.6 验证

```bash
# 容器状态
docker compose ps

# 实时日志
docker compose logs -f

# GPU 使用
nvidia-smi
```

日志确认项：
- 模型加载完成
- `CUDAExecutionProvider` 可用
- WebSocket 监听在 `0.0.0.0:6016`

### 4.7 管理命令

```bash
docker compose up -d            # 启动
docker compose down             # 停止
docker compose restart          # 重启（修改配置后）
docker compose logs -f          # 实时日志
docker compose logs --tail 100  # 最近 100 行
```

---

## 5. 网络配置

### 5.1 防火墙

```bash
# ufw
sudo ufw allow 6016/tcp

# 或 iptables
sudo iptables -A INPUT -p tcp --dport 6016 -j ACCEPT
```

### 5.2 客户端连接

客户端 `config_client.py` 中设置：

```python
addr = '<目标服务器IP>'
port = '6016'
```

---

## 6. 目标服务器目录结构

```
/opt/capswriter/
├── docker-compose.yml       # 编排文件
├── config_server.py         # 服务端配置（挂载进容器，onnx_provider='CUDA'）
├── hot.txt                  # 热词
├── hot-server.txt           # 服务端热词
├── hot-rule.txt             # 热词替换规则
├── logs/                    # 日志目录（挂载进容器）
└── models/                  # 模型文件（挂载进容器，~2.8GB）
    ├── Qwen3-ASR/
    ├── Punct-CT-Transformer/
    └── ...
```

Docker 镜像内部：
```
/opt/CapsWriter-Offline/
├── start_server.py          # 服务端入口
├── start_client.py          # 客户端入口
├── build_hook.py            # PyInstaller hook（保留兼容）
├── core/                    # 项目源码
├── LLM/                     # LLM 角色配置
└── assets/                  # 资源文件
```

---

## 7. 故障排查

### Q1: 容器启动后立即退出

```bash
docker compose logs    # 查看退出原因
```

常见原因：`config_server.py` 配置错误、模型路径不对。

### Q2: GPU 不可用

```bash
# 测试 GPU 直通
docker run --rm --gpus all nvidia/cuda:12.6.3-cudnn9-runtime-ubuntu22.04 nvidia-smi

# 如果失败，重新配置 NVIDIA Container Toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Q3: CUDA 报错 libcublas.so 找不到

不应出现（CUDA 12 运行时已内置于镜像）。如出现：

```bash
docker compose exec capswriter-server ls /usr/local/cuda/lib64/libcublas.so*
```

### Q4: 客户端连接不上

```bash
# 容器内确认监听
docker compose exec capswriter-server ss -tlnp | grep 6016

# 宿主机确认端口映射
ss -tlnp | grep 6016

# 从客户端测试
nc -zv <服务端IP> 6016
```

### Q5: 修改配置后不生效

```bash
docker compose restart    # 重启容器
```

---

## 8. 构建信息

| 项目 | 值 |
|------|-----|
| 基础镜像 | `nvidia/cuda:12.6.3-cudnn9-runtime-ubuntu22.04` |
| 容器内 Python | 3.11 |
| onnxruntime-gpu | latest（当前 1.26.0，CUDA 12 构建） |
| 兼容宿主机 CUDA | ≥ 12（含 13.x，驱动向下兼容） |
| 兼容宿主机 glibc | 任意（容器自带 glibc） |
| 镜像大小 | ~2GB |
