# 使用轻量级Python基础镜像
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.7.2 /uv /uvx /bin/

# 设置工作目录
WORKDIR /app

# 环境变量设置
ENV TZ=Asia/Shanghai \
    UV_LINK_MODE=copy \
    DEBIAN_FRONTEND=noninteractive

# 设置代理和时区，更换镜像源，安装系统依赖 - 合并为一个RUN减少层数
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 更换为阿里云镜像源加速下载
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    # 清理apt缓存并更新，避免空间不足问题
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    apt-get update && \
    # 安装系统依赖，减少缓存占用
    apt-get install -y --no-install-recommends \
        python3-dev \
        ffmpeg \
        libsm6 \
        libxext6 \
        curl \
        && apt-get autoremove -y && \
        apt-get autoclean && \
        rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# 复制项目配置文件
COPY ../pyproject.toml /app/pyproject.toml
COPY ../.python-version /app/.python-version

# 接收构建参数
ARG HTTP_PROXY=""
ARG HTTPS_PROXY=""
# 可配置 Python 镜像源（默认清华）
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# 设置环境变量（这些值可能是空的）
ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    http_proxy=$HTTP_PROXY \
    https_proxy=$HTTPS_PROXY \
    PIP_INDEX_URL=$PIP_INDEX_URL

# 复制本地离线 wheels（如存在）
COPY ../wheels /app/wheels

# 离线优先安装：先尝试用本地 wheels 安装大依赖，再在线补齐缺失依赖
# 说明：
# 1) 第一步 uv pip --no-index --find-links=/app/wheels 会仅从本地目录解析并安装已存在的 wheel 包，
#    若目录不存在或空/不满足依赖，将继续下一步，不会影响后续在线安装。
# 2) 第二步 uv sync 仍使用缓存挂载与镜像源，补齐剩余未安装的依赖；已安装的会被跳过（满足版本约束时）。
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/root/.cache/pip \
    bash -lc 'set -euo pipefail; \
    echo "[info] Using PIP_INDEX_URL=$PIP_INDEX_URL"; \
    if [ -d /app/wheels ] && [ "$(ls -A /app/wheels || true)" != "" ]; then \
        echo "[info] Detect local wheels, preparing project venv and installing into it..."; \
        uv venv; \
        VENV_PY=.venv/bin/python; \
        HAS_WHL=$(compgen -G "/app/wheels/*.whl" || true); \
        HAS_TAR=$(compgen -G "/app/wheels/*.tar.gz" || true); \
        if [ -n "$HAS_WHL" ] || [ -n "$HAS_TAR" ]; then \
            [ -n "$HAS_WHL" ] && uv pip install --python "$VENV_PY" --no-index --find-links /app/wheels --upgrade /app/wheels/*.whl || true; \
            [ -n "$HAS_TAR" ] && uv pip install --python "$VENV_PY" --no-index --find-links /app/wheels --upgrade /app/wheels/*.tar.gz || true; \
        else \
            echo "[info] No local wheel/source archives (*.whl|*.tar.gz) found under /app/wheels."; \
        fi; \
    else \
        echo "[info] No local wheels found, skipping offline install."; \
    fi; \
    echo "[info] Running online sync to resolve remaining deps..."; \
    uv sync --no-dev --no-install-project --index-url $PIP_INDEX_URL'

# 复制代码到容器中
COPY ../src /app/src
COPY ../server /app/server
