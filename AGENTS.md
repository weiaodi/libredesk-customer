# AGENTS.md — LibreDesk 项目指引

## 项目概述

LibreDesk 是一个开源客户支持平台，采用 Go 后端 + Vue3 前端架构。

- **后端**: Go 1.25，HTTP 框架，PostgreSQL 17，Redis 7
- **前端**: Vue 3 + Vite + Tailwind CSS + TipTap 编辑器
- **包管理**: 前端使用 pnpm（monorepo 结构），后端使用 Go Modules
- **Go 模块路径**: `github.com/abhinavxd/libredesk`

## 知识库

项目文档知识库位于 `knowledge/` 目录，整理自官方文档 https://docs.libredesk.io ，涵盖：

- 项目介绍与功能特性（01-introduction）
- 安装部署指南（02-installation）
- 开发环境搭建（03-developer-setup）
- 升级指南（04-upgrade）
- 配置文档（05-configuration/）：收件箱连接、实时聊天、SSO、Webhook、邮件模板、上下文链接
- 角色与权限体系（06-roles-permissions）
- API 参考文档（07-api-reference/）：认证、Widget API、端点汇总
- 云部署（08-hosting/）

总索引: `knowledge/INDEX.md`

当需要查阅 LibreDesk 的功能说明、配置方法、API 用法、权限体系等内容时，优先查阅 `knowledge/` 目录下的文档。

### 改动后端接口与核心服务时必须参考知识库

当改动涉及**API 接口或后端核心业务服务**时，**必须先查阅 `knowledge/` 目录中相关文档**，确保改动符合 LibreDesk 的设计规范和功能约定：

1. **API 端点改动**：必须对照 `07-api-reference/endpoints-summary.md` 和 Widget API 文档，确保接口路径、请求/响应格式与文档一致
2. **权限相关改动**：必须对照 `06-roles-permissions.md` 中的完整权限列表，确保权限名称和粒度不变
3. **收件箱/邮件/聊天等核心服务改动**：必须对照 `05-configuration/` 下的对应文档，确保功能行为和配置项语义与文档描述一致
4. **不确定时查阅**：如果改动可能影响用户可见行为或 API 兼容性，先用 `knowledge/INDEX.md` 的关键词速查定位文档，确认后再动手

## 开发环境启动（本地开发模式）

本项目推荐使用「本地开发模式」：数据库和 Redis 通过容器运行，Go 后端和前端在宿主机直接运行，方便调试。

### 前置条件

- Go 1.25+
- Node.js 18+ & pnpm
- Podman（或 Docker）+ podman-compose（或 docker-compose）

### 第一步：启动 PostgreSQL 和 Redis 容器

```bash
# 使用 Podman
podman-compose up -d db redis

# 或使用 Docker
docker compose up -d db redis
```

容器启动后，PostgreSQL 监听 `localhost:5432`，Redis 监听 `localhost:6379`。

验证数据库就绪：
```bash
podman exec libredesk_db pg_isready -U libredesk -d libredesk
# 应输出: accepting connections
```

### 第二步：配置 config.toml

从模板创建配置文件：
```bash
cp config.sample.toml config.toml
```

必须修改以下关键配置：

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `encryption_key` | 32 字符随机字符串 | 使用 `openssl rand -hex 16` 生成 |
| `[db].host` | `localhost` | 本地开发改为 localhost（模板默认为 `db`） |
| `[redis].address` | `localhost:6379` | 本地开发改为 localhost（模板默认为 `redis:6379`） |
| `app.env` | `dev` | 开发模式 |
| `app.lang` | `zh-CN` | 默认中文 |

### 第三步：初始化数据库

```bash
# 首次安装数据库 schema
go run ./cmd/ --install --idempotent-install --yes --config config.toml

# 数据库升级（如有待执行的迁移）
go run ./cmd/ --upgrade --yes --config config.toml
```

注意：由于开发模式（`go run`）使用本地文件系统而非嵌入二进制，
`initFS()` 已修复包含 `schema.sql`（见 `cmd/init.go` 第 186 行）。
如遇 "file does not exist" 错误，可手动导入：
```bash
podman exec -i libredesk_db psql -U libredesk -d libredesk < schema.sql
```

### 第四步：设置系统用户密码

```bash
# 交互式设置密码
go run ./cmd/ --set-system-user-password --config config.toml
# 或通过环境变量
LIBREDESK_SYSTEM_USER_PASSWORD="YourStrongP@ss1" go run ./cmd/ --install --yes --config config.toml
```

### 第五步：启动后端

```bash
make run-backend
# 后端监听 http://localhost:9000
```

### 第六步：启动前端（另开终端）

```bash
make run-frontend
# 前端开发服务器监听 http://localhost:8000
```

### 一键全容器启动（非本地开发，仅体验/演示）

```bash
podman-compose up -d    # 或 docker compose up -d
```

### 常用运维命令

```bash
# 停止容器
podman-compose down

# 重启容器
podman-compose up -d db redis

# 查看容器状态
podman ps -a

# 查看后端日志（运行中时）
# 后端日志直接输出到终端

# 设置系统用户密码
go run ./cmd/ --set-system-user-password --config config.toml
```

## 构建命令

```bash
# 构建前端（生产模式，主应用 + Widget）
make frontend-build

# 仅构建主应用
make frontend-build-main

# 仅构建 Widget
make frontend-build-widget

# 安装全部依赖（前端 + stuffbin）
make install-deps
```

## 测试命令

```bash
# 前端单元测试
cd frontend && pnpm test

# 前端测试（单次运行）
cd frontend && pnpm test:run

# 前端 E2E 测试
cd frontend && pnpm test:e2e

# 前端 Lint
cd frontend && pnpm lint

# 前端格式化
cd frontend && pnpm format

# 后端测试
go test ./...
```

## 项目结构

```
├── cmd/                    # Go 后端入口和 HTTP handlers
├── internal/               # Go 后端核心业务逻辑
│   ├── models/             # 数据模型
│   ├── store/              # 数据库访问层（PostgreSQL）
│   ├── auth/               # 认证和授权
│   ├── i18n/               # 国际化
│   └── ...
├── frontend/               # Vue3 前端 monorepo
│   ├── apps/main/          # 主应用（管理后台）
│   ├── apps/widget/        # 客户端 Widget
│   └── packages/           # 共享包
├── i18n/                   # 后端国际化翻译文件
├── static/                 # 静态资源
├── schema.sql              # 数据库 schema
├── config.sample.toml      # 配置文件模板
├── docker-compose.yml      # Docker 编排
├── Dockerfile              # 生产部署镜像
└── Makefile                # 构建、运行、打包命令
```

## 代码风格

### Go 后端

- 遵循 Go 标准格式化：`gofmt` / `goimports`
- 错误处理使用 `fmt.Errorf("context: %w", err)` 包装
- HTTP handler 放在 `cmd/` 目录，业务逻辑放在 `internal/` 目录
- 数据库操作通过 `internal/store/` 层进行，不直接在 handler 中写 SQL

### Vue 前端

- Vue 3 Composition API（`<script setup>` 语法）
- 使用 Tailwind CSS，不写自定义 CSS
- 组件命名使用 PascalCase
- Composable 函数放在 `composables/` 目录，以 `use` 前缀命名
- 常量放在 `constants/` 目录
- ESLint + Prettier 强制代码风格

## 国际化（i18n）

- 项目默认语言为 **zh-CN**（中文简体）
- 后端默认语言常量: `cmd/i18n.go` 中的 `defLang = "zh-CN"`
- 后端翻译文件在 `i18n/` 目录（已有 `zh-CN.json`、`en-US.json` 等多种语言）
- 前端使用 vue-i18n，语言包从后端 API `/api/v1/lang/{code}` 动态加载
- 前端默认 fallback 语言: `zh-CN`（`frontend/apps/main/src/main.js`）
- 数据库 settings 表中 `app.lang` 默认值为 `"zh-CN"`（`schema.sql`）
- 可通过管理后台「设置 > 通用」修改界面语言
- 新增语言需要同时更新前后端翻译文件
- 可用语言列表: `en-US`, `zh-CN`

## 配置

- 配置文件: `config.toml`（基于 `config.sample.toml`）
- 必须修改 `encryption_key`（使用 `openssl rand -hex 16` 生成 32 字符密钥）
- 开发模式设置 `env = "dev"`
- 服务默认监听 `0.0.0.0:9000`

## 数据库

- PostgreSQL 17，Schema 在 `schema.sql`
- 使用 SQL builder 模式，日期过滤需注意时区处理
- Docker Compose 已包含 PostgreSQL 和 Redis 服务

## 热更新与重启规范

**核心原则：不要做不必要的重启。前端 dev server 运行时，Vite HMR 会自动处理文件变更。**

| 操作类型 | 是否需要重启 | 说明 |
|----------|-------------|------|
| 修改 `.vue` / `.js` / `.ts` / `.scss` 前端文件 | 不需要 | Vite HMR 自动热更新到浏览器 |
| 修改 `vite.config.js` | 需要重启前端 | Vite 配置变更需要重启 dev server |
| 修改 `tailwind.config.cjs` | 不需要 | PostCSS 插件会自动重载 |
| 修改 Go 后端代码 | 需要重启后端 | Go 没有热重载，必须 `kill + make run-backend` |
| 修改 `config.toml` | 需要重启后端 | 配置只在启动时读取 |
| 修改 `schema.sql` | 不需要重启 | 直接 `psql` 导入即可，或通过 `--upgrade` |
| 修改 `i18n/*.json` | 不需要重启 | 前端通过 API 动态加载，刷新页面即可 |
| 修改 `cmd/init.go` 等初始化代码 | 需要重启后端 | 下次 `go run` 时生效 |

**操作守则：**
- 编辑前端文件后，**不要重启 dev server**，等 Vite HMR 自动生效
- 只有 dev server 挂掉（端口不在监听）时才重启前端
- 重启后端时先用 `lsof -ti:9000 | xargs kill -9` 停旧进程，再 `make run-backend`

## 安全注意事项

- 不要提交 `config.toml`（包含密钥），它已在 `.gitignore` 中
- `encryption_key` 必须是 32 字符随机字符串
- 生产环境不要禁用 secure cookies

## PR 规范

- Commit message 使用英文，简洁描述变更
- 提交前运行 `pnpm lint` 和 `pnpm test`（前端）
- 提交前运行 `go test ./...`（后端）
