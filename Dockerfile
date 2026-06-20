# ========== 多阶段构建 ==========
# 阶段1: 安装依赖（含 better-sqlite3 编译）
# 阶段2: 构建 Next.js
# 阶段3: 生产镜像

# ---------- 阶段1: 依赖安装 ----------
FROM node:20-slim AS deps

# 安装 better-sqlite3 编译依赖 + pnpm
RUN apt-get update && apt-get install -y \
    python3 make g++ \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable && corepack prepare pnpm@10.33.0 --activate

WORKDIR /app

# 先拷贝依赖声明文件（利用 Docker 缓存层）
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .pnpmrc.json ./

# 安装全部依赖（含 devDependencies，build 需要）
RUN pnpm install --frozen-lockfile

# ---------- 阶段2: 构建 ----------
FROM deps AS builder

WORKDIR /app

# 拷贝源码
COPY . .

# Next.js 采集匿名遥测数据，Docker 中关闭
ENV NEXT_TELEMETRY_DISABLED=1

# 构建生产版本
RUN pnpm build

# ---------- 阶段3: 生产运行 ----------
FROM node:20-slim AS runner

# 安装运行时依赖：FFmpeg（视频合成）+ 中文字体（字幕烧录）+ curl（健康检查）
RUN apt-get update && apt-get install -y \
    ffmpeg \
    fonts-wqy-zenhei \
    fonts-noto-cjk \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv \
    && corepack enable && corepack prepare pnpm@10.33.0 --activate

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
# Next.js standalone 输出模式的环境端口
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# 创建非 root 用户运行（安全最佳实践）
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# 拷贝构建产物
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/drizzle ./drizzle

# 数据目录：数据库 + 上传文件 + 输出视频
RUN mkdir -p data/uploads data/output \
    && chown -R nextjs:nodejs data

USER nextjs

EXPOSE 3000

# 数据持久化挂载点
VOLUME ["/app/data"]

CMD ["node", "server.js"]
