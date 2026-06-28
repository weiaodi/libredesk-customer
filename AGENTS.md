# AGENTS.md — LibreDesk 项目指引

## 项目概述

LibreDesk 是一个开源客户支持平台，采用 Go 后端 + Vue3 前端架构。

- **后端**: Go 1.25，HTTP 框架，PostgreSQL 17，Redis 7
- **前端**: Vue 3 + Vite + Tailwind CSS + TipTap 编辑器
- **包管理**: 前端使用 pnpm（monorepo 结构），后端使用 Go Modules
- **Go 模块路径**: `github.com/abhinavxd/libredesk`

## 开发环境启动

```bash
# 安装前端依赖
cd frontend && pnpm install

# 启动前端开发服务器（主应用）
make run-frontend
# 或直接: cd frontend && pnpm dev:main

# 启动前端开发服务器（Widget）
cd frontend && pnpm dev:widget

# 启动后端开发服务器（需要先配置 config.toml）
make run-backend

# 使用 Docker Compose 一键启动（PostgreSQL + Redis + LibreDesk）
docker compose up -d
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

- 后端翻译文件在 `i18n/` 目录
- 前端使用 vue-i18n，翻译文件在各应用内
- 新增语言需要同时更新前后端翻译文件

## 配置

- 配置文件: `config.toml`（基于 `config.sample.toml`）
- 必须修改 `encryption_key`（使用 `openssl rand -hex 16` 生成 32 字符密钥）
- 开发模式设置 `env = "dev"`
- 服务默认监听 `0.0.0.0:9000`

## 数据库

- PostgreSQL 17，Schema 在 `schema.sql`
- 使用 SQL builder 模式，日期过滤需注意时区处理
- Docker Compose 已包含 PostgreSQL 和 Redis 服务

## 安全注意事项

- 不要提交 `config.toml`（包含密钥），它已在 `.gitignore` 中
- `encryption_key` 必须是 32 字符随机字符串
- 生产环境不要禁用 secure cookies

## PR 规范

- Commit message 使用英文，简洁描述变更
- 提交前运行 `pnpm lint` 和 `pnpm test`（前端）
- 提交前运行 `go test ./...`（后端）
