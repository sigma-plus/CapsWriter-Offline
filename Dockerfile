# CapsWriter-Offline 服务端 Docker 镜像
# 基础镜像：CUDA 12.6 + cuDNN 9 运行时
# onnxruntime-gpu 1.26.0 构建于 CUDA 12，与 CUDA 13 宿主机驱动完全兼容

FROM nvidia/cuda:12.6.3-cudnn9-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1

# ---------- 系统依赖 + Python 3.11 ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Python 3.11 作为默认 + pip
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && python3.11 -m ensurepip --upgrade \
    && pip3 install --no-cache-dir --upgrade pip

WORKDIR /opt/CapsWriter-Offline

# ---------- Python 依赖（利用 Docker 层缓存） ----------
COPY requirements-server-docker.txt requirements.txt
RUN pip3 install --no-cache-dir -r requirements.txt

# ---------- 项目源码 ----------
COPY start_server.py start_client.py build_hook.py ./
COPY core/ core/
COPY LLM/ LLM/
COPY assets/ assets/

# 挂载点
RUN mkdir -p models logs

EXPOSE 6016

CMD ["python3", "start_server.py"]
