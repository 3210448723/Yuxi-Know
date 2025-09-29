# 开发阶段
FROM node:20-alpine AS development
WORKDIR /app

ARG http_proxy
ARG https_proxy
# 可配置的国内 npm / pnpm registry（默认使用 npmmirror）
ARG PNPM_REGISTRY=https://registry.npmmirror.com
ENV TZ=Asia/Shanghai \
	PNPM_REGISTRY=${PNPM_REGISTRY}

# 只有当代理变量不为空时才设置代理（不放入同一层：防止构建缓存失效扩大）
RUN if [ -n "$http_proxy" ]; then echo "export http_proxy=$http_proxy" >> /etc/environment; fi
RUN if [ -n "$https_proxy" ]; then echo "export https_proxy=$https_proxy" >> /etc/environment; fi

# 设置 npm/pnpm 镜像并安装 pnpm；合并为单层减少镜像层数
RUN npm config set registry "$PNPM_REGISTRY" \
	&& npm install -g pnpm@latest \
	&& pnpm config set registry "$PNPM_REGISTRY"

# 复制 package.json 和 pnpm-lock.yaml
COPY ./web/package*.json ./
COPY ./web/pnpm-lock.yaml* ./

# 安装依赖（使用 BuildKit 缓存 pnpm store 以加速重复构建）
RUN --mount=type=cache,target=/root/.pnpm-store pnpm install

# 复制源代码
COPY ./web .

# 暴露端口
EXPOSE 5173

# 启动开发服务器的命令在 docker-compose 文件中定义

# 生产阶段
FROM node:20-alpine AS build-stage
WORKDIR /app
ARG PNPM_REGISTRY=https://registry.npmmirror.com
ENV PNPM_REGISTRY=${PNPM_REGISTRY}
# 安装 pnpm 并设置镜像
RUN npm config set registry "$PNPM_REGISTRY" \
	&& npm install -g pnpm@latest \
	&& pnpm config set registry "$PNPM_REGISTRY"

# 复制依赖文件
COPY ./web/package*.json ./
COPY ./web/pnpm-lock.yaml* ./

# 安装依赖（使用冻结锁文件保证一致性 + 缓存）
RUN --mount=type=cache,target=/root/.pnpm-store pnpm install --frozen-lockfile

# 复制源代码并构建
COPY ./web .
RUN pnpm run build

# 生产环境运行阶段
FROM nginx:alpine AS production
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY ./docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]